# Waitlist retry priority — October 23, 2026

BETA-14 requires stable repeated join behavior. The deployed join RPC's waitlist
upsert reset `joined_at` on every retry while full, moving a waiting player back
in the FIFO queue. A local synthetic full-game fixture reproduced this with
`join retry changed waitlist priority` against the pre-fix candidate functions.

Migration `20261023215505_preserve_waitlist_retry_priority.sql` retains the
account-before-session locks and existing RPC contract. The waitlist conflict
update now skips an already-waitlisted row. Retries preserve its original queue
timestamp; an explicit leave followed by a new join resets queue time. The
existing available-slot path can still admit a waiter when capacity changes.

`phase_p_waitlist_retry.sql` covers two retries, one membership row, unchanged queue
time and fresh leave/rejoin. The current fixture fails against the previous join
definition and passes with the fix. The complete local candidate SQL/RLS suite
passed with **32 phase-success notices**, including the preceding host-edit fix,
inside rollback. Log: `/tmp/pickup-waitlist-retry-candidate-sql.log`;
red reproduction: `/tmp/pickup-waitlist-retry-red.log`.

Review: the row remains serialized by the session lock; no new lock, query, role,
grant or external side effect is introduced. Skipping the no-op conflict update
also avoids unnecessary tuple/trigger work. Nullability is unchanged. Full
host-action/cancellation concurrency and device acceptance remain separate gates.

Local source only: neither October 23 migration has been deployed. Production,
TestFlight build 5 and the older local schema baseline remain unchanged. No push,
upload, invitation or external review submission occurred.
