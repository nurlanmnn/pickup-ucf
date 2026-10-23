# Participant read minimization — October 23, 2026

## Threat model and contract

A confirmed UCF caller can craft direct Data API reads, bypassing the app's
explicit selects and roster RPC. Participant identities and game membership must
respect session visibility and block relationships. Raw waitlist identities are
not part of the public roster: it returns only a count and the caller's position.

Preserve direct self membership/status reads (My Games and participant status),
joined roster reads for visible games, and host attendance reads for their own
past games. Preserve RPC ordering/counts and existing build-5 queries. No changes
to privileged join/leave, attendance or moderation operations are proposed.

First reproduce direct reads of another user's inaccessible historical membership
and visible game's waitlist row. Only then restrict participants_select using the
existing private session visibility gate; own rows stay readable and other users
require joined status, a visible game and no block relationship. No new grants.

## Read surface review

- Profiles contain display identity, optional avatar/skill, preferred sports and
  public game/streak statistics; no email/token fields. Client own selects include
  onboarding completion; public host profile selects omit it. Blocked profiles
  are filtered by RLS. Created/updated/onboarding timestamps and arbitrary-user
  boolean helper inference were noted separately: helper disclosure is now fixed
  locally in [the helper-scope plan](2026-10-23-policy-helper-reads.md); timestamp
  minimization is deferred optional work, not a claim of strict column minimization.
- Session selects embed only venue columns and host id/display name/username.
  Session top-level wildcard retains legacy column compatibility; RLS is the
  authorization boundary. Session times/locations are public for discoverable
  games, and retained history is limited to host/participants.
- Roster RPC filters blocked identities, omits waitlist identities, retains true
  counts/position, and shares session RLS's private visibility helper.
- Reports/notices use caller-scoped RPCs; raw moderation tables revoke application
  grants. Queue/snapshot reads require moderator membership in the RPC.
- Blocked-user list intentionally returns identity of the caller's own blocked
  targets, allowing unblock despite ordinary profile RLS.

## Verification and disposition

- Two independent red probes reproduced another player's inaccessible historical
  membership and another player's waitlist identity via direct table reads.
  Logs: /tmp/pickup-participant-red.log, /tmp/pickup-waitlist-read-red.log.
- Migration 20261023221000 restricts only participants_select, with no grants,
  writes, function or RPC changes. The shared definer visibility helper avoids
  policy recursion; privileged RPC behavior stays intact.
- Full candidate SQL/RLS suite passed with 33 success notices inside rollback.
  Log: /tmp/pickup-participant-candidate-sql.log.
- Phase Q covers public joined rows, inaccessible history, self historical and
  waitlist lookups, reverse blocks, blocked-host games, retained participant
  rosters, host attendance, exact waitlist counts/position, stale school-email
  claims and anonymous reads. Existing role/write/roster tests also pass.
- Independent review found no actionable correctness, compatibility, privacy or
  test-validity issue. git diff --check passed.

This closes the reproduced direct-read bypass locally, not all of BETA-13.
Public helper boolean inference was subsequently reproduced and fixed locally
in [the helper-scope plan](2026-10-23-policy-helper-reads.md). Nonessential profile
timestamp minimization remains deferred optional work. Deployment and production role-matrix verification need
their separate authorization/evidence.
Production remains unchanged. Exact device/two-account and full production role
matrix acceptance remain separate gates.
