# Isolated logical restore — October 23, 2026

Completed at approximately 5:15 PM America/New_York on source checkout `a67e29b`,
branch `codex/calendar-write-only`. This exercised the actual October 22 restricted
snapshot, not synthetic replacement data. No production connection was used.

## Result and scope

- All five recovery files matched their saved byte lengths and SHA-256 manifest.
- Restored the saved `public` and `pickup_private` schema and every populated
  auth/application COPY block into a fresh disposable PostgreSQL container.
- All 38 imported table blocks matched source row counts. All 44 restored
  foreign-key relationships passed explicit orphan checks after trigger-disabled
  import. COPY also enforced existing unique and CHECK constraints.
- The refresh-token sequence was not behind its restored data. All restored
  application/private tables had RLS enabled. This is not a role-policy audit.
- No pg_cron/pg_net extension or subscription was installed. Listen addresses and
  shared preloads were empty, and max_worker_processes was zero.
- Removed the disposable container after verification. Its database lived only in
  tmpfs. The existing `supabase_db_pickup-ucf` remained running and healthy; only its
  auth schema was read with schema-only pg_dump, without accessing local user rows.

The snapshot's data header reports server 17.11 and pg_dump 17.6. The available
Supabase PostgreSQL image was `17.6.1.121` (server 17.6). Logical import and checks
passed on that target; compatibility with a fresh hosted platform is untested.

## Auth compatibility boundary

The snapshot does not contain managed auth DDL. Bootstrapped auth tables/functions
from the existing local stack's schema-only dump and created only required local
NOLOGIN roles and crypto extensions. Auth primary/foreign-key definitions must be
installed **before** application schema, whose FKs reference auth.users. The first
application-schema attempt failed on that ordering dependency and rolled back;
installing auth post-data DDL resolved it before any snapshot data was imported.

Six auth COPY blocks were incompatible with that local schema and were verified
empty before omission: `custom_oauth_providers`, `mfa_recovery_code_sets`,
`mfa_recovery_codes`, `one_time_tokens`, `scim_tokens`, and `scim_users`.
The replay helper refuses to omit a populated block. Every populated auth block
was imported without removing columns. This does not verify those six tables or
recover the original managed auth schema/version.

## Isolation and restricted replay materials

Snapshot directory: `/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-22`.
Exercise directory: `/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-23-exercise`.
Both remain private, outside Git. Exercise files include `restore.py`,
`validate.sql`, `source-counts.json`, schema-only prerequisites, private logs and
`evidence.json`. Logs may contain sensitive diagnostics; do not print or commit them.

To repeat this exact scoped exercise, first confirm that the disposable name is
unused, the recorded local auth schema baseline is still appropriate, and the
existing local database is available for schema-only reads. Never replace the
local database or use a production database URL. Create the fresh container:

```sh
docker run -d --name pickup-restore-20261023 \
  --network none --user postgres --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --tmpfs /restore:rw,nosuid,nodev,mode=0700,uid=100,gid=101 \
  --tmpfs /tmp:rw,nosuid,nodev,mode=1777 \
  --entrypoint sh public.ecr.aws/supabase/postgres:17.6.1.121 -c \
  'initdb -D /restore/db --auth-local=trust --auth-host=reject >/tmp/init.log 2>&1 && exec postgres -D /restore/db -k /tmp -c listen_addresses= -c shared_preload_libraries= -c max_worker_processes=0 -c logging_collector=off -c log_statement=none -c log_min_error_statement=panic -c log_min_messages=panic'
```

Wait until `docker exec pickup-restore-20261023 pg_isready -h /tmp -U postgres`
succeeds. Inspect network=none, no published ports/host mounts, read-only root and
the two tmpfs mounts before reading snapshots. Run the restricted `restore.py`
with Python 3. It verifies isolation and the original manifest, installs local auth
prerequisites, imports the snapshot schema, and imports compatible data in a
transaction with ON_ERROR_STOP and session_replication_role=replica. Triggers stay
disabled during import; normal sessions return to origin mode afterward.

Then run the private validator without displaying rows or diagnostic contents:

```sh
docker exec -i pickup-restore-20261023 psql -X -h /tmp -U postgres \
  -d postgres -v ON_ERROR_STOP=1 \
  < /Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-23-exercise/validate.sql \
  > /Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-23-exercise/replay-validation.log 2>&1
docker rm -f pickup-restore-20261023
```

Use private file permissions (umask 077) for replay output. Always remove this
specific disposable container on failure too. Never enable networking, background
workers, cron, email, APNs, Edge Functions or API services around restored data.

## Remaining recovery gates

This is a **pre-rollout logical snapshot**, not the current deployed schema. The
ten October 22 migrations were not replayed in the first exercise above; the
follow-on below establishes a separate safe replay environment. The first
exercise's older RPC grants and deletion
behavior are unsuitable for service exposure or production rollback.

A complete recovery still requires the correct managed auth schema, roles and
migration history; platform/Storage recovery; separate secret/Vault, function,
cron and hosted-auth configuration recovery; and controlled forward migration to
the approved security boundaries. Provider login, APNs, email, encryption-key
recovery, and restored service operation were not tested. Document backup owner,
frequency/retention, acceptable data loss and recovery time before external beta.
The prior hosted WALG/no-PITR metadata was not refreshed in this exercise.

Reference workflow: [Supabase logical backup/restore documentation](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

## Restore plus forward migrations — approximately 5:46 PM

A second fresh container, `pickup-restore-forward-20261023`, restored the same
actual snapshot and replayed **all ten deployed migration files unchanged** in
rollout order through `20261022170532`. All ten transactions passed. The same
six empty incompatible auth blocks remain excluded; managed-auth/platform
limitations above still apply.

This container retained network=none, no ports/host mounts, read-only root, tmpfs
data, empty listen_addresses and max_worker_processes=0. The only preload was
pg_cron 1.6.4, with `cron.launch_active_jobs=off` set on the command line **before
reading snapshots**. The real cron API/metadata could be created with zero cron
workers. Exact schedule DDL therefore replayed without a scheduler or modified
migrations. No pg_net extension, subscriptions, API services or provider secrets
were loaded. [pg_cron's documented setting](https://github.com/citusdata/pg_cron#extension-settings)
disables active-job launches. All job rows were additionally deactivated after
replay. Final job-run, active-job and cron-worker counts were all zero.

Validation passed before replay, after replay and after a synthetic lifecycle
transaction rolled back:

- All 38 source/restored table-count checks and 44 FK checks passed. The migration
  deleting old queued 15-minute reminders affected zero snapshot rows.
- Sequence position, table RLS flags, nullable-host SET NULL behavior, activity
  lifecycle column, null-recipient cleanup guard, internal RPC denial, permitted
  client RPCs and direct mutation restrictions passed metadata assertions.
- The synthetic transaction passed atomic create retry, join/counts, chat insert,
  host account deletion/retry, retained anonymized game/other-player message,
  stale deleted-account JWT denial and cleanup retry. ROLLBACK preserved restored
  counts. No production account was changed.
- Read-only production catalog comparison matched **46/46 application functions**:
  signatures, definition fingerprints, SECURITY DEFINER flags and effective
  anon/authenticated/service-role execute permissions.
- The same comparison matched **148/148 catalog entries**: 18 tables (column
  definitions/RLS/effective column privileges), 16 policies, 64 constraints,
  36 indexes and 14 application triggers. App-owned triggers on managed tables
  were included when present. No table rows or function bodies were retrieved
  from production; only metadata/fingerprints were returned.

Catalog parity at this timestamp does not prove every policy's semantics, managed
role parity, current data freshness, provider recovery or complete platform
recovery. Live project metadata reports PostgreSQL 17.11.0.002; the restored target
remains the available 17.6 image.

Restricted materials are in
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-23-forward-exercise`:
`restore.py`, baseline/forward validators, migration filenames/hashes/exit codes,
synthetic lifecycle SQL, parity metadata and private logs. To repeat, use a fresh
container with the original run command above, change its name to the follow-on
name, and replace the empty preload with
`-c shared_preload_libraries=pg_cron -c cron.launch_active_jobs=off`. Keep workers
at zero. Verify network/mount/runtime isolation and zero cron workers, then create
the pg_cron extension. Run the follow-on private helper, baseline validator, all
ten original migration files in recorded order (psql -X, ON_ERROR_STOP, transaction
per file), forward validator, synthetic lifecycle (ROLLBACK), and forward validator
again. Capture output privately and remove this specific disposable container,
including on failure.

The follow-on container was removed; no restore container remains. The existing
local Supabase database remained healthy. Remaining gates include managed auth
DDL, roles/history, platform/Storage/configuration and secret recovery, plus
backup ownership, frequency/retention and RPO/RTO decisions.
