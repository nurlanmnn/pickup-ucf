# Host-action concurrency — October 23, 2026

`python3 supabase/tests/host_action_concurrency.py` passes against the candidate
schema including both October 23 local fixes. It creates a fresh PostgreSQL 17.6
container with network=none, no host mounts/ports, read-only root, tmpfs data,
empty preloads/listen_addresses and zero background workers. Only schema and
migration history are read from the existing local database; no user rows are
copied and no production connection or database URL is accepted. Before fixtures,
it verifies zero source profiles and no pg_cron/pg_net extension or subscription.
All accounts and games in this exercise are synthetic.

Passed cases:

- Cancellation holds the row lock before join: the waiting join rejects as
  session_not_joinable; cancellation remains final.
- Join holds the row lock before cancellation: both serialize successfully;
  membership counts remain correct on the cancelled game.
- Host reduces capacity before a final-slot join: the join becomes waitlisted.
- Join takes the final slot before host capacity reduction: reduction rejects
  through the existing count/capacity constraint; the game remains full and valid.
- Twelve simultaneous cancellation/join races retain cancelled state, exact
  joined-member counts and capacity bounds.
- Six simultaneous waitlist retries retain the original queue timestamp.

Ordered cases synchronize on a marker after the leading SQL action has acquired
its lock; stress cases use barriers. Each state is checked after both operations
finish. SQL timeouts bound failures. The disposable container is removed in
finally. Docker inventory confirmed none remained after the run; the existing
local database was not edited. Schema prerequisites and migration files are used
only inside the disposable target.

Log: `/tmp/pickup-host-action-concurrency.log`. Expected-error diagnostics are
private in the temporary directory printed by that log. Runtime case count:
four ordered races, twelve simultaneous cancellation/join races and six waitlist
retry connections. Existing duplicate-leave/final-slot/mixed/deletion exclusion
evidence remains recorded in the October 22 plan and was not needlessly rerun.

This closes the missing local host-action/cancellation exercise, not every
possible interleaving or the physical two-account acceptance gate. No production
mutation, source push, deployment, binary change, upload or invitation occurred.
