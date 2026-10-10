# Runbook: a server fails during patching

## What you will see
`playbooks/patch.yml` stops with a red task and the PLAY RECAP shows `failed=1` for one
server. Because the play uses `max_fail_percentage: 0`, no further servers are patched.
Servers that were already patched stay patched; servers not yet reached are untouched.

## 1. Read the failure
Scroll up to the red task. The task name tells you the stage:

| Failed task | Meaning | Go to |
| --- | --- | --- |
| Check free space on / | Not enough disk to patch safely | Section 2 |
| Apply updates | The package manager failed | Section 3 |
| Reboot if required | The server did not come back within 10 minutes | Section 4 |
| Critical services must be running | A service is down after patching | Section 5 |
| No new failed units | A systemd unit failed after patching | Section 5 |

## 2. Not enough disk space
```
ansible <host> -a "df -h /"
ansible <host> -a "dnf clean all"
ansible <host> -m shell -a "journalctl --vacuum-time=7d"
```
Re-run the patch for that server only: add `--limit <host>`.

## 3. Package update failed
```
ansible <host> -a "dnf check"
ansible <host> -m shell -a "dnf history | head"
ansible <host> -m shell -a "tail -50 /var/log/dnf.log"
```
Common causes: a repository is unreachable, a lock held by another dnf process, or a
dependency conflict. Fix the cause, then re-run with `--limit <host>`.

## 4. Server did not come back after reboot
1. Check the instance in the AWS console: EC2 > Instances > select it > Status checks.
2. View the boot output: Actions > Monitor and troubleshoot > Get system log.
3. If it is running but unreachable, check that your public IP has not changed:
   `terraform -chdir=terraform apply` refreshes the security group and the inventory.
4. If it does not boot, roll back from the snapshot (section 6).

## 5. Service or unit failed after patching
```
ansible <host> -a "systemctl --failed"
ansible <host> -a "systemctl status <service>"
ansible <host> -m shell -a "journalctl -u <service> -b --no-pager | tail -50"
```
Decide:
- **Fix forward** if the cause is clear and small (a config option renamed, a service
  needing a restart). Fix it, then re-run with `--limit <host>` to confirm the post-checks pass.
- **Roll back** if the cause is unclear or the fix would exceed the change window.

## 6. Roll back from the snapshot
The snapshot ID for each server is in the last column of `reports/patch-log.csv` and in
the AWS console under EC2 > Snapshots, named `pre-patch-<host>`.

```
# 1. Identify the instance, its availability zone and its current root volume
aws ec2 describe-instances --instance-ids <instance-id> \
  --query "Reservations[0].Instances[0].[Placement.AvailabilityZone,BlockDeviceMappings[0].Ebs.VolumeId]" --output text

# 2. Create a new volume from the pre-patch snapshot, in the same availability zone
aws ec2 create-volume --snapshot-id <snapshot-id> --availability-zone <az> --volume-type gp3

# 3. Stop the instance and swap the root volume
aws ec2 stop-instances --instance-ids <instance-id>
aws ec2 wait instance-stopped --instance-ids <instance-id>
aws ec2 detach-volume --volume-id <old-volume-id>
aws ec2 attach-volume --volume-id <new-volume-id> --instance-id <instance-id> --device /dev/sda1

# 4. Start it and refresh the inventory, because the public IP changes
aws ec2 start-instances --instance-ids <instance-id>
terraform -chdir=terraform apply
```
Verify with `ansible <host> -m ping` and `ansible <host> -a "uname -r"`: the kernel
should be the pre-patch version. Keep the old volume until the cause is understood,
then delete it.

Note: Terraform will see the replaced root volume as drift. In a production setup the
rollback would be scripted and the state reconciled; here, record it in the change record.

## 7. Resume the rollout
Once the failed server is fixed or rolled back and the cause is understood:
```
ansible-playbook playbooks/patch.yml -i inventories/prod/hosts.yml
```
Already-patched servers report no changes and the rollout continues.

## 8. Afterwards
Update the change record with what failed, the decision taken and the time to recover.
If the failure could recur, add a pre-check for it to `roles/patching/tasks/precheck.yml`.
