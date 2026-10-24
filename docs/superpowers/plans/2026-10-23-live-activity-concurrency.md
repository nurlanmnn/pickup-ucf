# Live Activity registration and lifecycle ordering

October 23, 2026. Local candidate evidence only; migration remains undeployed.

## Reproduced defect

`register_live_activity_token` checked eligibility without locking the session.
An authenticated host cancellation ran its cleanup trigger and held its transaction
open; a player's concurrent registration still saw the old open game and inserted
its token. Both committed: the cancelled game retained one token with `ended_at`
NULL and `ends_at` in the future. The original disposable regression printed
`accepted=True, future active tokens=1` and failed its final invariant. Its
container was removed; existing local rows and production were untouched.

## Change and contract

Migration `20261023232500_serialize_live_activity_registration.sql` replaces only
the registration function. It keeps token validation, ownership, normalization,
per-device storage, duplicate delivery-state preservation and terminal-state guards.
The caller's auth row takes KEY SHARE before the session takes SHARE. Account
deletion takes auth UPDATE before session UPDATE; this order prevents deletion
and the token's profile foreign key from forming a cycle. Different registrations
can share the session lock, while lifecycle edits and join/leave wait.

The eligibility SELECT is a separate statement after the lock, so participant
predicates see commits made while waiting. Transaction-wide repeatable-read and
serializable snapshots are rejected with SQLSTATE 40001 rather than relying on
stale membership. Default PostgREST READ COMMITTED remains compatible. See
[PostgreSQL row locks](https://www.postgresql.org/docs/17/explicit-locking.html)
and [transaction snapshots](https://www.postgresql.org/docs/17/transaction-iso.html).
The Supabase changelog was checked; no client/platform upgrade is part of this fix.

## Verification

Command: `PYTHONDONTWRITEBYTECODE=1 python3 supabase/tests/live_activity_concurrency.py`.
All writes use the existing schema-only disposable harness: network disabled,
read-only container root, tmpfs database, no background extension workers and no
source user rows. Container removal runs in finally. The existing local database
was read only for schema and migration history, never migrated.

- Full candidate SQL/RLS: all 38 phase notices, inside rollback.
- Cancellation, leave, eligible schedule edit and moving outside the one-hour
  eligibility window: both orders each. Invalid games retain zero future active
  tokens; eligible edits retain exactly the canonical stored schedule.
- Different device registrations finish concurrently before the first commits.
  Same-token concurrent retries produce one row. Normalized duplicates preserve
  delivery fields; other user/session ownership is rejected.
- Ended and expired token retries do not resurrect or modify terminal rows.
- Player account deletion and host deletion against a player's registration:
  both orders, no FK/deadlock error, no active token survives. Stale deleted caller
  is rejected. Host-own registration followed by deletion also passes.
- Repeatable read and serializable both reject with SQLSTATE 40001.

Ordered conflicting cases observe the follower's actual `pg_stat_activity` lock
wait before committing the leader. Compatible registrations must finish before
leader release; timing alone does not establish ordering.

Independent design and final source/test reviews found no required changes.
Final review completed October 24 after the usage-limit interruption. No Swift or Edge source
changed, so their unchanged passing suites were not repeated. This does not
establish physical ActivityKit/APNs delivery, production migration acceptance or
permission to deploy, merge or upload a binary.
