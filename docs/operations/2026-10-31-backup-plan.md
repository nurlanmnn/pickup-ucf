# Backup and recovery proposal — October 31, 2026

**Proposal only.** No purchase, export, upload, scheduled job, credential change
or restore is authorized by this document. Owner confirmed today that there is
no off-site copy and requested a plan.

**Owner decision:** stay on Free until real-user adoption justifies spending.
No user-count threshold has been chosen. Paid backups/PITR are deferred.

## Verified starting point

Read-only production Dashboard checks on October31 show the organization on
Free. Scheduled backups says Free does not include project backups; Point in
time shows the Pro add-on offer, with no enabled recovery window.

The [October23 exercise](2026-10-23-isolated-restore.md) records an October22
restricted local snapshot, successful isolated logical restore, forward migration
checks and explicit managed-auth/platform limits. That historical snapshot is
not a current backup of the October31 production state. Its files were not read
or copied during today's check.

## Recommended no-subscription plan

1. Keep the existing Supabase Free project. Use the Mac as the initial backup
   runner, with a daily scheduled attempt and a catch-up check when it next runs.
   Keep database credentials in an approved local credential store, outside Git
   and logs. Do not add a paid runner or new subscription.
2. Make a fresh logical recovery set, encrypt it locally, and copy only encrypted
   artifacts to an owner-selected private off-site location independent of this
   Mac and the Supabase account. Include supported database roles/schema/data,
   auth compatibility requirements, migration inventory, version metadata and
   integrity manifest. Exports contain sensitive data, including auth material;
   exact scope, destination and encryption/key custody need approval before
   export or upload. Do not reset a database password merely to follow an example.
3. Use existing cloud-storage capacity, such as a private Google Drive folder,
   after the owner selects the destination and available space is checked. No
   public sharing. Target one successful encrypted off-site copy daily. Retain seven daily and
   four weekly recovery points; approve expiry separately before removing any
   existing artifacts. A sleeping/offline Mac is
   not evidence of a completed nightly backup. Record last successful upload and
   verified checksum privately. Notify the owner on failure or a recovery point
   older than 26 hours, without records, credentials or dump contents in alerts.
   A Mac-only check cannot alert while that Mac is off; show the stale-backup
   warning on its next run. Independent monitoring remains a later improvement.
4. Keep the decryption key in the owner's password manager with an independent
   recovery method. Do not keep the only key beside the backup. Document access
   and a named backup responder without publishing credentials in Git.
5. Restore a fresh recovery point into an isolated environment before launch,
   then monthly and after material recovery-path changes. Follow the existing
   network-disabled/container isolation pattern first. Keep cron, email, push,
   subscriptions and provider credentials inactive around restored data. Verify
   integrity/counts/FKs, schema/RLS/grants, auth compatibility and a rolled-back
   synthetic lifecycle. A separate hosted exercise must establish managed auth
   and service recovery before claiming full platform recovery. Record elapsed
   time, outcome and cleanup; never overwrite production for a drill.

**Proposed targets for owner decision:** at most **24 hours of lost database
changes** (RPO), and **one business day to restore service** (RTO). These are
targets, not measured guarantees. A Mac-based schedule cannot guarantee a daily
recovery point while the Mac is unavailable. Record the actual latest successful
off-site copy and revise these targets after testing. Revisit managed backups
when real-user adoption, operational burden or recovery needs justify spending;
do not invent a user-count threshold or upgrade automatically.

## Recover more than the database

Database backups exclude Storage object contents. Inventory actual Storage usage
and, if present, back up object bytes with matching metadata and retention.
Separately inventory the recovery method and owner for Edge Function revisions,
cron configuration, Vault/secrets, Auth/email/provider configuration, APNs keys,
Apple signing/distribution access, associated domains and the support site.
Git source does not establish deployed configuration or secret recovery. Preserve
deletion/retention obligations when restoring older data; keep restored services
isolated until post-backup deletions and revocations have been reconciled.

## First implementation increment

After destination/key custody and export scope are approved, complete one fresh
encrypted backup, upload it privately, verify the downloaded ciphertext checksum,
and test decryption/restoration in isolation. Then add scheduling and missed-run
handling. A single successful copy improves safety but does not establish a
recurring system. Existing local backup files stay untouched.

## Decisions and acceptance still open

Local preparation: the [encryption helper](../../tools/recovery/README.md) uses
Homebrew age1.3.2 and passed11 synthetic local checks, including real decryption,
tamper/wrong-key rejection and file/error safety. Fresh review found and fixed
argument-error echo and restrictive-umask output permissions. This is tool
preparation only; no persistent owner key, production export, upload or schedule
has been created. A metadata-only Drive search found no PickUp folder; propose
a new owner-private **PickUp UCF Backups** folder, with sharing verified before
any upload. Drive quota is not yet checked.

- Free/self-managed is the owner's chosen direction; no paid plan is pending.
- Accept/revise RPO/RTO; choose encrypted-copy destination, key custody, runner
  and backup responder. No target or storage destination is owner-approved.
- Approve the exact new production export and encrypted upload scope separately.
- Verify fresh backup/upload, failure notification and isolated restoration;
  complete the managed-service recovery inventory. No recovery gate is closed.

References checked October31: [pricing](https://supabase.com/pricing),
[backup coverage and exclusions](https://supabase.com/docs/guides/platform/backups),
[logical backup/restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
The current changelog index was scanned; no database upgrade or restore is being
implemented in this proposal.
