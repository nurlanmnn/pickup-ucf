# Moderation report concurrency — October 23, 2026

## Reproduction and change

Six simultaneous authenticated reports by one synthetic confirmed school user,
each targeting a different user, committed **six reports** against the prior
candidate function. The configured hourly maximum is five. A test-only BEFORE
INSERT delay widened the real count/insert overlap; no function was mocked.
The failed assertion checked committed rows after all requests completed.

Migration `20261023231500_serialize_report_submissions.sql` takes the reporter's
existing `auth.users` row `FOR NO KEY UPDATE` before authorization/count/insert.
This serializes even the first reports, when no audit rows exist to lock.
It preserves confirmed-school identity, suspension/content/target checks,
duplicate error behavior, the 5/hour and 20/day limits, function ACLs, and retained
audit rows without auth FKs. There is no counter table or auth-column update.

The lock is compatible with join/create `FOR KEY SHARE` and follows deletion's
account-before-session order. Target snapshots use ordinary reads; reciprocal
reports do not lock each other's accounts. Same-reporter submissions wait until
the preceding transaction commits or rolls back. Errors release their locks.

The VOLATILE PL/pgSQL function counts in a separate statement after acquiring
the lock, so the normal READ COMMITTED path sees the preceding commit. A row lock
alone cannot refresh a transaction-wide snapshot. Repeatable read and serializable
SQL callers therefore fail closed with `40001 / report_requires_read_committed`;
they must start a new READ COMMITTED transaction. Read uncommitted has PostgreSQL's
READ COMMITTED behavior and is also allowed. The current API's default behavior
is preserved. References: [PostgreSQL isolation](https://www.postgresql.org/docs/17/transaction-iso.html),
[row locks](https://www.postgresql.org/docs/17/explicit-locking.html),
[PostgREST transaction isolation](https://docs.postgrest.org/en/stable/references/transactions.html#isolation-level).

## Verification

`PYTHONDONTWRITEBYTECODE=1 python3 supabase/tests/report_concurrency.py` passed:

- Full candidate SQL/RLS: **38 phase notices**, inside rollback in the disposable DB.
- Six distinct simultaneous targets: exactly five accepted, one rate-limited.
- Nineteen reports aged two hours plus six simultaneous targets: exactly one
  accepted, five rate-limited; twenty total persisted reports.
- Hourly and daily window recovery preserves all old audit rows.
- Reporter B succeeds with a 500ms lock timeout while A holds an uncommitted report.
- Same-target duplicate waits, returns `report_already_submitted`, and a later
  valid target succeeds; the duplicate consumes no quota.
- Actual account deletion first denies the waiting report. Report first allows
  deletion afterward, retaining the report and target snapshot without an account.
- Reciprocal reporters both succeed without deadlock.
- Established repeatable-read and serializable snapshots reject with SQLSTATE
  `40001` and persist no reports.

An independent review of the design and final SQL/test diff found no required
findings. Two test-fixture assumptions were corrected during development: the
losing race target is nondeterministic, and application roles cannot directly
read the moderation table to establish a snapshot. Final tests use a fresh
recovery target and `pg_current_snapshot()`.

The suite reuses the existing host-action harness through a callback after its
isolation/schema checks. The source DB contributes only schema and migration
history; all fixture rows are synthetic. The fresh PostgreSQL 17.6 container has
network=none, no host mounts/ports, read-only root, tmpfs data, empty preloads/listen
addresses and zero background workers. It verifies no source rows, pg_cron,
pg_net or subscription before tests, and is removed in finally, including failures.
Final Docker inventory showed no exercise container. Existing local migration
head remains `20261005150000`, with no atomic creation RPC installed.

This is local source/SQL evidence. No production mutation, deployment, merge,
binary change/upload, device check or invitation occurred. Unchanged iOS/Edge
suites were not repeated. Nine October 23 migrations now remain undeployed.
