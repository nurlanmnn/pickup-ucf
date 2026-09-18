# TF-06 Account-Transition Incident Checklist

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
