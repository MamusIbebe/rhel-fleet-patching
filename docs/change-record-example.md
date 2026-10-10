# Change record (example)

A worked example based on the patch run performed in this lab on 9 October 2026.
The layout follows a typical ITIL-style change request.

| Field | Value |
| --- | --- |
| Change ID | CHG-2026-1009-01 |
| Title | Monthly security patching, RHEL fleet |
| Type | Standard change, pre-approved procedure |
| Requested by | Linux platform team |
| Environment | dev (1 server), then prod (4 servers) |
| Window | 9 October 2026, 16:00 to 16:30 Eastern |
| Risk | Low to medium: kernel update requires a reboot of each server |

## Scope
Apply Red Hat security errata to `dev01` (RHEL 8.10) and `prod01` to `prod04` (RHEL 9.6)
using `playbooks/patch.yml`. No application changes.

## Implementation plan
1. Patch dev: `ansible-playbook playbooks/patch.yml`
2. Confirm dev is healthy: PLAY RECAP shows `failed=0`, services running, monitoring green.
3. Patch prod: `ansible-playbook playbooks/patch.yml -i inventories/prod/hosts.yml`
   - `prod01` is patched alone as a canary.
   - The remaining servers follow in batches of half the fleet.
   - The run stops on the first failure (`max_fail_percentage: 0`).

For each server the role checks free disk space, records failed services and the kernel,
takes an AWS snapshot, applies security updates, reboots only if required, verifies
critical services, renews the AIDE database and writes a line to `reports/patch-log.csv`.

## Rollback plan
Each server has an EBS snapshot taken immediately before patching. To roll back a
server, follow `docs/runbook-patch-failure.md`, section "Roll back from the snapshot".

## Validation
- `sshd`, `chronyd`, `firewalld` and `auditd` are running on every server.
- No new failed systemd units compared with before the change.
- All servers show UP in Prometheus and green on the Grafana fleet status dashboard.
- Kernel version in `reports/inventory-prod.csv` matches the patched kernel.

## Result
Successful. No rollback needed.

| Server | Started (Eastern) | Rebooted | Pre-patch snapshot |
| --- | --- | --- | --- |
| dev01 | 16:00 | Yes | snap-0f621536870ba2324 |
| prod01 (canary) | 16:09 | See patch log | snap-06e67db89bbb731bb |
| prod02 | 16:14 | See patch log | snap-0f273e18132eca74f |
| prod03 | 16:14 | See patch log | snap-0a6356cf75e3cc1d0 |
| prod04 | 16:20 | See patch log | snap-05c866033282378d2 |

`dev01` moved from kernel 4.18.0-553.158.1 to 4.18.0-553.172.1. Kernel versions before
and after for every server are recorded in `reports/patch-log.csv`.

## Communication
In production: notify application owners 5 working days ahead, post in the operations
channel at the start and end of the window, and attach this record to the ticket.

## Post-change tasks
- Delete the pre-patch snapshots after the agreed retention period (for example 7 days).
- Re-run `playbooks/compliance_scan.yml` to confirm the compliance score did not regress.
