terraform {
  required_providers {
    aws   = { source = "hashicorp/aws", version = ">= 5.0" }
    http  = { source = "hashicorp/http" }
    local = { source = "hashicorp/local" }
  }
}

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "prod_count" {
  default = 4
  validation {
    condition     = var.prod_count >= 1 && var.prod_count <= 10
    error_message = "prod_count must be between 1 and 10."
  }
}

variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "dev_subnet_cidr" {
  default = "10.20.1.0/24"
}

variable "prod_subnet_cidr" {
  default = "10.20.2.0/24"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { project = "rhel-fleet-patching" }
  }
}

# Your current public IP: only this address may reach the servers
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  my_cidr    = "${chomp(data.http.my_ip.response_body)}/32"
  prod_names = [for i in range(var.prod_count) : format("prod%02d", i + 1)]
  az         = data.aws_availability_zones.available.names[0]
}

# ------------------------------------------------------------------ network
# A dedicated VPC for the lab, with one subnet for dev and one for prod
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "rhel-fleet-vpc" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "rhel-fleet-igw" }
}

resource "aws_subnet" "dev" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.dev_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "rhel-fleet-dev", env = "dev" }
}

resource "aws_subnet" "prod" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.prod_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "rhel-fleet-prod", env = "prod" }
}

# Route table: send internet-bound traffic through the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = "rhel-fleet-public" }
}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "prod" {
  subnet_id      = aws_subnet.prod.id
  route_table_id = aws_route_table.public.id
}

# Firewall: SSH and metrics from your IP only, everything outbound
resource "aws_security_group" "lab" {
  name        = "rhel-fleet-sg"
  description = "SSH and metrics from my IP only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  ingress {
    description = "node_exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rhel-fleet-sg" }
}

# ------------------------------------------------------------------ servers
# Latest official Red Hat images (309956199498 is Red Hat's AWS account)
data "aws_ami" "rhel8" {
  most_recent = true
  owners      = ["309956199498"]
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*-Hourly2-GP3"]
  }
}

data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"]
  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*-Hourly2-GP3"]
  }
}

resource "aws_key_pair" "lab" {
  key_name   = "rhel-fleet-lab"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

resource "aws_instance" "dev" {
  ami                    = data.aws_ami.rhel8.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.lab.key_name
  subnet_id              = aws_subnet.dev.id
  vpc_security_group_ids = [aws_security_group.lab.id]
  tags                   = { Name = "dev01", env = "dev" }
  depends_on             = [aws_route_table_association.dev]
}

resource "aws_instance" "prod" {
  count                  = var.prod_count
  ami                    = data.aws_ami.rhel9.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.lab.key_name
  subnet_id              = aws_subnet.prod.id
  vpc_security_group_ids = [aws_security_group.lab.id]
  tags                   = { Name = local.prod_names[count.index], env = "prod" }
  depends_on             = [aws_route_table_association.prod]
}

# -------------------------------------------------------------- inventories
# Ansible inventories, written from what was actually built
resource "local_file" "dev_inventory" {
  filename        = "${path.module}/../inventories/dev/hosts.yml"
  file_permission = "0644"
  content = yamlencode({
    all = {
      vars = { env = "dev", aws_region = var.region }
      children = { linux = { hosts = {
        dev01 = { ansible_host = aws_instance.dev.public_ip, instance_id = aws_instance.dev.id }
      } } }
    }
  })
}

resource "local_file" "prod_inventory" {
  filename        = "${path.module}/../inventories/prod/hosts.yml"
  file_permission = "0644"
  content = yamlencode({
    all = {
      vars = { env = "prod", aws_region = var.region }
      children = { linux = { hosts = {
        for i, inst in aws_instance.prod :
        local.prod_names[i] => { ansible_host = inst.public_ip, instance_id = inst.id }
      } } }
    }
  })
}

resource "local_file" "monitoring_targets" {
  filename        = "${path.module}/../inventories/monitoring_targets.yml"
  file_permission = "0644"
  content = yamlencode({
    monitoring_targets = [
      for ip in concat([aws_instance.dev.public_ip], aws_instance.prod[*].public_ip) : "${ip}:9100"
    ]
  })
}

output "instance_ids" {
  value = join(" ", concat([aws_instance.dev.id], aws_instance.prod[*].id))
}

output "vpc_id" {
  value = aws_vpc.lab.id
}
