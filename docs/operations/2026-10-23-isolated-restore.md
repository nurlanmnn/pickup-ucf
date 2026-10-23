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
ten October 22 migrations were not replayed here, and cron-dependent migrations
must not be run unchanged in this environment. Its older RPC grants and deletion
behavior are unsuitable for service exposure or production rollback.

A complete recovery still requires the correct managed auth schema, roles and
migration history; platform/Storage recovery; separate secret/Vault, function,
cron and hosted-auth configuration recovery; and controlled forward migration to
the approved security boundaries. Provider login, APNs, email, encryption-key
recovery, and restored service operation were not tested. Document backup owner,
frequency/retention, acceptable data loss and recovery time before external beta.
The prior hosted WALG/no-PITR metadata was not refreshed in this exercise.

Reference workflow: [Supabase logical backup/restore documentation](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
