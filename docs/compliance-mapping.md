# Compliance mapping

The baseline is built on the **CIS Benchmark for Red Hat Enterprise Linux, Level 1 - Server**
and measured with **OpenSCAP** using the SCAP Security Guide profile `cis_server_l1` that
ships with RHEL. CIS is a technical configuration standard; NIST SP 800-53, the NIST
Cybersecurity Framework, FedRAMP and ISO/IEC 27001 are control frameworks that it supports.

The mapping below is a working mapping for this lab. It should be verified against the
current benchmark and an organisation's own control catalogue before being used in an audit.

## Measured results (9 October 2026)

| Server | Stage | Passed | Failed | OpenSCAP score |
| --- | --- | --- | --- | --- |
| dev01 (RHEL 8.10) | Stock AWS image | 183 | 115 | 78.66% |
| dev01 (RHEL 8.10) | After baseline, round one | 207 | 93 | 82.07% |
| dev01 (RHEL 8.10) | After baseline, round two | 220 | 80 | 83.26% |
| prod01 to prod04 (RHEL 9.6) | Stock AWS image | 154 | 106 | 76.42% |
| prod01 to prod04 (RHEL 9.6) | After baseline | 192 | 70 | 80.02% |

High-severity failures on dev01 fell from 3 to 1.

## What the project does, by control

| Project feature | Where | NIST SP 800-53 | NIST CSF 2.0 function |
| --- | --- | --- | --- |
| Standard configuration applied from code | `roles/baseline` | CM-2, CM-6 | Protect |
| Unused filesystem modules disabled | `roles/baseline` | CM-7 | Protect |
| SSH: no root login, keys only, limited retries | `roles/baseline` | AC-17, IA-2, AC-6 | Protect |
| SSH idle session timeout | `roles/baseline` | AC-12, SC-10 | Protect |
| Login warning banner | `roles/baseline` | AC-8 | Protect |
| SELinux enforcing | `roles/baseline` | AC-3, AC-6 | Protect |
| Host firewall on, AWS security group limited to one IP | `roles/baseline`, `terraform` | SC-7 | Protect |
| Dedicated VPC with separate dev and prod subnets | `terraform` | SC-7, AC-4 | Protect |
| Kernel network hardening, SYN cookies, ASLR | `roles/baseline` | SC-5, SC-7, SI-16 | Protect |
| Strong crypto policy (no SHA-1 on RHEL 8) | `roles/baseline` | SC-13 | Protect |
| Password quality, maximum age, inactive-account expiry | `roles/baseline` | IA-5, AC-2 | Protect |
| Empty passwords refused | `roles/baseline` | IA-5 | Protect |
| File integrity monitoring with AIDE, nightly check | `roles/baseline` | SI-7, AU-9 | Detect |
| Time synchronisation | `roles/baseline` | AU-8 | Detect |
| Audit logging enabled | `roles/baseline` | AU-2, AU-12 | Detect |
| Security patching, dev before prod, with rollback snapshot | `roles/patching` | SI-2, CM-3 | Protect |
| Compliance scan and score per server | `roles/compliance` | CA-2, CA-7, RA-5 | Identify, Detect |
| Monitoring and alerting | `roles/node_exporter`, `roles/prometheus_server` | SI-4, CA-7 | Detect |
| Configuration backups with tested restore | `roles/backup` | CP-9, CP-10 | Recover |
| Server inventory report | `playbooks/inventory_report.yml` | CM-8 | Identify |
| Change record and runbooks | `docs/` | CM-3, IR-4 | Govern, Respond |

## How the frameworks relate

- **CIS Benchmark / DISA STIG**: the actual settings on the server. This is what gets configured and scanned.
- **NIST SP 800-53**: the control catalogue those settings satisfy.
- **FedRAMP**: a US government cloud authorisation programme that uses NIST SP 800-53 baselines.
- **NIST CSF**: a high-level way to organise and report on a security programme.
- **ISO/IEC 27001**: a management-system standard; server hardening supports its technical controls.
- **NERC CIP**: the mandatory standard for the North American bulk electric system; secure
  baselines, patching and change control support its configuration and patch requirements.

## Known gaps

The lab applies a subset of CIS Level 1, so the scan does not report 100%. Left for a
production build, each with its reason:

| Gap | Why it was left |
| --- | --- |
| Account lockout and password history (PAM faillock, pwhistory) | Changes the login stack; a mistake locks administrators out, so it needs console access and staged testing |
| `/tmp`, `/var` and others on separate partitions | Requires a custom disk layout at build time, not a change to a running server |
| Full CIS audit rule set | Large rule set that needs tuning against log volume |
| CIS custom crypto policy modules | Needs testing against every client that connects |
| Central log forwarding | No log server in the lab |

The OpenSCAP HTML report lists every remaining rule with its remediation.
