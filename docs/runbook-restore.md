# Runbook: restore a configuration file from backup

## When to use
A file under `/etc` on a managed server was changed or deleted by mistake and the
server needs the last known-good copy.

## What exists
- `playbooks/backup.yml` archives `/etc` on every server and stores it on the control
  node under `/srv/backups/<hostname>/etc-<date>.tar.gz`.
- `playbooks/restore_file.yml` restores one file from the newest archive.

## Steps
1. Confirm the damage and note the file path, for example `/etc/motd`.
2. List the backups for the server and check the date of the newest one:
   `ls -lh /srv/backups/<hostname>/`
3. Restore the file. The path is given without the leading slash:
   `ansible-playbook playbooks/restore_file.yml -e target=<hostname> -e restore_path=etc/motd`
   Add `-i inventories/prod/hosts.yml` for a prod server.
4. Verify on the server: `ansible <hostname> -a "cat /etc/motd"`
5. If the file belongs to a service, restart or reload that service and check its status.
6. Record what was restored, from which backup, and why, in the change record.

## If the newest backup is also bad
List the archives, pick an older one, and extract by hand:
`tar -xzf /srv/backups/<hostname>/etc-<date>.tar.gz -C /tmp etc/<file>`
then copy it back with `ansible <hostname> -m copy -a "src=/tmp/etc/<file> dest=/etc/<file>"`.

## Limits
- Only `/etc` is backed up. Application data needs its own backup.
- A whole-server failure is recovered from the pre-patch AWS snapshot or rebuilt with
  Terraform and `playbooks/site.yml`, not from these archives.
