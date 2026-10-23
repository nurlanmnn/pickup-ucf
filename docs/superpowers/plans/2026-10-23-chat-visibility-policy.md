# Chat session visibility — October 23, 2026

## Threat model and contract

Direct message reads/inserts must require both membership and session visibility.
Blocking a host in either direction hides that game and its chat, including other
players' messages. Existing waitlist membership, retained historical/null-host
chat, blocked-author filtering and suspension write restrictions must remain.

Source observation: the current policy excludes sessions found by a blocked-host
subquery, but session RLS hides precisely those rows. NOT EXISTS can therefore
allow messages in a hidden game. Reproduce both reads and sends before replacing
that negative subquery with the existing private positive visibility gate.

## Reproduction, fix and evidence

Independent red probes failed with `blocked host game still exposes chat messages`
and `blocked host game still accepts chat sends`. Migration 20261023224500 now
uses pickup_private.can_view_session for SELECT and INSERT. This also requires a
current confirmed school account, closing stale confirmation after membership.
No client shape, grant, chat ordering or retained-history rewrite is involved.

Full candidate SQL/RLS passes 36 phase notices inside rollback. Phase T covers
both host-block directions, valid and waitlisted read/send, blocked authors,
retained null-host history, unconfirmed existing members and outsider denial.
Existing suspension/moderation tests pass. Independent review found no actionable
issue; git diff --check passed. Logs: /tmp/pickup-chat-visibility-red.log,
/tmp/pickup-chat-send-red.log, /tmp/pickup-chat-visibility-candidate-sql.log.

Local source only; migration remains undeployed. Existing subscribed/realtime
client buffers are distinct from fresh API authorization and require compatible
candidate/two-account device acceptance after any authorized rollout.
