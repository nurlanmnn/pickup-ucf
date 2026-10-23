# Current work — Production deployed; iOS candidate acceptance next

October 23: connected iPhone 17 / iOS 27.0.1 reports installed version 1.0 (5).
CoreDevice marks it as a developer app; TestFlight provenance and hands-on
acceptance remain unconfirmed. Completed an isolated actual-snapshot logical
restore: 38 imported table-count checks and 44 foreign-key checks passed;
disposable container removed. See [scope, evidence and recovery gaps](../docs/operations/2026-10-23-isolated-restore.md).

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

Remaining: confirm TestFlight candidate provenance and complete iOS 17/current-iOS
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
Test is saved. Internal installation and exact-candidate physical/provider checks
remain open. No external invitation or Beta App Review submission occurred.

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
