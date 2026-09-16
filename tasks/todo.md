# EXT-01 Task Checklist

## Readiness reconciliation

- [x] Record Internal Testers group, build 1.0 (2) assignment/Testing status, one tester invitation, and saved “What to Test”.
- [x] Keep TF-06 open for both physical-device lanes.
- [x] Preserve the three intentionally deferred production migrations.
- [ ] Record iOS 17 physical-device evidence (user-owned).
- [ ] Record current-iOS physical-device evidence (user-owned).

## Plan and policy

- [x] Write the focused EXT-01 technical contract and implementation plan before code.
- [ ] Add community rules and prohibited-content standards.
- [ ] Add support visibility, response targets, and escalation documentation.
- [ ] Add content-policy tests before implementation.
- [ ] Implement client content validation for all UGC fields.

## Backend safety (local only)

- [ ] Add typed message/user/session reports with duplicate protection.
- [ ] Add per-user report rate limits.
- [ ] Add moderator membership, queue, actions, suspensions, and audit records.
- [ ] Protect moderation data and functions with least-privilege RLS/RPC grants.
- [ ] Enforce blocking across profile/session/message visibility, joins, chat, and notifications.
- [ ] Define and test retained-but-hidden shared history.
- [ ] Add abusive-content, false-report, duplicate, block/unblock, deleted-account, suspension, and notification SQL tests.
- [ ] Run a clean local reset and full SQL/RLS suite.

## iOS reporting and moderation

- [ ] Add report reason/target models and repository contract.
- [ ] Add message, user, and session report entry points.
- [ ] Add accessible community rules and support surfaces.
- [ ] Filter blocked realtime messages.
- [ ] Add server-gated moderator queue and action UI.
- [ ] Add focused unit/view-model tests.

## Verification and delivery

- [ ] Run the full iOS suite.
- [ ] Run the unsigned Release build and Release analyzer.
- [ ] Run `git diff --check` and secret/PII review.
- [ ] Review the complete diff across correctness, readability, architecture, security, and performance.
- [ ] Update readiness evidence without falsely closing production/device gates.
- [ ] Commit in clean boundaries and push to `main`.

## Explicitly deferred / user-owned

- [ ] Deploy any EXT-01 migration/function revision to production.
- [ ] Deploy the three previously deferred production migrations.
- [ ] Provision production moderator accounts and confirm monitored support ownership.
- [ ] Complete App Store age-rating/content answers.
- [ ] Invite external testers or submit to Beta App Review.
