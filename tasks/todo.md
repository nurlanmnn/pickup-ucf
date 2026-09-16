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
- [ ] Obtain authorization before deploying migration `20260910120000`; no production deployment is part of this work.
- [ ] Retest runbook steps 11 and 16 on recorded iOS 17 and current-iOS physical devices.

---

# Previous EXT-01 Task Checklist

## Readiness reconciliation

- [x] Record Internal Testers group, build 1.0 (2) assignment/Testing status, one tester invitation, and saved “What to Test”.
- [x] Keep TF-06 open for both physical-device lanes.
- [x] Preserve the three intentionally deferred production migrations.
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

## Explicitly deferred / user-owned

- [ ] Deploy any EXT-01 migration/function revision to production.
- [ ] Deploy the three previously deferred production migrations.
- [ ] Provision production moderator accounts and confirm monitored support ownership.
- [ ] Complete App Store age-rating/content answers.
- [ ] Invite external testers or submit to Beta App Review.
