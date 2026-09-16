# Implementation Plan: TF-06 Account-Transition Cleanup Failure

## Objective

Diagnose the physical-device sign-out warning from TestFlight build 1.0 (2), preserve the failed/blocked runbook state, add a secure code-owned compatibility cleanup and notification quarantine without weakening token ownership, and leave the authoritative production migration explicitly pending authorization.

## Confirmed evidence and approach

- The 2026-09-16 10:09 AM America/New_York screenshot shows local sign-out completed with an unconfirmed server-cleanup warning; device model and iOS version were not recorded.
- The shipped cleanup path is unchanged between source `316b29b` and pre-remediation `main` at `0fba725`.
- Read-only migration and schema checks confirm production lacks migration `20260910120000` and both device-token RPCs.
- Treat step 11 as failed, step 16 as blocked, and TF-06 as open.
- Add an exact-token, owner-RLS-protected delete only for PostgREST’s explicit missing-function response. Do not add a registration/table-upsert fallback.
- Retry idempotent unregister once. If cleanup or registration remains unconfirmed, persist a quarantine and keep APNs locally disabled until authenticated atomic registration succeeds.
- Keep the aggregate user warning for genuine failures while retaining private, typed failure categories in memory for tests and future privacy-safe diagnostics.

## Verification

- Focused account-transition and device-token tests, followed by the complete iOS suite.
- Unsigned generic-device Release build and Release static analyzer.
- Privacy/log scan, complete diff review, and `git diff --check`.
- Documentation must state that production migration deployment and two-lane physical-device retesting remain authorized follow-up work, not completed work.

---

# Previous Implementation Plan: EXT-01 UGC Safety and Moderation

## Objective

Make PickUp UCF's user-generated content safe enough for external TestFlight: publish visible rules and support, filter objectionable text at both client and database boundaries, support message/user/session reports, make blocking effective across discovery/chat/notifications/future interactions, and provide a least-privilege moderator workflow with an audit trail and bounded report volume.

This plan starts from `main` at `8791117`. Build 1.0 (2) remains the processed internal build from source `316b29bd59f5efafcf43151f634ad55b46921b8f`; later source changes do not change that provenance.

## Current Release State

- Internal group **Internal Testers** exists; build 1.0 (2) is assigned with status **Testing**.
- One internal Apple Account is invited and “What to Test” is saved.
- TF-06 upload/setup is complete, but TF-06 remains open until the iOS 17 and current-iOS device matrix has evidence.
- Production is intentionally missing migrations `20260822000000`, `20260909000000`, and `20260910120000`.
- EXT-01 work may add local migrations and tests, but no migration/function deployment, Supabase upgrade, production data change, App Review submission, or external tester invitation is authorized.

## Technical Contract

### User content

- Apply one deterministic `UserContentPolicy` contract to display names, session notes, custom sport names, custom locations, report context, and chat messages.
- Normalize whitespace; enforce field-specific length limits; reject control characters, direct threats, targeted slurs, sexual solicitation, and common contact-spam patterns.
- Return a neutral user-facing validation message without echoing rejected content.
- The iOS validator provides immediate feedback; PostgreSQL remains authoritative after deployment.

### Reports

- A report targets exactly one session, message, or user.
- Required category: harassment, hate, threat, sexual content, spam, impersonation, unsafe behavior, or other.
- Optional context is trimmed and bounded; duplicate open reports by the same reporter/target are rejected.
- Authenticated users submit through a `SECURITY DEFINER` RPC. Limit each reporter to 5 reports/hour and 20/day.
- Reporters can read their own report status but cannot read moderator notes or other users' reports.

### Blocking

- Blocking is directional for user intent but enforced symmetrically for contact and visibility.
- A blocked pair cannot see each other's profiles/messages, discover or join each other's hosted sessions, or receive actor-generated notifications from one another.
- Existing session membership and stored chat rows remain for integrity/audit; affected content is hidden by RLS rather than deleted.
- Unblocking restores future visibility/contact but does not recreate deleted/moderated content or missed notifications.

### Moderation

- Moderator membership is stored separately and cannot be self-granted by authenticated clients.
- Moderator list/read/action RPCs verify role on every call; underlying tables have no broad authenticated access.
- Actions support dismissing a report, removing content, warning a user, suspending a user, and resolving a report.
- Every action records moderator, target, bounded reason, timestamp, and resulting status. Suspension state is enforced by content-write and join/report RPCs.

### Support and response ownership

- Community rules and support contact are visible from Settings and from report flows.
- Safety target: urgent threats or imminent harm acknowledged within 24 hours; other reports within 72 hours. Emergencies direct users to 911/UCF Police rather than implying in-app emergency response.
- Store metadata monitoring and App Store age-rating answers remain Apple Account-owned release actions.

## Project Structure

- `ios/PickUpUCF/Core/Validators/` — reusable client content policy.
- `ios/PickUpUCF/Features/Moderation/` — community rules, report flow, moderator queue/action UI.
- `ios/PickUpUCF/Repositories/` and `Models/` — typed moderation contracts.
- `supabase/migrations/` — additive authoritative schema, RLS, RPC, blocking, notification, and rate-limit enforcement.
- `supabase/tests/` — SQL abuse/access-control integration coverage.
- `privacy-site/` — public community-rules document prepared for later authorized publication.
- `docs/operations/` — response targets, escalation, moderation provisioning, and deployment limitations.

## Commands

```sh
cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze

cd ..
supabase start
supabase db reset
# Run supabase/tests/run_all.sql against disposable local Postgres with ON_ERROR_STOP=1.
git diff --check
```

## Testing Strategy

- TDD unit tests for normalization, field limits, prohibited categories, and safe validation messages.
- SQL integration tests for report target integrity, false/duplicate/rate-limited reports, role escalation attempts, moderator actions, suspension, block/unblock, deleted users, message visibility, join denial, and notification suppression.
- Focused view-model/repository tests for typed report inputs and moderation state where logic can be isolated from Supabase.
- Full iOS suite, clean local database reset/full SQL suite, unsigned Release build, Release analyzer, and final diff review.
- Runtime physical-device verification remains separate; simulator/static evidence cannot close TF-06 or production EXT-01.

## Boundaries

- Always: validate at client and database boundaries; parameterize SQL/RPC inputs; use RLS plus per-RPC authorization; keep moderator/audit data private; preserve existing user work.
- Ask first: production migration/function deployment, moderator provisioning in production, support mailbox ownership changes, App Store metadata/age-rating edits, dependency changes.
- Never: expose report context/moderator notes to reported users; let clients self-assign moderator status; log UGC/report bodies; alter production data; invite external testers or submit for review.

## Implementation Tasks

### Phase 1 — Readiness reconciliation and policy foundation

1. Reconcile TF-06/EXT evidence and extract the remaining physical-device actions.
   - Acceptance: internal group/build/tester/instructions are recorded; TF-06 stays open; deferred migrations stay explicit.
   - Verify: documentation diff and checklist consistency review.
2. Add community rules, support visibility, response targets, and escalation documentation.
   - Acceptance: rules name prohibited behavior, explain reports/blocks/history, expose support, and distinguish emergencies.
   - Verify: local HTML inspection and iOS build.
3. Add content-policy tests, then implement the smallest shared iOS validator.
   - Acceptance: supported fields normalize safely and abusive/spam/control-character cases are rejected with neutral messages.
   - Verify: focused XCTest red → green.

### Checkpoint 1

- Focused policy tests pass; rules/support links compile; no production state changes.

### Phase 2 — Authoritative moderation backend

4. Add an additive local migration for reports, moderator membership/actions, suspensions, content validation, rate limits, and least-privilege RPCs.
   - Acceptance: clients cannot read moderation internals or self-elevate; every moderator action is authorized and audited.
   - Verify: clean local reset plus new SQL abuse/access-control tests.
5. Extend blocking across RLS, join/chat writes, profile/session visibility, and actor-generated notifications.
   - Acceptance: blocked pairs cannot contact or notify each other; history is retained but hidden; unblock restores future access.
   - Verify: SQL block/unblock, shared-history, alternate-flow, deleted-user, and notification assertions.

### Checkpoint 2

- Full local SQL/RLS suite passes from a clean reset; production remains unchanged.

### Phase 3 — User reporting and moderator UI

6. Replace the session-only report contract with typed message/user/session reporting and reason/context UI.
   - Acceptance: each target is reportable from its relevant surface; duplicates/rate limits/errors are understandable.
   - Verify: focused unit tests plus full iOS suite.
7. Add report/block actions to chat/user surfaces and filter blocked content in realtime state.
   - Acceptance: message and sender actions are accessible; realtime inserts from blocked users are not rendered.
   - Verify: focused ChatViewModel tests and simulator UI review.
8. Add moderator queue/detail/action UI gated by server role checks.
   - Acceptance: non-moderators cannot discover or invoke it; moderators can review and record permitted actions.
   - Verify: access-control SQL tests and focused view-model tests.

### Checkpoint 3

- Full iOS suite, unsigned Release build, and analyzer pass; accessibility labels and error/empty/loading states are reviewed.

### Phase 4 — Final documentation and review

9. Update EXT-01 checklist evidence with code-owned results and keep deployment/device/Apple Account tasks open.
10. Review tests first, then the complete diff for correctness, simplicity, architecture, security/privacy, and performance.
11. Commit in clean boundaries and push `main` only after every gate passes.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Static word filtering over-blocks legitimate sports conversation | Medium | Keep the list narrow, test word boundaries/normalization, provide neutral correction, and rely on reporting/moderation for context. |
| RLS changes hide required session data or break counts | High | Preserve membership rows, test both block directions, hosts/participants, unblock, and unrelated users on a clean database. |
| `SECURITY DEFINER` enables privilege escalation | Critical | Set `search_path`, revoke public execution, grant only named RPCs, derive actor from `auth.uid()`, and test direct-table/RPC denial. |
| Rate limits punish legitimate reporters | Medium | Use per-user rolling hour/day bounds, idempotent duplicate handling, and moderator/service-role bypass only where explicitly required. |
| Local implementation is mistaken for production protection | High | Mark every new migration and behavior pending deployment; do not close EXT-01 until production deployment and end-to-end evidence exist. |

## Success Criteria

- Local users can see rules/support, report a message/user/session, and block/unblock users.
- Database tests prove content, reporting, blocking, rate-limit, suspension, moderator, and audit invariants.
- No authenticated client can read other reports, moderation notes, role membership, or audit actions.
- Full iOS and SQL suites, Release build/analyzer, and final diff review pass.
- Readiness docs clearly separate code complete from production/device/Apple Account complete.

## Open External Actions

- Accept the internal TestFlight invitation and run the full physical-device matrix on iOS 17 and current iOS.
- Authorize/deploy production migrations and current functions only after backup/rollback readiness.
- Provision real moderator accounts and monitored support ownership in production.
- Complete the App Store age-rating/content questionnaire and external-beta metadata in App Store Connect.
