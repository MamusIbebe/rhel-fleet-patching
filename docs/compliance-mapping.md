# Compliance mapping

The baseline is built on the **CIS Benchmark for Red Hat Enterprise Linux, Level 1 - Server**
and measured with **OpenSCAP** using the SCAP Security Guide profile `cis_server_l1` that
ships with RHEL. CIS is a technical configuration standard; NIST SP 800-53, the NIST
Cybersecurity Framework, FedRAMP and ISO/IEC 27001 are control frameworks that it supports.

The mapping below is my own working mapping for this lab. Verify it against the current
benchmark and your organisation's control catalogue before relying on it for an audit.

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
| Kernel network hardening, SYN cookies, ASLR | `roles/baseline` | SC-5, SC-7, SI-16 | Protect |
| Strong crypto policy (no SHA-1 on RHEL 8) | `roles/baseline` | SC-13 | Protect |
| Time synchronisation | `roles/baseline` | AU-8 | Detect |
| Audit logging enabled | `roles/baseline` | AU-2, AU-12 | Detect |
| Security patching, dev before prod, with rollback snapshot | `roles/patching` | SI-2, CM-3 | Protect |
| Compliance scan and score per server | `roles/compliance` | CA-2, CA-7, RA-5 | Identify, Detect |
| Monitoring and alerting | `playbooks/monitoring.yml` | SI-4, CA-7 | Detect |
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
  baselines, patching and change control here support its configuration and patch requirements.

## Known gaps

This lab applies a subset of CIS Level 1, so the scan will not report 100%. Rules left
for a production build include disk partition layout, password ageing and complexity
policy, file integrity monitoring (AIDE), and full audit rules. The scan report lists each one.
