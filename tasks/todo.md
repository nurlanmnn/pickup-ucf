# TF-06 Task Checklist

## Scope and Preserved Evidence

- [x] Read the complete readiness checklist and prior focused plan/todo.
- [x] Preserve TF-02 through TF-05 evidence and open user/device/archive constraints.
- [x] Confirm the initial worktree is clean on `main` at `f548802` with local `origin/main` at the same commit.
- [x] Replace the focused files with a TF-06-only plan before other changes.
- [x] Do not start EXT-01, BETA-04, or later workstreams.
- [x] Do not commit, push, deploy, archive, sign, upload, submit, or change production data.

## Candidate Baseline and Provenance

- [x] Verify fresh remote `main` SHA and divergence.
- [x] Identify and justify the pre-readiness diff baseline.
- [x] Review the full baseline-to-candidate commit and file diff.
- [x] Record marketing version, current/intended build, bundle IDs, starting SHA, environment status, and local/remote migration versions; final SHA remains unavailable until an authorized commit.
- [x] Inventory Xcode, simulator/runtime, Deno, Docker, and Supabase availability/versions.

## Automated Suites

- [x] Regenerate the Xcode project and confirm only expected test references remain; document nondeterministic temporary-group UUID churn.
- [x] Run the complete iOS unit suite in Release-compatible optimized conditions.
- [x] Record exact iOS counts: 157 executed/passed, 0 failed, 0 skipped.
- [x] Run all `send-push` Deno tests: 14/14 passed.
- [x] Run all `fetch-weather` Deno tests: 10/10 passed.
- [x] Start local Supabase/Docker without touching production data.
- [x] Run a clean local database reset and apply all 24 migrations.
- [x] Run the complete SQL/RLS suite with stop-on-error enabled.
- [x] Record all 23 SQL phase assertions with no failure.

## Configuration, Secrets, Privacy, Logging, and Migrations

- [x] Audit tracked/generated Release configuration and replace the unsafe placeholder fallback with validated fail-closed behavior.
- [x] Confirm app/widget bundle identifiers, entitlements, App Groups, APNs inputs, URL handling, permission copy, and privacy-manifest inputs; signed production APNs remains a device/archive gate.
- [x] Inspect the built Release bundle for expected resources and manifest placement.
- [x] Audit source logging/diagnostics and remove address/domain/raw-error/provider-body logging from the email hook.
- [x] Audit committed files/history heuristically for likely secret material without displaying values.
- [x] Review migrations, RLS policies, grants, `SECURITY DEFINER` functions, notification ownership, and rollback/mitigation.
- [x] Record latest local migration and production parity gap.

## Final Review and Toolchain Gates

- [x] Review tests and implementation across every commit since the chosen baseline.
- [x] Complete correctness, simplicity, architecture, security/privacy, and performance review.
- [x] Run unsigned generic-device Release build.
- [x] Run Release static analyzer.
- [x] Triage output and confirm no emitted application-owned high-severity warning.
- [x] Run `git diff --check`.
- [x] Confirm generated/build artifacts did not change tracked source unexpectedly.

## Safe Simulator Checks

- [x] Launch the current candidate and inspect privacy-safe runtime console metadata.
- [x] Verify cold launch and force-quit/relaunch without mutating account data.
- [x] Verify background/foreground restoration.
- [x] Verify safe malformed deep-link rejection without external mutation.
- [x] Review poor-connectivity, airplane-mode relaunch, and expired-session behavior; record these as static-only/physical-device checks.
- [x] Review notification, badge, Live Activity, calendar, and location-denial/recovery paths statically; keep physical-device-only claims open.
- [x] Confirm no crash, assertion, app-owned high-severity console error, or PII-bearing app diagnostic was observed in exercised simulator paths.

## Physical Device and Processed TestFlight

- [x] Prepare the iOS 17 physical-device matrix.
- [x] Prepare the current-iOS physical-device matrix.
- [x] Cover launch, auth/email verification, onboarding, Discover, create, join/leave, chat, edit/cancel, reporting/blocking, profile edit, sign-out, and deletion.
- [x] Separate APNs/notification/deep-link/badge tests.
- [x] Separate Live Activity tests.
- [x] Separate calendar and location permission tests.
- [x] Separate poor-connectivity/airplane/lifecycle/session-expiry tests.
- [x] Separate destructive account-deletion and same-device account-transition tests.
- [x] Provide prerequisites, expected results, stop-ship conditions, and failure evidence for every matrix row.
- [ ] Record processed build results only after the user completes them.

## Documentation and Decision

- [x] Record current candidate build/provenance, environment and migration gaps, known issues, and tester instructions; final commit/build remain explicitly pending.
- [x] Update only evidence-supported TF-06 checklist boxes.
- [x] Add dated TF-06 evidence without altering TF-02 through TF-05 evidence.
- [x] Record failures and root causes, including configuration and production blockers separately.
- [x] Document exact user actions for every remaining physical-device/TestFlight/production-owned check.
- [x] Recommend clean commit boundaries without staging or committing.
- [x] State that TF-06 is not ready to close and name—but do not start—EXT-01.
