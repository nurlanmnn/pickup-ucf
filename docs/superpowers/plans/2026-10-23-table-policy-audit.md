# Application table-policy audit — October 23, 2026

## Scope and trust boundary

Reviewed the local candidate's 18 public/private application tables and both
anon/authenticated role grants, using catalog metadata only. Every table has RLS
enabled. No auth records, private rows or recovery contents were read for this
inventory. The audit covers crafted Data API calls and current/build-5 clients;
managed Auth/platform recovery and direct database administrator access are
separate boundaries. Broad stock grants are not permission to bypass RLS.

| Surface | Intended client access and reviewed enforcement |
| --- | --- |
| profiles | Confirmed school users read unblocked identity/statistics; owner insert/update only, with content/suspension checks and column restrictions protecting statistics. |
| venues | Confirmed school-user SELECT; no client write policy. |
| sessions | Shared private visibility gate; host editable columns only, lifecycle/numeric/schedule/pin guard; counts/membership/creation controlled transactionally. |
| session_participants | Own status/history lookup; others only joined rows in visible games with block filtering; no direct client writes. Waitlist identity comes only from caller-scoped aggregate RPC. |
| messages | Membership plus positive session visibility; blocked author filtering; suspended senders denied. INSERT only session_id/user_id/body; server supplies ID/time. No UPDATE/DELETE policies. |
| attendance | Own ledger SELECT for profile history, requiring current school identity. Host form reads participants and submits through host-authorized RPC; no direct ledger writes. |
| notification_preferences | Caller-owned rows; no access to another user's preferences. Owner preference/safety operations remain separate from UGC suspension. |
| user_blocks | Caller-owned outgoing block rows; unblock/list RPC intentionally permits managing own blocked targets despite ordinary profile filtering. |
| session_reports | Legacy own-reporter read/insert, per-game uniqueness and reason constraint; profile FK prevents deleted-actor writes. Current build uses typed moderation RPC instead. Legacy-table deprecation is separate work. |
| moderation_reports / moderation_actions / moderator_accounts | No direct application-role grants; report submission now verifies current confirmed school account; queue/actions require moderator membership. Retained reporter IDs intentionally have no auth FK. |
| user_moderation_state / user_moderation_notices | No direct application-role grants; own notice RPC, trusted moderation mutations. Public suspension helper only reveals caller's state. |
| device_tokens / live_activity_tokens | No direct application-role grants; owner-scoped RPCs and trusted dispatch. |
| notification_outbox | RLS with no application policies: default deny despite stock table grants. Enqueue/maintenance functions are closed to ordinary callers. |
| pickup_private.session_creation_requests | No direct application-role table grants or policies; authenticated atomic creation owns receipt access. |

## Findings and verification

The continuation reproduced and fixed deleted-account moderation submissions,
blocked-host chat reads/sends, forged/nonfinite message timestamps, and raw
attendance reads of blocked identities. Earlier in the same source audit,
participant history/waitlist disclosure and unrelated-user helper RPC disclosure
were reproduced and fixed. Focused October 23 plans contain the red/green logs.

The latest complete candidate SQL/RLS suite passes **38 phase success notices**
inside rollback, including all prior lifecycle/grant/role cases and new phases
Q–V. Log: /tmp/pickup-attendance-candidate-sql.log. Each new fix received independent
review. Attendance review caught and corrected an own-history compatibility issue
before commit/push. No iOS or Edge source changed in this follow-up; prior signed
267/267 iOS, Release/analyzer and Edge evidence were preserved, not rerun.

## Intentional exceptions and remaining gates

- Existing profile timestamps and legacy table cleanup are deferred optional
  minimization work; this is not a claim of strict per-column minimization.
- Shared roster counts/position reflect the true queue even when blocked names
  are hidden. Own attendance and membership history remain available.
- Definer services can inspect arbitrary actors; public helpers cannot. Raw
  helpers in pickup_private require that schema to remain unexposed to REST and
  GraphQL. Production API configuration must be verified before deployment.
- Existing subscribed/client-buffered state needs two-account/device acceptance;
  a new SELECT/INSERT policy is not evidence of immediate UI cache removal.
- All eight October 23 migrations are **undeployed**. Exact production role/API
  verification and compatible-candidate device/provider acceptance remain open.
- The audit does not grant client SQL connections or arbitrary-SQL RPCs. Do not
  expose private schemas or treat role grants alone as the authorization model.
