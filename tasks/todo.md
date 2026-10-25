October25 evening physical follow-up: owner-approved8PM temporary game was
published and app-reported Calendar export succeeded. Mirroring then disconnected;
Calendar details/physical cancellation/Live Activity remain unverified. The exact
approved fixture was administratively cancelled through backend (1 row), with
separate cancelled/0-active-token verification. No game remains published from
this test. Calendar copy may remain; inspect/remove that copy when reachable.
Owner readiness retry and Mirroring restart both failed; do not repeatedly poll.
See [build5 evidence](../docs/testflight/2026-10-22-build-5.md). Keep local work going,
stop at15 percent remaining usage; no deployment/upload/new fixture authorization.

October25 evening: LiveActivityTokenRepository now uses existing closed local
DeviceTokenDiagnostics for register_live_activity_rpc. Original RPC/payload/
whitespace/errors remain; no fallback/retry/auth/ActivityKit change. Focused32/32
and final full signed isolated340/340 pass, AX1/1 verified around restart and
suite; unsigned Release build/analyzer pass. Actual focused/full Logger8 records
each (2 activity-stage) checked for exact schema/privacy. Independent final review
found no required issue. See [scope/evidence](../docs/superpowers/plans/2026-10-25-live-activity-token-diagnostics.md).
This is backend-stage local evidence, not APNs delivery or physical lifecycle
acceptance. Owner resumed work with15 percent remaining-usage stop threshold.

October25: BETA-11 now has a bounded authenticated Debug-simulator UI fixture:
one exact flag selects synthetic SDK session/in-memory storage/HTTP response
allowlist and all existing isolation guards before views initialize. Real
Discover/My Games upcoming+history/Profile repositories and screens render
synthetic data; My Games ActivityKit refresh is suppressed in UI mode. Auth,
writes and unknown HTTP fail closed; no websocket isolation claim. Gate7/7 with
built backend URL/key empty; new screenshots inspected. Final signed isolated
units336/336 (AppConfig11/11, existing Keychain/four renderedAX), unsigned Release
build/analyzer and final fresh-context review pass. Unsupported host builds ignore
flag; Release fixture literals absent. See [scope/evidence](../docs/superpowers/plans/2026-10-25-authenticated-ui-smoke.md).
Broader workflows/permissions/CI/device/provider acceptance remain open; BETA-11
partial. No production/phone/deployment/upload/account action.

October25: BETA-10 local realtime subscription diagnostics now distinguish returned,
failed, caller-cancelled and superseded attempts plus finite channel-status
observations. Closed ten-field JSON excludes identifiers/content/URLs/raw errors;
SDK cancellation is kept separate from caller cancellation. Loopback-only real-SDK
websocket harness: initial8 tests failed14 absent-record assertions; focused34/34
and final signed isolated333/333 (11 new runtime tests), Release build/analyzer,
actual Logger schema/privacy checks and final fresh-context review pass. See
[scope/evidence](../docs/superpowers/plans/2026-10-25-realtime-diagnostics.md).
Subscription/status does not prove delivery or caught-up history. BETA-10/11 partial.

October25: BETA-10 device-token backend diagnostics now distinguish register RPC,
unregister RPC and the PGRST202-only owner-filtered fallback delete. Closed ten-field
local JSON excludes tokens/identities/raw errors; original payloads, filters,
errors and service retry/quarantine/account-transition behavior remain. Red proof
29 missing-record assertions; focused33/33 and final full signed isolated322/322,
unsigned Release build/analyzer and fresh-context review pass. Actual default
Logger JSON schema/privacy checked. See [scope/evidence](../docs/superpowers/plans/2026-10-25-device-token-diagnostics.md).
No APNs delivery or whole-account-cleanup claim; BETA-10/11 remain partial.

October25: BETA-10 local auth restoration now emits one closed auth_operation
record per currentSession invocation, distinguishing SDK session_missing,
unavailable, verified, rejected cached/remote, invalidated, superseded and cached
fallback. Original SDK requests, guards, cleanup and error suppression remain;
SDK-cleared cache/absence causes are not inferred. Focused28/28 before final
additions, final full signed isolated311/311 (11 restore tests), unsigned Release
build/analyzer and independent final review pass. Actual Logger schema/privacy
checked. See [contract/evidence](../docs/superpowers/plans/2026-10-25-restoration-diagnostics.md).
No deployment/upload/phone/account action. BETA-10/11 remain partial.

October25: BETA-10 local chat diagnostics now distinguish first/older page reads,
send (session lookup+insert), and targeted message/author reconciliation reads.
Closed ten-field local chat_operation JSON excludes content/identities/cursors/
URLs/errors; exact queries, normalization, returned values and original errors
remain. Invalid bodies/empty updates emit no record or request. Focused15/15 and
full signed isolated300/300 pass after restoring/restarting simulator AX1/true;
unsigned Release simulator build/analyzer pass. Independent design/final reviews
found no required issues. See [scope/evidence](../docs/superpowers/plans/2026-10-25-chat-diagnostics.md).
BETA-10 remains partial; realtime subscription health/other flows/reporting/alerts
remain open. October24 temporary-game time is past; no game was published, and a
new time needs owner approval. No phone reconnect/deployment/upload occurred.

October 24 follow-up: isolated UI smoke now passes6/6, adding blank sign-up
and reset-request blank/non-school-email validation plus return to original sign-in.
Built backend URL/key empty; three new screenshots inspected. Initial intro-route
query error was corrected in the test; no product code changed. See
[UI scope and evidence](../docs/superpowers/plans/2026-10-24-ui-smoke.md).
Authenticated/permission/CI/device acceptance remains open. Before future unit
runs check the documented simulator AX prerequisites after the UI lane.

October 24: BETA-10 explicit-auth diagnostics now cover sign-up/sign-in/sign-out,
verification resend/OTP, recovery request/password update, staged change-password
and accepted callback exchange. Closed local JSON excludes inputs/identities/raw
errors; original requests/errors/cleanup remain. Focused16/16 and full signed
isolated289/289 tests pass; unsigned Release simulator build/analyzer pass;
fresh-context design/final reviews found no required issues. See
[contract and evidence](../docs/superpowers/plans/2026-10-24-auth-diagnostics.md).
Session restoration diagnostics, other critical flows, centralized reporting and
alert ownership remain open. No deployment/upload/device/account mutation.

October 24: BETA-11 first isolated XCUITest slice passes 4/4 with backend URL/key
absent: Welcome intro/relaunch, account route replacement/email carry, blank
sign-in validation and actual accessibility5 navigation. One Debug simulator-only
flag automatically selects a synthetic HTTP-denying client, discards auth storage
and skips restore/lifecycle/push side effects. Runner rejects unsupported builds
before launch and asserts an isolation marker before actions. Screenshots inspected;
independent review has no required findings. Signed isolated unit suite passes
273/273 after restoring the simulator Accessibility prerequisite (post-UI run was
0/false and reproduced four existing AX lookup failures). Unsigned Release
simulator build/analyzer pass. See [scope, gate command and lane setup](../docs/superpowers/plans/2026-10-24-ui-smoke.md).
Authenticated UI/permissions, CI and physical acceptance remain open; BETA-11 is partial.

October 24: BETA-10 first local diagnostics slice now covers session create RPC,
post-create read, edit/cancel/join/leave. Closed JSON fields, coarse error classes,
monotonic duration and fresh attempt IDs (shared receipt/read, distinct retries)
exclude raw errors and user data. Signed isolated suite passes 270/270 on the
established iPhone16e lane; initial iPhone17 accessibility lookup failures and
lane prerequisites are documented. Unsigned Release simulator build and analyzer both pass.
See [diagnostics scope/evidence](../docs/superpowers/plans/2026-10-24-session-diagnostics.md).
Other BETA-10 flows, centralized reporting/health/alert ownership remain open.

Owner approved publishing/cancelling the prepared temporary game directly in the
source chat. Mirroring reconnect failed before submission; no game was published.
An async phone-readiness request is pending in diagnostics continuation chat
`01a170f3-0159-7ad2-bc51-28fc4e37c08c`. Recheck latest human turns and actual date/time
before any later submit; the Oct24 11:30PM form can become stale.

October 24, 10:39–10:43 PM: owner made phone available; Mirroring reconnected to
installed build 1.0 (5). Empty/over-limit Other-name validation, exact40-character
progression, nonfuture schedule error and min capacity2 were observed on device.
Physical Unicode input remains unverified due to Mirroring entry limitations.
A labeled test-game form is prepared but unpublished, pending owner's explicit
answer before creating a production-visible game. See updated build5 evidence.
Next independent P1 work while waiting: expand BETA-10 privacy-safe critical-auth
diagnostics or the remaining isolated BETA-11 paths; keep optional P2 work deferred.

October 24: push outbox transport failure no longer aborts later recipients;
failed database acknowledgements no longer inflate the sent count. Both defects
have red/green synthetic regressions; relevant typechecked Edge tests pass 31/31.
See [push outbox recovery](../docs/superpowers/plans/2026-10-24-push-outbox-recovery.md).
This Edge change and ten SQL migrations remain undeployed. Live Activity lifecycle
fix is committed/pushed as `09e9473`; no production/device acceptance is implied.

# Current work — Production deployed; iOS candidate acceptance next

October 23 read-only production check: Data API exposes public/graphql_public,
excludes pickup_private, and adds only public/extensions to search_path. GraphQL
is disabled. See [API exposure evidence](../docs/operations/2026-10-23-api-schema-exposure.md).
No settings changed; recheck at future authorized helper deployment. Live Activity registration/lifecycle ordering is now fixed locally in
`20261023232500`: account/session locks precede a fresh eligibility read. Both
lifecycle orders, parallel devices, retries/ownership, terminal states, deletion
and isolation guards pass in the disposable harness; all 38 candidate SQL/RLS
notices pass inside rollback. See [Live Activity concurrency evidence](../docs/superpowers/plans/2026-10-23-live-activity-concurrency.md).
There are **ten undeployed October 23 migrations**. This is not production/device acceptance.

October 23 report concurrency: reproduced six simultaneous distinct-target
reports committing past the 5/hour cap. Migration `20261023231500` serializes
submissions per reporter while preserving current-account authorization and
retained audits. Focused hourly/daily, duplicate/recovery, independent/reciprocal
reporter, deletion-order and snapshot cases pass; full candidate SQL/RLS passes
38 notices inside rollback in a fresh network-disabled disposable DB. Independent
review found no required changes. See [report concurrency](../docs/superpowers/plans/2026-10-23-report-concurrency.md).
There are now **nine undeployed October 23 migrations**. Existing local DB and
production were not edited. Prior iOS/Edge evidence remains unchanged.

October 23 further audit: fixed deleted-account report submissions, blocked-host
chat visibility/sends, forged message timestamps/IDs and attendance-ledger identity
leaks locally. Own profile history and released host attendance remain compatible.
Full candidate SQL/RLS now passes **38 phase notices** inside rollback. All 18
application/private tables have RLS; source/API threat model, intentional
exceptions and evidence are in the
[table-policy audit](../docs/superpowers/plans/2026-10-23-table-policy-audit.md).
There are now **nine undeployed October 23 migrations**. The owner authorized
GitHub feature-branch pushes; deployment, merge, new upload and external review
remain separate gates. No new Swift/Edge code warranted repeating prior evidence.

October 23 continuation: BETA-13 edit/read audit reproduced and fixed three
additional defect groups locally. Session edits now persist the normalized Other
sport name and clear optional notes/location/name fields; direct participant reads
respect game visibility and hide other waitlist identities; public policy helpers
reject unrelated-user block/suspension probes while preserving trusted internals.
See [edit payload](../docs/superpowers/plans/2026-10-23-session-edit-payload.md),
[participant reads](../docs/superpowers/plans/2026-10-23-participant-read-minimization.md),
and [helper scope](../docs/superpowers/plans/2026-10-23-policy-helper-reads.md).
Signed isolated simulator tests passed 267/267; unsigned Release build/analyzer
passed. Candidate SQL/RLS passed 34 phase notices inside rollback; isolated host
concurrency passed after the helper change. All nine October 23 migrations now remain
undeployed, and the iOS fix is absent from TestFlight build 5. Before deployment,
verify pickup_private remains unexposed in production API configuration. Optional
profile timestamp minimization is deferred. Device/provider/two-account and full
production acceptance remain open. See the updated
[continuation handoff](../docs/operations/2026-10-23-launch-handoff.md).

October 23 follow-up: BETA-13 host-edit numeric/schedule/location-pin bypasses
reproduced and fixed locally in `20261023215028`; all 31 candidate SQL/RLS phase
notices passed inside rollback. Production migration and build 5 remain unchanged.
See [host edit contract and evidence](../docs/superpowers/plans/2026-10-23-host-edit-boundaries.md).

Also fixed BETA-14 waitlist retries resetting queue priority locally in
`20261023215505`. Red reproduction and all 32 candidate SQL/RLS phase notices
passed with rollback; explicit leave/rejoin still creates a new queue entry.
See [waitlist retry evidence](../docs/superpowers/plans/2026-10-23-waitlist-retry.md).
These two migrations, plus the subsequent participant/helper read fixes, remain undeployed.

BETA-14 independent isolated concurrency now passes four ordered host-action
races, twelve cancellation/join races and six simultaneous waitlist retries.
Only schema/history were copied from the local DB; fixtures stayed in a fresh
network-disabled disposable container, removed afterward. See
[host-action concurrency](../docs/superpowers/plans/2026-10-23-host-action-concurrency.md).

October 23: connected iPhone 17 / iOS 27.0.1 reports installed version 1.0 (5).
The owner confirmed installation through TestFlight and availability for testing.
iPhone Mirroring connected for the smoke checks, then disconnected while the owner used the phone away from the computer. Physical-device launch, online cold relaunch into
the same reviewer profile, Profile/Settings navigation, Privacy Policy and Terms
links passed smoke checks. No upcoming reviewer games were visible; two-account,
provider, Calendar, APNs, offline and accessibility checks remain open. See the
[build-5 device evidence](../docs/testflight/2026-10-22-build-5.md).
Completed an isolated actual-snapshot logical
restore: 38 imported table-count checks and 44 foreign-key checks passed;
then replayed all ten deployed migrations unchanged in a second isolated restore.
Synthetic lifecycle/rollback passed; read-only production catalog comparison matched
46 functions and 148 table/policy/constraint/index/trigger entries. Both disposable
containers were removed. Platform/auth/configuration recovery gaps remain. See
[scope, evidence and recovery gaps](../docs/operations/2026-10-23-isolated-restore.md).

The owner authorized pushing current source and deploying required changes on
October 22. Source `b8349d2` is verified on origin/main. See the
[production rollout record](../docs/operations/2026-10-22-production-rollout.md).

- Deployed all ten pending migrations, including the null-host cleanup preflight fix.
- Deployed send-auth-email v23 and send-push v18; downloaded source matches local.
- Published Vercel privacy/AASA/fallback routes and set exact hosted HTTPS redirects.
- Verified origin/Apple CDN AASA, public routes, grants/schema, migration parity,
  rejection of unsigned function requests, and successful cleanup/dispatch cron runs.
- Preserved isolated 261-test iOS and 39-test Edge Function evidence. The new SQL
  regression first failed, then the complete local candidate SQL/RLS suite passed.

Remaining: prepare controlled upcoming-game/two-account prerequisites and complete iOS 17/current-iOS
two-account/device and provider acceptance, complete platform recovery readiness,
and external Beta App Review. Build-5 packaging/internal distribution was completed
October 22 as recorded below; no additional upload or invitation occurred.

## Build 5 prepared — October 22

Local signed Release archive and App Store IPA export passed for version 1.0 (5),
source `53ac5c7`. Exported app/widget signatures and App Store profiles verify;
production APNs and Associated Domains are present. See
[build 5 provenance and acceptance](../docs/testflight/2026-10-22-build-5.md).
Owner subsequently approved upload for internal testing. Upload succeeded at
2:48 PM America/New_York; Apple processing is Complete, export compliance saved,
and build 5 is Testing in the existing one-tester Internal Testers group. What to
Test is saved. Internal installation was owner-confirmed October 23; remaining exact-candidate
physical/provider checks stay open. No external invitation or Beta App Review submission occurred.

# Previous work — October 22, 2026

Continue with [input boundaries and launch gates](../docs/superpowers/plans/2026-10-22-input-boundaries-and-launch-gates.md). BETA-08 changes are preserved on `codex/realtime-chat-recovery`. BETA-03, explicit RPC/mutation grants, serialized leave, contextual notification consent and account-local cleanup now have local implementation. Production exposed RPC grants and missing October notification migrations were confirmed read-only. The owner chose anonymized retained games; deletion, null-host UI, chat reconciliation and relaunch cleanup now have local coverage. Production/device/App Store gates remain open. This source snapshot was committed and pushed to main as `c18ef78` on October 22; production deployment remains open. Earlier test-host bootstrap refreshed one existing production profile/token registration; the incident and the now-enforced synthetic test isolation are recorded in the focused plan.

# Previous work — October 21, 2026

BETA-08 source and regression work is recorded in [Realtime chat recovery](../docs/superpowers/plans/2026-10-21-realtime-chat-recovery.md). Live two-account reconnect/foreground checks and physical-device accessibility remain open.

Use the [master readiness checklist](../docs/superpowers/plans/2026-09-02-testflight-readiness.md) for remaining work. UI/auth UX, chat pagination, and atomic creation have local evidence; the atomic-creation production migration was approved and applied on October 21. The owner has requested pushing the current state to main. Earlier incident checklists below preserve historical evidence; TF-06 was subsequently completed by owner confirmation on October 4. Physical-device/offline and remaining deployment gates stay separate.

# Historical TF-06 Account-Transition Incident Checklist

- [x] Preserve the screenshot as untrusted evidence and record unknown device/OS fields as “not recorded”.
- [x] Mark runbook step 11 failed, step 16 blocked, and TF-06 open.
- [x] Compare pre-remediation `main` with build source `316b29bd59f5efafcf43151f634ad55b46921b8f`.
- [x] Verify production migration status and the actual absence of both device-token RPCs using read-only checks.
- [x] Add failing tests for distinct cleanup failures, local session clearing, token isolation, compatibility cleanup, and recovery.
- [x] Implement owner-scoped missing-RPC cleanup, bounded retry, and persistent APNs quarantine.
- [x] Run the complete iOS suite (171/171), unsigned Release build, Release analyzer, privacy/static checks, and `git diff --check`.
- [x] Review the complete diff across correctness, readability, architecture, security/privacy, and performance.
- [x] Commit in clean boundaries and push `main` (completed by this delivery).
- [x] Obtain authorization and deploy migration `20260910120000` with the other three pending migrations in order; verify production migration parity and token RPC definitions (2026-09-16).
- [ ] Retest runbook steps 11 and 16 on recorded iOS 17 and current-iOS physical devices.

## TF-06 Chat Notification Delivery Follow-up

- [x] Record the 2026-09-16 observation with unknown device/build fields as “not recorded”; mark step 13 failed and step 16 blocked.
- [x] Prove chat outbox creation, recipient eligibility, preferences, device-token presence, and the absence of blocking/suspension using privacy-safe production checks.
- [x] Restore the missing once-per-minute `send-push` schedule with a dedicated Vault-backed credential.
- [x] Synchronize the scheduler/function credential and remove the temporary least-privilege bootstrap and rotation RPCs.
- [x] Set `APNS_ENV=production` for TestFlight delivery.
- [x] Add privacy-safe APNs diagnostics and confirm HTTP 429 `TooManyProviderTokenUpdates` without logging private data.
- [x] Cache and share the APNs provider JWT for 50 minutes; keep rejected outbox rows pending for retry.
- [x] Confirm the stable JWT processes eligible backlog rows and isolates the remaining APNs response as HTTP 400 `BadDeviceToken`.
- [x] Remove only exact tokens rejected as `BadDeviceToken`, leave the current attempt failed, and permit fresh app registration recovery.
- [x] Pass the complete Edge Function suite (19/19) and formatting checks.
- [x] Confirm the recovered production backlog reaches zero pending rows after stable-JWT processing and exact invalid-token cleanup (2026-09-18 approximately 8:55 AM America/New_York).
- [ ] Run and record the exact physical-device notification and account-isolation retest; keep TF-06 open until it passes in both lanes.

---

# Previous EXT-01 Task Checklist

## Readiness reconciliation

- [x] Record Internal Testers group, build 1.0 (2) assignment/Testing status, one tester invitation, and saved “What to Test”.
- [x] Keep TF-06 open for both physical-device lanes.
- [x] Preserve the deferred production migrations until explicit authorization; all four pending migrations were authorized and deployed on 2026-09-16 without a backup.
- [ ] Record iOS 17 physical-device evidence (user-owned).
- [ ] Record current-iOS physical-device evidence (user-owned).

## Plan and policy

- [x] Write the focused EXT-01 technical contract and implementation plan before code.
- [x] Add community rules and prohibited-content standards.
- [x] Add support visibility, response targets, and escalation documentation.
- [x] Add content-policy tests before implementation.
- [x] Implement client content validation for all UGC fields.

## Backend safety (local only)

- [x] Add typed message/user/session reports with duplicate protection.
- [x] Add per-user report rate limits.
- [x] Add moderator membership, queue, actions, suspensions, and audit records.
- [x] Protect moderation data and functions with least-privilege RLS/RPC grants.
- [x] Enforce blocking across profile/session/message visibility, joins, chat, and notifications.
- [x] Define and test retained-but-hidden shared history.
- [x] Add abusive-content, false-report, duplicate, block/unblock, deleted-account, suspension, and notification SQL tests.
- [x] Run a clean local reset and full SQL/RLS suite (2026-09-16).

## iOS reporting and moderation

- [x] Add report reason/target models and repository contract.
- [x] Add message, user, and session report entry points.
- [x] Add accessible community rules and support surfaces.
- [x] Filter blocked realtime messages.
- [x] Add server-gated moderator queue and action UI.
- [x] Add focused policy and blocked-message unit tests.

## Verification and delivery

- [x] Run the full iOS suite (167 tests, 2026-09-16).
- [x] Run the unsigned Release build and analyzer (2026-09-16).
- [x] Run `git diff --check` and secret/PII review.
- [x] Review the complete diff across correctness, readability, architecture, security, and performance.
- [x] Update readiness evidence without falsely closing production/device gates.
- [x] Commit in clean boundaries and push to `main` (completed by this delivery).

## Production follow-up / user-owned

- [x] Deploy the EXT-01 migration/function revision to production (2026-09-16).
- [x] Deploy the three previously deferred production migrations (2026-09-16).
- [ ] Provision production moderator accounts and confirm monitored support ownership.
- [ ] Complete App Store age-rating/content answers.
- [ ] Invite external testers or submit to Beta App Review.
