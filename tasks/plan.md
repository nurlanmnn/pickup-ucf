# Implementation Plan: TF-06 Internal TestFlight Release Gate

## Overview

Complete TF-06 only. Establish a reproducible internal-TestFlight candidate baseline, run every safe local release gate, review all application changes since the pre-readiness baseline, and separate simulator/local evidence from checks that require a signed processed TestFlight build or physical hardware. Do not start EXT-01, BETA-04, or any later workstream, and do not archive, upload, deploy, commit, push, or change production data.

## Preserved Prior Work

- TF-02 privacy-manifest implementation remains complete at `6934d39`; archive placement, archive privacy report, and App Store Connect answers remain open.
- TF-03 APNs token-ownership implementation remains complete at `ab9e67b`; its clean-reset SQL evidence remains valid, while production deployment and physical-device notification/account-switch testing remain open.
- TF-04 safe user-facing error mapping remains complete at `7a81129`.
- TF-05 accessibility layout and motion work remains complete at `f548802`, with 153/153 Debug simulator tests, 4/4 focused accessibility tests, unsigned Release build, Release analyzer, and `git diff --check` previously passing.
- TF-06 begins from clean `main` at `f54880285026010be5ec5c1d48137fc41374a21e`, with the local `origin/main` tracking ref at the same commit. Remote freshness must be checked without pushing.

## Release-Gate Invariants

- Evidence must come from the current checkout and exact candidate configuration; stale checklist claims are context only.
- No secret value, APNs token, email address, message body, precise user location, auth session, or other private data may appear in commands, captured output, patches, screenshots, or final reporting.
- Local automated suites may create and reset disposable simulator/local-Docker data only. Production and shared external state remain read-only.
- A static review or simulator run cannot close a physical-device or processed-TestFlight task.
- iOS 17 device coverage is recorded separately from current-iOS coverage.
- Notification, Live Activity, permission, network-recovery, and destructive-account tests remain separate test groups.

## Phase 1: Candidate Baseline and Provenance

- [x] Verify the current branch, worktree/index status, HEAD, remote tracking state, and fresh remote `main` SHA.
- [x] Identify the last pre-readiness baseline and review the complete commit/file diff through the current candidate.
- [x] Record the marketing version, intended build number, bundle identifiers, candidate provenance, environment status, and local/remote migration versions without exposing configuration values.
- [x] Inventory available simulator runtimes, Docker/Supabase/Deno/Xcode tool versions, and the existing authenticated simulator state available for read-only checks.

**Acceptance criteria:** The exact candidate source/configuration baseline is unambiguous, no user changes were altered, and any unavailable provenance field is explicitly marked unverified.

**Verification:** `git status --short --branch`, `git log`, fresh remote comparison, sanitized build-setting inspection, migration ordering inspection, and tool-version checks.

## Phase 2: Automated Release-Compatible Suites

- [x] Regenerate the Xcode project from `ios/project.yml` and isolate the expected test-file references from nondeterministic temporary-group UUID churn.
- [x] Run the complete iOS unit suite in Release-compatible optimized conditions on the smallest installed simulator; record exact counts.
- [x] Run every existing Deno Edge Function test file with only the permissions each suite requires; record exact counts.
- [x] Start local Supabase/Docker, perform a clean local database reset, and run the complete ordered SQL/RLS suite with stop-on-error; record every assertion.
- [x] Stop the local services started by this run without retaining a backup.

**Acceptance criteria:** All three suites pass from the current candidate, with exact counts and no skipped release-gate tests. Any infrastructure failure is distinguished from an application/test failure.

**Verification:** Release-configured `xcodebuild test`, `deno test`, `supabase db reset`, and the full SQL/RLS runner against the local database only.

## Phase 3: Configuration, Secret, Privacy, Logging, and Migration Audit

- [x] Inspect generated Release build settings and bundle inputs for placeholders, localhost/test endpoints, debug flags, fallback credentials, unexpected entitlement differences, and missing privacy resources.
- [x] Inspect tracked configuration and templates using names/presence checks and redacted value classification; never print sensitive values.
- [x] Search application, widget, Edge Function, SQL, and configuration sources for privacy-sensitive logging and remove the verified email-hook violations.
- [x] Review the migration chain in order, including RLS enablement, grants, `SECURITY DEFINER` search paths, service-role boundaries, notification ownership, rollback/mitigation, and parity between migrations and SQL tests.
- [x] Review privacy manifest declarations, entitlements, Info.plist permission copy, URL schemes, App Groups, APNs/environment selection, and resource inclusion in the unsigned Release bundle.

**Acceptance criteria:** No release-blocking placeholder, unsafe fallback, exposed secret, privacy-sensitive log, grant/RLS regression, or configuration mismatch remains. Findings are severity-ranked and tied to concrete files/lines without revealing private values.

**Verification:** Sanitized static searches, `xcodebuild -showBuildSettings` filtering, `plutil`, built-bundle inspection, and manual migration/RLS review.

## Phase 4: Final Diff and Release Toolchain Gates

- [x] Review tests first, then every application/configuration/migration change since the selected pre-readiness baseline across correctness, readability, architecture, security/privacy, and performance.
- [x] Pay particular attention to authentication/session transitions, privacy disclosures, RLS/RPC authorization, migration safety, notifications/Live Activities, deep links, calendar/location permissions, and secret handling.
- [x] Run an unsigned generic-device Release build without automatic package resolution.
- [x] Run the Release static analyzer without signing.
- [x] Run final `git diff --check` and confirm project generation/build/test activity did not alter tracked source unexpectedly.
- [x] Extract and triage compiler/analyzer output; no application-owned high-severity warning was emitted.

**Acceptance criteria:** No unresolved critical/required review finding or application-owned high-severity warning remains; build, analyzer, and whitespace checks pass.

**Verification:** Baseline-to-HEAD diffs, Release `build`, Release `analyze`, result logs filtered for warnings/errors, and final Git status/diff.

## Phase 5: Safe Simulator Runtime Review

- [x] Launch the current candidate on the existing simulator and capture privacy-safe console metadata during cold launch and foreground/background transitions.
- [x] Exercise safe, read-only authenticated paths for launch, force-quit/relaunch, foreground/background, and malformed deep-link rejection.
- [x] Review code paths for connectivity/session expiry, notification taps, Live Activities, calendar export, and location denial/recovery without claiming device-only paths passed.
- [x] Record runtime crashes, assertions, high-severity console errors, stale-session leaks, or unsafe diagnostic output; none was observed in exercised paths.

**Acceptance criteria:** Simulator-verifiable lifecycle paths have explicit results, and device/TestFlight-only behavior is not conflated with static or simulator evidence.

**Verification:** Existing authenticated simulator session, privacy-safe console capture, and focused code-path tracing. Do not submit, mutate production data, send chat, join/leave, edit/cancel, change settings, sign out, or delete the account.

## Phase 6: Physical-Device and Processed-TestFlight Matrix

- [x] Produce separate result columns for an iOS 17 physical iPhone and a current-iOS physical iPhone.
- [x] Cover launch, sign-up/sign-in, email verification, onboarding, Discover, create, join, leave, chat, edit/cancel, reporting/blocking, profile editing, sign-out, and account deletion with prerequisites, expected results, and failure evidence.
- [x] Separate notification/APNs ownership and preview safety, push deep links, badges, Live Activities, calendar permission/export, location denial/recovery, poor-connectivity/airplane mode, lifecycle/force quit, and expired-session scenarios.
- [x] Identify cases requiring a processed build, two accounts/devices, production readiness, or destructive test data.
- [x] Draft internal tester instructions, known issues, evidence fields, stop-ship criteria, and rollback/mitigation guidance.

**Acceptance criteria:** The user can execute every remaining device-only gate without guessing, and each result can be traced to build number, commit, environment, migration version, device, and OS.

## Phase 7: Evidence and Checklist Update

- [x] Update TF-06 boxes only for checks supported by concrete current-run evidence.
- [x] Add dated TF-06 evidence containing exact automated counts, toolchain results, sanitized audit conclusions, simulator coverage, provenance, known issues, and constraints.
- [x] Preserve all TF-02 through TF-05 evidence verbatim.
- [x] Update this plan and `tasks/todo.md` with outcomes, root causes, and remaining user-owned actions.
- [x] Recommend clean commit boundaries without staging or committing.

**Acceptance criteria:** Documentation distinguishes passed, failed, blocked, and unverified gates; TF-06 closes only if its full done-when condition is satisfied.

## Verification Commands

```sh
git status --short --branch
git log --oneline --decorate -12
git ls-remote origin refs/heads/main

cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'platform=iOS Simulator,id=<smallest-supported-simulator-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution ENABLE_TESTABILITY=YES test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze

cd ../supabase/functions/send-push
deno test --allow-env --allow-net
cd ../fetch-weather
deno test --allow-env --allow-net

cd ../../
supabase start
supabase db reset
# Run the ordered SQL files against the disposable local database with ON_ERROR_STOP=1.
# If host psql is unavailable, use the local Supabase database container.

cd ..
git diff --check
git status --short --branch
```

## Physical-Device / TestFlight Evidence Record

| Field | Value |
| --- | --- |
| Marketing version | 1.0 |
| Intended build number | 2 (current local value is 1; no bump performed) |
| Commit SHA | `f54880285026010be5ec5c1d48137fc41374a21e` until source changes |
| Environment | Linked production project; read-only audit found it not candidate-ready |
| Latest migration | Local: `20260910120000_secure_device_token_ownership.sql`; production: `20260718220000` |
| Processed TestFlight build | Not uploaded or verified |
| iOS 17 physical device | Not verified |
| Current-iOS physical device | Not verified |
| Known issues | Production migration/APNs/cron gap; no final SHA; build not bumped; signed archive and physical-device lanes unverified |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Release-configured unit tests are unsupported or behave differently from Debug | High | Run the exact Release scheme first, inspect the generated settings/result bundle, and report configuration failures separately |
| Docker/Supabase is unavailable or local ports conflict | High | Complete all independent gates, capture sanitized version/status evidence, and provide exact recovery steps |
| Configuration inspection leaks secrets | High | Report only key names, presence, source, and classifications; never echo values |
| Simulator success is mistaken for APNs/TestFlight evidence | High | Keep device/TestFlight rows open and label all static/simulator results precisely |
| Existing authenticated simulator state is altered | High | Limit runtime interaction to read-only navigation/lifecycle checks and avoid account/session mutations |
| Project generation creates unrelated diffs | Medium | Compare tracked status immediately after generation and stop before overwriting user work |

## Rollback and Scope

- Expected edits are limited to `tasks/plan.md`, `tasks/todo.md`, and evidence-supported TF-06 updates in `docs/superpowers/plans/2026-09-02-testflight-readiness.md` unless a verified release-blocking defect requires a narrowly scoped fix.
- Any source fix must be preceded by a reproducing test when behavior changes, then the affected suite and all release gates must be rerun.
- Local Supabase reset is destructive only to disposable local Docker data. Do not target a linked or remote project.
- Do not archive, sign, validate in Organizer, upload, submit for review, deploy migrations/functions, modify App Store Connect, commit, push, or start EXT/BETA work.

## Verification Results (2026-09-13)

Toolchain: Xcode 26.2 (17C52), XcodeGen 2.45.4, Deno 2.9.3, Supabase CLI 2.99.0, Docker 29.6.1, and an iPhone 16e simulator on iOS 26.3.1.

| Gate | Result | Evidence |
| --- | --- | --- |
| Candidate provenance | Passed | Clean `main`; HEAD, local tracking ref, and fresh remote `main` were `f54880285026010be5ec5c1d48137fc41374a21e`, with zero divergence. Review baseline: `7076810`. |
| Project generation | Passed with reproducibility note | Sources/configuration were preserved. XcodeGen changes the temporary Products group UUID nondeterministically; that unrelated UUID churn was restored, leaving only the expected new test-file references. |
| iOS tests | Passed | Release-optimized suite with testability enabled: 157 executed, 157 passed, 0 failed, 0 skipped on iPhone 16e / iOS 26.3.1. The unmodified Release configuration cannot compile `@testable` tests because shipping Release correctly has `ENABLE_TESTABILITY=NO`. |
| Edge Function tests | Passed | 24/24: `send-push` 14/14 and `fetch-weather` 10/10. `send-auth-email` has no test suite; `deno check` passed. |
| Local database/RLS | Passed | Clean reset applied all 24 migrations; all 23 ordered SQL phase assertions passed with stop-on-error. The local stack was stopped without backup afterward. |
| Release build/analyzer | Passed | Unsigned generic-device Release build and analyzer completed without emitted application warnings. |
| Bundle/configuration | Local candidate passed | App IDs are `edu.ucf.pickup` and `edu.ucf.pickup.widget`; app icon, app entitlements, widget, and byte-identical app privacy manifest are present. Local Release Supabase settings are present, HTTPS, and non-placeholder. |
| Privacy/security review | Passed locally | Configuration now fails closed; user-facing setup details were removed. Email-hook logs no longer include addresses, domains, raw errors, or provider response bodies. A heuristic tracked/history scan found no committed sensitive file or credential; it is not a substitute for key rotation or a dedicated secret scanner. |
| Simulator lifecycle | Passed within scope | Authenticated cold launch, force-quit/relaunch, background/foreground restoration, and safe rejection of a malformed session deep link passed. No crash, assertion, app-owned high-severity log, or PII-bearing app diagnostic was observed. |
| Production parity | **Blocked / stop ship** | A fresh dry run confirms exactly three migrations remain pending; they were not applied without a recoverable backup. Required APNs and cron secret names remain absent. The privacy-hardened email function is deployed, but `send-push` parity and cron execution are unverified. |
| Processed TestFlight / physical devices | **Partially complete / stop ship** | Build 1.0 (2) has a successful App Store Connect distribution export, production APNs entitlement, reviewed privacy report, and a clean Xcode Organizer validation. Upload/processing, iOS 17 coverage, and current-iOS coverage remain unverified. |

### Fixed release-gate defects

1. `AppConfig` previously substituted placeholder service settings when Release configuration was invalid. It now accepts only a root HTTPS `*.supabase.co` endpoint and a plausibly shaped anon key, otherwise displays a service-unavailable state without constructing the backend client. Four focused tests were demonstrated red then green.
2. `send-auth-email` previously logged a rejected address and raw verification/provider error details. Logs now contain only bounded action/status metadata.

### Candidate record

| Field | Current evidence |
| --- | --- |
| Marketing version | 1.0 |
| Current local build | 2 |
| Intended first-upload build | 2; committed and pushed |
| Candidate app/build SHA | `316b29bd59f5efafcf43151f634ad55b46921b8f` |
| Environment | Linked production project, inspected read-only; not candidate-ready |
| Latest local migration | `20260910120000_secure_device_token_ownership.sql` |
| Latest production migration | `20260718220000` |
| Archive/export | App Store Connect distribution export and Organizer validation complete; not uploaded or processed |

## Physical-Device and Processed-TestFlight Execution Guide

### Prerequisites

- Use the exact processed TestFlight build produced from the final candidate commit. Record version/build, SHA, environment, latest deployed migration, device model, OS, tester initials, date/time, and result before testing.
- Complete the production readiness actions below first. Use two controlled UCF test accounts and preferably two physical iPhones; never use real student content.
- Run every row once on a physical iPhone running iOS 17 and again on a current-iOS physical iPhone. `Not run` is not a pass.
- Capture only privacy-safe evidence: step, timestamp, device/OS, visible symptom, expected versus actual, and a redacted screenshot or Console excerpt. Never capture an email address, token, message body, precise location, or secret.

### Core critical path

| ID | Test and exact action | Expected result | iOS 17 | Current iOS |
| --- | --- | --- | --- | --- |
| C1 | Fresh-install and launch the processed build. | Welcome/auth UI loads without crash, setup copy, placeholder endpoint, or high-severity app log. | Not run | Not run |
| C2 | Create account A with a controlled UCF inbox, verify the code/link, and finish onboarding. | Verification completes once; invalid/expired input is safely explained; onboarding persists. | Not run | Not run |
| C3 | Sign in as account B, force quit, relaunch, background, and foreground. | Session restores without exposing another account or returning to a stale screen. | Not run | Not run |
| C4 | On A, browse Discover and create a uniquely named private test session. | Session appears once with correct host, time, place, capacity, and count. | Not run | Not run |
| C5 | On B, join then leave A's session. Repeat once during a refresh. | Membership and player count change exactly once and remain consistent on both devices. | Not run | Not run |
| C6 | A and B exchange non-sensitive test chat, then reopen chat. | New messages arrive once in order and access follows current membership/block state. | Not run | Not run |
| C7 | A edits the session, then cancels it. | B sees the update/cancellation and cannot act on stale content. | Not run | Not run |
| C8 | B reports the controlled session/account, then blocks and unblocks A. | Confirmation is clear; blocked content/contact is suppressed according to current product behavior. Record any BETA-04 limitation separately. | Not run | Not run |
| C9 | Edit profile fields with synthetic data and relaunch. | Allowed changes persist and render correctly without exposing private data. | Not run | Not run |
| C10 | Sign out A, sign in B on the same device, then switch back. | No profile, notification preview, badge, token ownership, or cached content leaks across accounts. | Not run | Not run |
| C11 | Delete a disposable account after all other tests. | Confirmation is explicit, session is cleared, deleted credentials cannot sign in, and retained/anonymized content matches policy. | Not run | Not run |

### Notifications, deep links, badges, and token ownership

| ID | Test and exact action | Expected result | iOS 17 | Current iOS |
| --- | --- | --- | --- | --- |
| N1 | Allow notifications, trigger join/chat/update/cancel events from the second account, and test foreground/background/terminated delivery. | One correct notification per event; safe preview; no address, message body, token, or stale-account content. | Not run | Not run |
| N2 | Tap each session/chat notification, including after content deletion or access revocation. | Correct destination opens when authorized; unavailable content fails safely without disclosure. | Not run | Not run |
| N3 | Accumulate notifications, open relevant content, switch accounts, and sign out. | Badge increments/clears consistently and never carries another account's count. | Not run | Not run |
| N4 | On one device sign in A, sign out, sign in B, then send an A-only event. | The device token belongs only to B; A's private notification is not delivered or previewed. | Not run | Not run |

### Live Activities

| ID | Test and exact action | Expected result | iOS 17 | Current iOS |
| --- | --- | --- | --- | --- |
| L1 | Join an eligible near-term session and observe Lock Screen/Dynamic Island where supported. | Activity starts once with correct safe metadata and countdown/state. | Not run | Not run |
| L2 | Edit/cancel/leave/end the session and test device restart or force quit during the activity. | Activity updates or ends promptly and does not remain stale or expose another account's data. | Not run | Not run |

### Permissions

| ID | Test and exact action | Expected result | iOS 17 | Current iOS |
| --- | --- | --- | --- | --- |
| P1 | Deny location, retry the location-dependent flow, enable access in Settings, and return. | Denial is recoverable and understandable; granting access restores the flow without restart or crash. | Not run | Not run |
| P2 | Deny calendar access, retry export, then grant the currently requested permission and export again. | Denial is safe; successful export creates one correct event. Note BETA-05's current full-access request. | Not run | Not run |
| P3 | Deny notifications, exercise settings guidance, then enable permission in Settings. | App remains usable; state refreshes and later eligible notifications work. | Not run | Not run |

### Network, lifecycle, and session expiry

| ID | Test and exact action | Expected result | iOS 17 | Current iOS |
| --- | --- | --- | --- | --- |
| NTL1 | Launch online, enable airplane mode, relaunch, browse cached/empty surfaces, then restore network. | No crash or infinite spinner; actionable safe error; recovery occurs without duplicate mutations. | Not run | Not run |
| NTL2 | Interrupt create/join/leave/chat/profile actions by removing connectivity, then retry once. | Failure is truthful; retry is bounded and does not duplicate records/messages/counts. | Not run | Not run |
| NTL3 | Background and force quit during refresh/deep-link handling, then reopen. | App resumes to an authorized coherent state without stale navigation or leaked content. | Not run | Not run |
| NTL4 | Use a controlled expired/revoked session, including from a notification tap. | Credentials are not reused; user is safely returned to auth and destination data is not exposed. | Not run | Not run |

### Stop-ship criteria

- Any crash, assertion, launch failure, invalid signed entitlement, missing privacy manifest/report, or secret/PII in UI or logs.
- Cross-account data, notification, token, badge, chat, or Live Activity leakage.
- Authentication/account deletion failure, authorization/RLS bypass, destructive duplicate operation, or inconsistent membership/player count.
- Missing production migration, APNs/cron configuration, scheduler execution, or processed-build provenance.
- A repeatable P1 regression without an explicit owner, mitigation, and target build.

## Required User-Owned Release Actions

1. Upgrade the Supabase project or otherwise establish an approved recoverable backup/restore path. Until then, the three pending production migrations will not be applied.
2. Enter the private APNs key, key ID, team ID, production environment, app bundle ID, and a new cron secret in Supabase's protected secret manager. Do not send those values through chat or commit them to Git.
3. Confirm the App Store Connect privacy answers match the reviewed archive privacy report.
4. Explicitly authorize Xcode upload when ready. Build 1.0 (2) is archived, distribution-exported, and validated; it has not been uploaded to App Store Connect.
5. After Apple processing, install from TestFlight and execute every matrix row on the iOS 17 and current-iOS lanes. Attach privacy-safe evidence under `docs/testflight-evidence/tf-06/` and update only the corresponding checklist boxes.
6. TF-06 may close only after production parity and every processed-build physical-device gate pass. Then the next checklist workstream is EXT-01; it has not been started here.

## Known Constraints and Mitigation Notes

- `deno fmt --check` reports pre-existing whole-file formatting drift in `send-auth-email/index.ts`; the function type-checks, and TF-06 deliberately avoids an unrelated bulk reformat.
- XcodeGen produces nondeterministic temporary Products-group UUID churn. Always inspect the generated project diff and exclude UUID-only noise.
- BETA-04 (nested session-card actions), BETA-05 (calendar full-access request), BETA-06, BETA-07, BETA-10, BETA-13, and BETA-17 remain separately scoped; none was started.
- If a production migration or notification change fails, stop testing, preserve sanitized failure evidence, disable the affected scheduler/function if required by the approved incident plan, and restore via an additive corrective migration or documented service rollback—not ad hoc production edits.
