# Attendance ledger access — October 23, 2026

## Contract

Attendance is a server-owned ledger. Current source and build 5 read the joined
participant roster for the host form and submit through a definer RPC. Profile
history separately reads the caller's own attendance rows. Preserve both paths,
while withholding other users' ledger rows that could bypass blocked-identity or
hidden-game protections. No stored history or RPC payload changes.

Reproduce a blocked identity exposed through a member's direct ledger read using
synthetic rollback fixtures. Restrict direct reads to the current school user's
own rows; keep direct writes revoked and trusted service/RPC access intact.

## Local fix and evidence

The red probe failed with `attendance ledger reveals blocked participant identity`.
An initial uncommitted proposal revoked all direct reads; independent review
caught the build-5 ProfileHistoryRepository caller outside Repositories/. The
final migration 20261023230500 preserves authenticated SELECT with own-row RLS,
requires the authoritative school account, and revokes direct writes. No broken
proposal was committed or pushed.

Full candidate SQL/RLS passes 38 phase notices inside rollback. Phase V proves
other blocked ledger identities are hidden, own historical attendance/session
joins work, host participant-form rows remain available, repeated RPC submission
works and statistics increment once. Independent re-review found no remaining
actionable issue; git diff --check passed. Logs:
/tmp/pickup-attendance-access-red.log and /tmp/pickup-attendance-candidate-sql.log.

Local source only; migration is undeployed. No Swift/Edge source changed, so their
unchanged passing suites were not repeated.
