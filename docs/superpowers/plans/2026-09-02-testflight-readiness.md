# PickUp UCF — TestFlight Readiness Checklist

> **Purpose:** Single source of truth for preparing PickUp UCF for internal TestFlight, external testers, and beta stabilization. Complete the checklist in order, update each checkbox as work lands, and create a focused step-by-step implementation plan for each workstream before changing production code.

**Status:** Internal TestFlight physical-device smoke gate completed by release-owner confirmation on 2026-10-04; external Beta App Review preparation in progress

**Last audited:** 2026-10-22 (authorized source push and production database/function/Vercel/auth rollout verified; physical devices and App Store Connect not re-audited)

**Target sequence:** Internal TestFlight → external TestFlight → stabilized beta

**Scope:** iOS app, Supabase database/Edge Functions, App Store Connect, production operations, accessibility, and beta UX

---



## How to use this document

- Treat `TF-*` items as release gates for the first internal TestFlight build.
- Treat `EXT-*` items as release gates before inviting external testers.
- Treat `BETA-*` items as prioritized beta fixes. Items marked **P1** should be completed early and before a wider external rollout when practical.
- Create a separate implementation plan before starting a workstream. Plans should include exact files, migrations, tests, manual verification, dependencies, and rollback steps.
- A parent item is complete only when its **Done when** criteria are satisfied—not merely when code has been written.
- Do not commit unless explicitly requested.



### Priority legend


| Priority | Meaning                                                                                        |
| -------- | ---------------------------------------------------------------------------------------------- |
| **P0**   | Blocks the first TestFlight upload or creates unacceptable privacy/security/accessibility risk |
| **P1**   | Required before external testers or should be addressed in the first beta iterations           |
| **P2**   | Quality, maintainability, or scale improvement that can follow initial internal testing        |


---



## Audit baseline



### Verified

- [x] Unsigned Release device build completed successfully.
- [x] Xcode static analyzer completed successfully.
- [x] iOS unit suite passed: **110/110 tests**.
- [x] Deno Edge Function suite passed: **18/18 tests**.
- [x] App launched successfully on an iOS 26.3 simulator.
- [x] Welcome screen looked polished at the normal text size.
- [x] Welcome screen accessibility failures were reproduced at Accessibility XXXL.
- [x] The audit itself did not modify application source code.



### Not yet verified

- [x] Signed archive and App Store Connect validation.
- [x] Physical-device push notification and Live Activity behavior (release-owner confirmation on 2026-10-04; detailed device record not supplied in this repository).
- [ ] Production Supabase migrations, secrets, cron jobs, email hook, and APNs configuration.
- [x] SQL/RLS integration suite passed against a clean local Supabase reset on 2026-09-11.
- [x] Authenticated UI flows at runtime (release-owner confirmation of completed physical-device smoke test on 2026-10-04).
- [ ] External TestFlight metadata and Beta App Review submission.

---



# Gate 1 — Before the first TestFlight upload

All `TF-*` items are **P0** and must be complete before uploading the first build.

## TF-01 — App icon, signing, capabilities, and archive configuration

**Why this blocks release:** The audited Release bundle did not contain `Assets.car`, no AppIcon asset was found, all targets had an empty `DEVELOPMENT_TEAM`, and Push Notifications existed only as a project comment rather than a source-controlled entitlement. A local unsigned build is not proof that an App Store archive is valid.

**Evidence:**

- `ios/project.yml`
- `ios/PickUpUCF/Info.plist`
- Missing `ios/PickUpUCF/Assets.xcassets/AppIcon.appiconset/`
- Missing source-controlled app entitlements file with `aps-environment`

**Tasks:**

- [x] Add a production-quality 1024×1024 app icon and a complete `AppIcon.appiconset`.
- [x] Confirm the asset catalog is included in the app target and compiled into the Release bundle.
- [x] Configure the Apple Development Team for the app, widget, and applicable test targets.
- [x] Add source-controlled entitlements for the main app, including Push Notifications.
- [x] Add or verify widget entitlements and App Group configuration used by the app and widget.
- [x] Set `CODE_SIGN_ENTITLEMENTS` for each target that requires entitlements.
- [x] Enable the Push Notifications capability and verify the generated signed entitlement contains the correct production APNs environment.
- [x] Confirm regenerating the Xcode project from `ios/project.yml` does not remove signing or capability configuration.
- [x] Set the correct distribution bundle identifiers and provisioning profiles in the Release/archive configuration.
- [x] Increment the build number for the upload.
- [x] Create a signed Archive using the Release configuration.
- [x] Run Xcode Organizer validation and resolve every blocking error or warning.
- [x] Upload the archive and confirm App Store Connect finishes processing it.

**Done when:** A signed archive validates, uploads, processes in App Store Connect, contains the app icon and required entitlements, and installs from TestFlight on a physical device.

**Evidence (updated 2026-09-15):** Build **1.0 (2)** was committed and pushed from `316b29bd59f5efafcf43151f634ad55b46921b8f`. Xcode created a Release archive and successfully exported an App Store Connect distribution package using cloud-managed Apple Distribution signing. The export summary confirms bundle ID `edu.ucf.pickup`, matching app/widget build 2, App Store provisioning profiles, `get-task-allow=false`, and `aps-environment=production`. The exported app contains the first-party privacy manifest, compiled 1024×1024 `AppIcon` rendition, and Xcode Organizer reported **“Your app successfully passed all validation checks.”** The build uploaded on Sep 14, 2026 and finished Apple processing/export compliance. App Store Connect reports binary state `Validated`, status `Ready to Submit`, production APNs, and `App Icon Hidden: No`. Physical-device TestFlight installation remains open.

## TF-02 — App privacy manifest and required-reason API declaration

**Why this blocks release:** The app directly uses `UserDefaults`, but the audited app target and bundle had no root `PrivacyInfo.xcprivacy`. Required-reason API declarations must reflect the app’s actual use, not only dependency manifests.

**Tasks:**

- [x] Inventory app and extension use of Apple required-reason APIs.
- [x] Add `PrivacyInfo.xcprivacy` to the main app target.
- [x] Declare `NSPrivacyAccessedAPICategoryUserDefaults` with an Apple-approved reason matching the actual usage.
- [x] Add a separate manifest to the widget target if its own code requires one. (Inventory confirmed it does not.)
- [x] Declare tracking and collected-data fields accurately; do not copy dependency declarations blindly.
- [x] Verify the manifest is included in the archived app bundle.
- [x] Generate and review Xcode’s privacy report for the archive.
- [x] Ensure App Store Connect privacy answers match the manifest and real production behavior.

**Evidence (2026-09-10):** Added `ios/PickUpUCF/PrivacyInfo.xcprivacy` to the main app resources only. First-party and resolved-package inspection found only app `UserDefaults` required-reason use; its app-only defaults domain matches Apple reason `CA92.1`. The widget has no required-reason API use, independent collection/tracking, or third-party dependency, so it has no separate manifest. The manifest declares tracking false, no tracking domains, and nine linked/non-tracking categories based on repository behavior: name, email address, fitness, precise custom game coordinates, emails/text messages, other user content, user ID, device ID, and product interaction. Fitness and the user ID used to retrieve preferred sports are used for app functionality and product personalization; the remaining categories are used for app functionality. `xcodegen generate` placed the file only in the app resources phase. Source, Debug, and unsigned Release app manifests match byte-for-byte and pass `plutil`; both built widget bundles correctly contain no manifest. Debug simulator tests passed (123/123), as did the unsigned Release device build and Release static analyzer. The user confirmed the main App Store Connect record exists for bundle ID `edu.ucf.pickup` (Apple ID `68107128702`, Prepare for Submission); no widget record was created. The user also confirmed Supabase, Brevo, Open-Meteo, and APNs are used only for app functionality, with no advertising, data-broker sharing, cross-company tracking, or undisclosed analytics/crash-reporting integration. Archive placement, Xcode's archive privacy report, and App Store Connect privacy answers remain unverified/user-owned.

**Archive evidence (updated 2026-09-15):** The App Store Connect export contains the root app privacy manifest. Xcode Organizer generated a one-page privacy report with the declared linked, non-tracking data categories; visual inspection found no clipping, overlap, invalid-manifest warning, or unreadable content. The report is stored locally at `docs/testflight-evidence/tf-06/PickUpUCF-1.0-2-Privacy-Report.pdf` and remains ignored by Git. The user published the matching App Store Connect privacy answers and saved the public privacy-policy URL.

**Done when:** The signed archive contains valid privacy manifests, Xcode’s privacy report has been reviewed, and App Store Connect privacy answers are consistent with the app.

## TF-03 — Prevent APNs device-token ownership leaks across accounts

**Why this blocks release:** `device_tokens` currently allows the same APNs token to remain associated with more than one user because its key is `(user_id, apns_token)`. Sign-out and account deletion do not unregister the device token. On a shared phone, user A could continue receiving notifications—including chat previews—after user B signs in.

**Evidence (2026-09-10, SQL verification 2026-09-11):** Added `20260910120000_secure_device_token_ownership.sql`, which normalizes and deduplicates legacy values, makes `apns_token` the primary key, revokes client table writes, gives the service role only sender-required read/delete access, and exposes authenticated `SECURITY DEFINER` register/unregister functions. Registration derives the owner from `auth.uid()` and atomically transfers a token; unregistration is owner-scoped so a delayed user-A cleanup cannot remove user B's transferred row. The iOS client now persists the last token without logging it, serializes callback/transition operations, retries ownership at authenticated bootstrap and when returning from an iOS authorization change, unregisters before sign-out/deletion, disables local remote notifications, and synchronously ends local Live Activities. Sign-out always clears local UI/auth state with a token-free warning on incomplete server cleanup; failed account deletion restores notification registration and keeps the session. Sender coverage confirms chat previews select only the outbox user's current token, while existing APNs 410 cleanup remains covered. All 137 iOS tests and all 24 Deno Edge Function tests pass; the unsigned Release device build and Release analyzer also pass. A clean local `supabase db reset` applied every migration, including TF-03, and the complete SQL/RLS suite passed with `phase_f_device_token_ownership: ownership lifecycle OK`. Production deployment and physical-device APNs/account-switch testing remain user-owned.

**Implementation files:**

- `supabase/migrations/20260910120000_secure_device_token_ownership.sql`
- `supabase/tests/phase_f_device_token_ownership.sql`
- `ios/PickUpUCF/Core/PushNotificationService.swift`
- `ios/PickUpUCF/Core/AccountTransitionCoordinator.swift`
- `ios/PickUpUCF/Repositories/DeviceTokenRepository.swift`
- `supabase/functions/send-push/index_test.ts`

**Tasks:**

- [x] Make each APNs token have one current account owner at the database level.
- [x] Prefer an authenticated RPC that atomically reassigns the token to `auth.uid()` instead of a client-side delete/insert sequence.
- [x] Revoke broad execution rights on the RPC and grant only the roles that need it.
- [x] Store the most recently registered token locally so it can be removed during account transitions.
- [x] Unregister the token before sign-out and before account deletion.
- [x] Define safe behavior when unregistering fails: local auth state must still be cleared, and the failure must be recoverable/observable without exposing the token.
- [x] Re-register/reassign the token after login, token rotation, app reinstall, and authorization changes.
- [x] Preserve server cleanup for APNs responses indicating an invalid or unregistered token.
- [x] Add migration tests proving one token cannot remain attached to two users.
- [x] Add regression coverage for: user A signs in → token registers → A signs out → user B signs in on the same device → only B receives notifications.
- [ ] Confirm notification payload previews do not expose sensitive chat content to a stale account/device mapping.

**Done when:** Database constraints and end-to-end tests prove that an APNs token has exactly one current owner and account transitions cannot deliver one user’s notifications to another user.

## TF-04 — Fix user-facing error mapping

**Why this blocks release:** `AppErrorMapper` returns any `LocalizedError` before reaching friendly Supabase-specific mappings. Supabase `AuthError` and `PostgrestError` also conform to `LocalizedError`, so raw backend text can reach users and intended recovery guidance can be skipped.

**Evidence:** `ios/PickUpUCF/Core/AppErrorMapper.swift`

**Tasks:**

- [x] Reorder or redesign mapping so known auth, database, networking, validation, and domain errors are handled before a generic `LocalizedError` fallback.
- [x] Ensure unexpected server details, SQL text, internal identifiers, and implementation messages never appear in the UI.
- [x] Preserve actionable copy for common states such as duplicate accounts, invalid credentials, expired links, connectivity loss, conflicts, and capacity limits.
- [x] Add tests using real `AuthError`/`PostgrestError` values where constructible, or accurate test doubles that conform to `LocalizedError`.
- [x] Add a safe generic fallback and retain detailed diagnostics only in privacy-safe internal logging.
- [x] Audit all views/view models that show repository errors to ensure they use the mapper consistently.

**Evidence (2026-09-11):** `AppErrorMapper` now inspects bounded, cycle-protected underlying-error chains and handles cancellation, `URLError`, structured Supabase `AuthError` codes, structured `PostgrestError`/SQLSTATE codes, and concrete app-authored domain errors before narrow compatibility text classification. Compatibility checks return fixed allowlisted copy only; arbitrary `LocalizedError` descriptions and unknown auth/database messages fall back to `Something went wrong. Please try again.` Developer-facing configuration and migration instructions were replaced with user-appropriate service-unavailable copy. Regression tests use real constructible `AuthError` and `PostgrestError` values plus accurate localized and wrapped-error doubles, inject SQL/token/identifier/stack-trace-like details, and cover authentication, verification/reset expiry, networking, cancellation, conflicts, capacity/waitlist, authorization, validation, and every app-authored domain-error family. A static presentation audit confirmed repository failures shown in global banners, load states, action errors, and inline API feedback already converge on the mapper; direct messages are deliberate field validation or fixed account-transition guidance. No raw-error or sensitive-value logging was added. Focused tests pass; the complete iOS Debug simulator suite passed 149/149 on iPhone 17 Pro / iOS 26.3.1; the unsigned generic-device Release build and Release analyzer passed; `git diff --check` passed. Authenticated runtime UI verification remains unverified because no safe test credentials were available.

**Done when:** Known failures produce specific, friendly recovery messages; unknown failures produce safe generic copy; raw backend errors are covered by regression tests and do not reach users.

## TF-05 — Make the app usable with accessibility text sizes

**Why this blocks release:** At Accessibility XXXL, the welcome headline/body truncate and the Sign Up/Sign In controls clip. The shared buttons use a fixed 50-point height, and the Welcome layout is not scrollable. Shared components can reproduce the problem throughout the app.

**Evidence:**

- `ios/PickUpUCF/DesignSystem/Components/PrimaryButton.swift`
- `ios/PickUpUCF/DesignSystem/Components/SecondaryButton.swift`
- `ios/PickUpUCF/Features/Auth/WelcomeView.swift`
- `ios/PickUpUCF/DesignSystem/AccessibilityLayout.swift`
- `ios/PickUpUCFTests/AccessibilityLayoutTests.swift`
- `docs/testflight-evidence/tf-05/`

**Tasks:**

- [x] Replace fixed button heights with a minimum height plus vertical padding that allows labels to grow.
- [x] Make the Welcome screen scroll or adapt with `ViewThatFits`/equivalent when content no longer fits.
- [x] Allow multiline labels where truncation would remove meaning.
- [x] Review fixed frames, hard-coded spacers, and combined accessibility elements across all major screens.
- [x] Verify touch targets remain at least 44×44 points.
- [ ] Test every screen at all Dynamic Type accessibility sizes on the smallest supported iPhone.
- [ ] Test VoiceOver reading order, labels, hints, actions, focus behavior, and modal dismissal.
- [x] Test Increase Contrast, Reduce Motion, Bold Text, button shapes, light mode, and dark mode.
- [x] Add accessibility identifiers needed for repeatable UI checks.
- [x] Add focused tests for shared component sizing where practical and preserve screenshots/manual evidence for the release checklist.

**Evidence (2026-09-12):** The Accessibility XXXL Welcome failure was reproduced on the smallest installed simulator, iPhone 16e / iOS 26.3.1. Before the fix, the headline/body/guidance truncated, the shared fixed-height button labels clipped, and overflow was unreachable. Shared buttons now use multiline labels, vertical padding, and a 44-point minimum; display typography uses a semantic text style; Welcome is viewport-aware and scrollable; and compact chips, map controls, session actions, and chat send controls meet the shared minimum target. Session cards, numeric stepper rows, create-session actions, profile statistics, and session-detail content adapt vertically at accessibility sizes. Decorative auth branding is hidden from assistive technologies, and nonessential shared/root/tab/discover/create/edit/chat motion respects Reduce Motion. Static audits covered onboarding, authentication, Discover, My Games, create/edit, session detail, attendance/reporting, chat, profile/host profile, settings, banners, sheets, alerts, loading/error/empty states, and modal dismissal paths. BETA-04's nested session-card navigation/action issue was recorded but deliberately not changed.

Runtime evidence covers all 12 supported Dynamic Type categories on iPhone 16e / iOS 26.3.1, settled Large and Accessibility XXXL Welcome screenshots, reachable Accessibility XXXL Welcome actions, AX-tree order and actionable names on Welcome/Sign Up, Light/Dark auth rendering, Increase Contrast, Bold Text, Button Shapes, and Reduce Motion. An existing authenticated test session was then exercised at Accessibility XXXL across Discover list/map/filter states, My Games/history, every create-session step without submission, completed/cancelled session detail, empty chat without sending, profile/host profile, settings, notification rows without changing values, blocked users, account forms without submission, keyboard accessories, and navigation/sheet dismissal. Issues found in the authenticated pass were repaired in the create details stepper/actions, My Games section heading, notification rows, shared empty states, and session-detail hero/roster metadata. Authenticated Large checks confirmed the standard Discover, My Games, Create, and Profile layouts remain intact. Credentials were not entered or transmitted because the simulator already held an authenticated session.

Focused layout tests passed 4/4, the complete Debug simulator suite passed 153/153, the unsigned generic-device Release build passed, the Release analyzer passed, and `git diff --check` passed. The broad per-screen/per-size task remains open because all 12 sizes were exercised on safe unauthenticated surfaces while authenticated runtime coverage concentrated on Large and Accessibility XXXL. The accessibility tree was inspected for labels, values, hints, order, decorative-element hiding, and dismissal actions, but auditory VoiceOver/rotor/focus operation, Switch Control/Voice Control, and physical-device behavior remain manual. Destructive or state-changing actions were deliberately not performed: join/leave, create/edit/cancel/run-it-back submission, attendance/report submission, chat send, notification changes, block/unblock, sign-out, password change, and account deletion. The two broad runtime tasks above therefore stay open.

**Done when:** Core flows are readable and operable without clipping, truncation, overlapping, or unreachable controls at the largest supported text size and with VoiceOver.

## TF-06 — Internal TestFlight release gate

**Dependencies:** TF-01 through TF-05.

**Tasks:**

- [x] Run the full iOS unit suite in Release-compatible conditions.
- [x] Run the Deno Edge Function suite.
- [x] Start local Supabase/Docker and run the SQL/RLS integration suite.
- [x] Review the final app diff with special attention to auth, privacy, RLS, migrations, notifications, and secrets.
- [x] Upload the validated archive and confirm Apple processing/export compliance.
- [x] Create the internal TestFlight group, assign build 1.0 (2), invite the initial internal tester, and save “What to Test” instructions.
- [ ] Confirm production configuration contains no placeholders, test endpoints, debug flags, or development credentials.
- [x] Verify no secrets, APNs tokens, emails, message bodies, or other PII are logged.
- [x] Install the processed build through TestFlight on physical hardware (release-owner confirmation; device/OS matrix details not supplied here).
- [x] Smoke test launch, sign-up/sign-in, email verification, onboarding, discover, create, join, leave, chat, edit/cancel, reporting/blocking, profile editing, sign-out, and account deletion (release-owner confirmation).
- [x] Test poor connectivity, airplane-mode relaunch, background/foreground transitions, force quit, and expired sessions (release-owner confirmation).
- [x] Verify push notifications, deep-link routing, badge behavior, and Live Activities on physical hardware (release-owner confirmation).
- [x] Verify calendar export and location permission denial/recovery (release-owner confirmation).
- [x] Confirm crash-free launch and no high-severity runtime console errors (release-owner confirmation).
- [x] Record the build number, commit SHA, environment, migration version, known issues, and tester instructions.

**Evidence (2026-09-13):** TF-06 began from clean `main` at `f54880285026010be5ec5c1d48137fc41374a21e`; a fresh read-only remote check confirmed `origin/main` at the same SHA with zero divergence. The final review baseline is `7076810`, immediately before the seven candidate commits that added/fixed Live Activity delivery and then completed TF-02 through TF-05. The optimized Release-configured simulator suite passed **157/157** with `ENABLE_TESTABILITY=YES`, 0 failures, 0 skipped, on iPhone 16e / iOS 26.3.1. An initial unmodified Release test attempt failed before execution because shipping Release correctly has testability disabled while the suite uses `@testable import`; this was a test-configuration constraint, not an application build failure. The Deno suites passed **24/24** (send-push 14/14; fetch-weather 10/10). A clean local Supabase reset applied all 24 migrations, and the complete SQL/RLS suite passed all **23** phase assertions with stop-on-error enabled. The unsigned generic-device Release build and Release static analyzer passed with no emitted application warnings; the built app contains `Assets.car` and a byte-identical privacy manifest, while the widget correctly has no separate manifest. Source plists and the built app/widget report version **1.0 (1)**. The local Release configuration contains present, non-placeholder, HTTPS Supabase settings and targets the same linked project, but secret values were not displayed or recorded.

The final baseline-to-candidate review covered tests first, then authentication/session transitions, APNs ownership, Live Activities, push payload/deep-link routing, privacy resources, error mapping, RLS/RPC grants, migrations, accessibility changes, and dependency/configuration scope. It found and repaired two TF-06 defects in the uncommitted working tree: invalid app configuration previously fell back to a placeholder service and showed developer setup instructions to users, and `send-auth-email` logged a rejected full address plus raw verification/provider error details. `AppConfig` now validates and fails closed, renders a service-unavailable state without constructing the backend client, and blocks backend deep-link handling until configuration is valid; 4/4 focused tests were demonstrated red then green. The email function now logs only bounded event/status metadata and passes `deno check`. A static diagnostics audit found no iOS app logging APIs and no remaining email/token/body/error-detail arguments in the email function's logs. A high-confidence tracked-history scan found only the documented private-key marker example in `README.md`; no sensitive-path file has been tracked. `deno fmt --check` remains red for the pre-existing formatting of `send-auth-email/index.ts`; a broad unrelated reformat was intentionally not bundled into TF-06.

Safe simulator checks on the current working tree confirmed authenticated cold launch, force-quit/relaunch, background/foreground restoration, and rejection of a malformed custom-scheme session link without mutating account data. The app remained on the authenticated Discover surface. Fourteen initial and two final high-severity unified-log entries were all Apple Network framework connection-state queries (`unconnected connection` / `no local endpoint`); there was no crash, assertion, app-owned error log, or PII-bearing app diagnostic. This does not close the processed-build/physical-device console check.

**Pre-deployment state (2026-09-13):** The linked production backend was not at migration parity: a dry run showed `20260822000000`, `20260909000000`, and `20260910120000` pending. They were initially deferred because no recoverable hosted backup was available without a Supabase plan upgrade. This state was superseded by the authorized 2026-09-16 deployment recorded below. The privacy-hardened `send-auth-email` revision was type-checked and deployed successfully; `fetch-weather` and `send-push` remained active. The six required APNs/cron secret names were present, but no secret values were read. Production cron status and exact `send-push` code parity remained unverified.

Build **1.0 (2)** is committed and pushed at `316b29bd59f5efafcf43151f634ad55b46921b8f`. Xcode created a Release archive, exported it with cloud-managed Apple Distribution signing, and confirmed production APNs entitlement, matching app/widget build numbers, App Store profiles, and the root privacy manifest. The generated privacy report was visually reviewed and stored in the ignored evidence directory. Xcode Organizer validation passed every check.

**Processed-build update (2026-09-15):** Xcode uploaded build **1.0 (2)** on Sep 14, 2026, and App Store Connect completed processing and export compliance. The build is `Ready to Submit`; Build Metadata reports binary state `Validated`, bundle ID `edu.ucf.pickup`, minimum iOS 17.0, arm64, symbols included, `get-task-allow: false`, production `aps-environment`, and the matching `edu.ucf.pickup.widget` extension. It reports `App Uses Non-Exempt Encryption: No` and `App Icon Hidden: No`. The submitted compliance answers identify standard encryption and exclude France, avoiding a separate French encryption filing for this build. The compiled distribution asset catalog contains the 1024×1024 `AppIcon` rendition, although App Store Connect may continue to show a placeholder until the build is attached to a version.

The user published the App Store privacy answers and saved the public privacy-policy URL. The six required APNs/cron secret names are present without their values being read. The Supabase upgrade remains deferred; the three migrations that were pending at this point were later deployed with the EXT-01 migration on 2026-09-16. Scheduler execution and exact deployed `send-push` parity remain unverified. Physical-device installation and every iOS 17/current-iOS matrix row remain open. Detailed tester instructions are in `docs/testflight/tf-06-device-runbook.md`.

**Internal-testing update (2026-09-16):** The internal TestFlight group **Internal Testers** exists. Build **1.0 (2)** is assigned to the group with status **Testing**, one internal Apple Account has been invited, and the internal “What to Test” instructions are saved. This completes the upload and internal-group setup portion of TF-06 only. It does not close TF-06: invitation acceptance, TestFlight installation, and every iOS 17/current-iOS physical-device row still require direct device evidence.

**Physical-device failure update (2026-09-16):** During sign-out at approximately 10:09 AM America/New_York, TestFlight build **1.0 (2)** returned to Welcome and showed “You’re signed out. Some server cleanup could not be confirmed.” Device model and iOS version were not recorded. TF-06 runbook step 11’s sign-out/account-transition portion is failed, and step 16’s account-specific notification isolation is blocked until token cleanup is proven; TF-06 remains open. Read-only production verification showed migration `20260910120000` absent and independently confirmed that its register/unregister RPCs were not present in the production schema. APNs token unregistration was therefore a confirmed broken dependency whenever a stored device token existed. Because the device’s token state was not recorded and build 1.0 (2) aggregates failures, the screenshot alone cannot prove which branch emitted the warning or whether remote Supabase logout also failed; Live Activity cleanup cannot emit it. The code remediation uses an authenticated-user-and-exact-token legacy delete only for the explicit missing-RPC response, does not add a registration/upsert fallback, and quarantines APNs after unconfirmed ownership until atomic registration succeeds. Focused tests passed 20/20, the complete iOS suite passed 171/171, and the unsigned Release build and analyzer passed. See the dated result and retest procedure in `docs/testflight/tf-06-device-runbook.md`. At the time of this failure investigation, no migration had yet been deployed and no production data had been changed.

**Production migration update (2026-09-16):** After reviewing a dry run that listed four pending migrations, the user explicitly authorized deploying all four without a backup. Production applied `20260822000000_fix_leave_session_player_count.sql`, `20260909000000_live_activity_end_pushes.sql`, `20260910120000_secure_device_token_ownership.sql`, and `20260916090000_ugc_safety_and_moderation.sql` in order. A fresh linked migration listing verified local/remote parity, and a schema-only export verified the one-token primary key plus the authenticated, owner-constrained `register_device_token(text)` and `unregister_device_token(text)` functions. This resolves the confirmed missing-RPC backend prerequisite. It does not erase the recorded build 1.0 (2) failure or close TF-06: step 11 remains failed and step 16 remains blocked until the remediation build passes both physical-device lanes.

**Live Activity and in-app privacy update (2026-09-15):** Settings → Privacy now includes a native system `Link` labeled **Privacy Policy** that opens the published `https://pickup-ucf-privacy.vercel.app` page. Live Activity content now carries both session start and end times, derives pre-session/live/ended presentation from those dates, and uses the session end as the stale boundary instead of treating staleness as the start signal. The app immediately ends expired activities when it launches, becomes active, or refreshes My Games session data, while leave, host cancellation, cancellation notifications, sign-out, and account transitions retain immediate local cleanup. The APNs end payload now includes `startsAt` and `endsAt`, matching the Swift content state. Regression tests were demonstrated red before the fix and green afterward; focused checks passed 13/13 iOS and 3/3 Live Activity Edge Function tests, the complete iOS suite passed 159/159, all 14 `send-push` tests passed, Deno formatting passed, and the unsigned Release build and Release analyzer passed.

The `20260909000000_live_activity_end_pushes.sql` migration was deployed on 2026-09-16. Reliable background removal still requires deploying or confirming the current `send-push` function revision and verifying that the production scheduler invokes it successfully. No new TestFlight build was uploaded as part of the migration deployment.

**Done when:** All automated checks pass, a processed TestFlight build completes the physical-device critical-path smoke test, and the build’s exact backend/configuration state is recorded.

**Gate disposition (2026-10-04): COMPLETE by release-owner confirmation.** The user confirmed that the physical-device smoke test is complete and directed that TF-06 be treated as completed. The physical-device rows above record that attestation; no smoke test was rerun in this work. Earlier dated failure investigations remain historical evidence. The user did not provide the passing build number, device/OS matrix, timestamps, or redacted runbook results, so this repository cannot independently reconstruct those details. The separate production-configuration checkbox remains an evidence gap and is tracked with EXT-05 before external submission; do not represent it as independently verified.

---



# Gate 2 — Before inviting external testers

All `EXT-*` items are **P1** and must be complete before a build is submitted to Beta App Review or shared outside the internal team.

## EXT-01 — User-generated-content safety and moderation

**Why this is required:** Session notes and chat are user-generated content. Filtering, message/user/session reporting, blocking, moderator operations, and published support are implemented in source. This gate also requires production/candidate verification and operational coverage before external testing.

**Tasks:**

- [x] Publish clear community rules and prohibited-content standards.
- [x] Add reasonable objectionable-content filtering for session notes, display names, custom sports/locations, and chat messages (source and local SQL/unit evidence).
- [x] Let users report an individual message, user, and session with a reason and optional context (implemented; exact-candidate device check remains below).
- [x] Let users block an abusive user across discovery, sessions, chat, notifications, and future interactions—not only one session (source and local SQL evidence).
- [x] Define what happens to existing shared sessions and chat history after a block (membership/history retained; protected content hidden; unblock restores future access).
- [x] Prevent blocked users from contacting or notifying each other through alternate app flows (source and local SQL evidence).
- [x] Build an authenticated moderation workflow for reviewing reports, removing content, warning/suspending users, and recording actions (implemented; production candidate flow remains below).
- [x] Define a response-time target and escalation path for urgent safety reports (runbook published; backup coverage remains below).
- [x] Publish an accessible support/contact method in the app and store metadata (source plus previously saved metadata; exact-candidate check remains below).
- [x] Rate-limit report creation and protect moderation functions with least-privilege RLS/RPC permissions (local SQL evidence).
- [x] Test abusive-content, false-report, duplicate-report, block/unblock, deleted-account, and notification edge cases (local SQL suite; production/device evidence remains below).
- [ ] Execute the production role/access matrix and synthetic report/moderator-action flow on the exact external candidate, including ordinary-user denial and block/notification behavior.
- [ ] Assign backup support/moderation coverage and record private escalation ownership.
- [ ] Complete the App Store age-rating/content questionnaire based on actual UGC behavior.

**Done when:** Users can filter/avoid, report, and block abusive content or users; moderators can act on reports promptly; the policy and contact path are visible; abuse tests pass.

**Local implementation evidence (2026-09-16):** Source now includes client/server UGC validation, typed message/user/session reports, symmetric block enforcement, private rate-limited moderation RPCs, audited moderator actions, warning/suspension notices, in-app rules/support, and an operations runbook. A clean local migration reset and the full SQL/RLS suite pass, along with 167 iOS tests, an unsigned Release build, and static analysis. The EXT-01 migration was deployed later on 2026-09-16. The Community Guidelines were published at `https://pickup-ucf-privacy.vercel.app/community-guidelines.html` on 2026-09-30 and returned HTTP 200. Nurlan Mammadli was provisioned as the production moderator on 2026-09-30; a privacy-safe verification resolved one intended profile, one moderator row, and `is_current_user_moderator() = true`, while an unrelated authenticated profile returned `false`. EXT-01 remains open because backup moderation/support coverage is not assigned, physical-device behavior is not verified, and the App Store age-rating/content questionnaire remains user-owned.

## EXT-02 — Privacy policy, terms, data disclosures, and support

**Tasks:**

- [x] Publish a stable HTTPS privacy-policy URL.
- [x] Link the privacy policy from an easily discoverable in-app location. The App Store Connect URL is saved.
- [x] Document what is collected and why: email, profile identity, sessions, attendance, chat, reports, device tokens, location permission behavior, calendar identifiers, and notification data.
- [x] Name relevant processors/services, including Supabase, Brevo, Open-Meteo, and Apple/APNs, and explain their roles accurately.
- [x] Document retention, deletion, account deletion, consent withdrawal, security practices, and contact details.
- [x] Publish Terms of Use/community rules appropriate for a campus social/sports app.
- [ ] Confirm in-app account deletion removes or anonymizes data according to the published policy and any safety/legal retention needs.
- [x] Complete and publish App Store Connect App Privacy answers from the production data-flow inventory.
- [x] Ensure support email, privacy contact, and response ownership are monitored.

**Evidence (2026-09-14):** The privacy policy is publicly available at
`https://pickup-ucf-privacy.vercel.app`. The production deployment returned HTTP
200 over HTTPS and was manually checked at desktop and mobile widths with no
browser-console errors or warnings. The page names the app's data categories,
purposes, service providers, device-permission behavior, retention and deletion
approach, user choices, security practices, and public contact address. App Store
Connect's nine data-type disclosures are published, and the privacy-policy URL is
saved in the English (U.S.) metadata. Settings → Privacy now includes a native
**Privacy Policy** link in source after build 1.0 (2); it requires a future build
and physical-device verification before external testing.

**Source update (2026-09-30):** Added a publishable Terms of Use page at
`privacy-site/terms.html`, cross-linked the Privacy Policy, Terms, and Community
Guidelines sources, and added a Terms link to Settings. Publication of the new
pages and verification on the external candidate build remain open.

**Ownership update (2026-09-30):** The user confirmed Nurlan Mammadli as the
public operator and confirmed that `support.roomateapp@gmail.com` is actively
monitored. External-delivery verification and backup coverage remain open.

**Publication update (2026-09-30):** Vercel production deployment
`dpl_4Cfh4ZZDSonGyr7PEiddBhk4rkDs` published the Terms at
`https://pickup-ucf-privacy.vercel.app/terms.html` and the Community Guidelines
at `https://pickup-ucf-privacy.vercel.app/community-guidelines.html`. The privacy,
Terms, and guidelines URLs each returned HTTP 200. The live Terms page identifies
Nurlan Mammadli as the operator, displays the monitored support address, exposes
the expected heading/link accessibility structure, and produced no browser
console warnings or errors.

**Done when:** In-app links work, policies match the shipped product and backend, App Store disclosures are consistent, and deletion/retention behavior has been tested.

## EXT-03 — Beta App Review access and reviewer notes

**Why this matters:** Registration is restricted to UCF email addresses, so the reviewer needs a reliable preverified path into the app.

**Tasks:**

- [x] Create a dedicated, preverified UCF demo account for Beta App Review (email-confirmed auth record, password present, and release-owner-confirmed TestFlight sign-in).
- [x] Seed safe sample data so Discover, My Games, session detail, chat, report/block, and profile flows can be reviewed (production rows and reviewer-scoped RLS verified; release owner reports successful app navigation).
- [x] Ensure the seeded content uses only controlled accounts, public campus venues, neutral messages, and no production secrets (verified from the seed transaction and row counts; ordinary production content may still be discoverable under normal app policy).
- [x] Add credentials directly in App Store Connect and exact login steps to Beta App Review Information (saved and reloaded 2026-10-04; credential values excluded from Git).
- [x] Explain the UCF-email restriction and any one-time verification behavior in the review packet; the account's confirmed-email state was verified in production auth.
- [x] Draft reviewer notes for notification, location, calendar, widget, Live Activity, deep-link, reporting, and account-deletion flows; confirm seeded flows before saving in App Store Connect.
- [ ] Confirm the review account remains usable for the duration of review.

**Done when:** A reviewer starting from a fresh install can access and exercise every review-relevant feature without contacting the developer.

**Preparation update (2026-09-30):** `docs/testflight/external-beta-review-packet.md`
now contains draft beta metadata, reviewer notes, seed-data requirements,
age-rating guidance, cohort settings, and a submission checklist. Personal contact
details and demo credentials remain intentionally outside Git and must be entered
directly in App Store Connect.

**Reviewer-packet update (2026-10-04):** The public Privacy Policy, Terms of Use, and Community Guidelines opened successfully over HTTPS and cross-link. Source inspection confirmed the Sign In form, Discover/My Games/Create/Profile navigation, Settings paths, My Games past section, and Live Activity-only widget extension. The packet now gives exact login and navigation instructions, public policy URLs, support contact, optional-permission notes, and the App Store Connect credential-entry location. A dedicated plus-addressed UCF reviewer account was created through Supabase's auto-confirmed admin form; the release owner entered its password directly. Production auth reports one matching user, confirmed email, password present, and zero moderator grants. A synthetic onboarded profile, five labeled public-venue games, three joined memberships, and four neutral messages from two controlled accounts were seeded. A transaction-scoped authenticated RLS check as the reviewer returned one own profile, five visible sample games, four visible messages, and `is_current_user_moderator() = false`. The release owner subsequently confirmed TestFlight sign-in and seeded navigation below. Refresh of the near-term Live Activity game remains open if its start time passes before review. No password, verification link, account email, token, or account identifier was written to Git.

**App Store Connect update (2026-10-04):** Test Information was saved with beta description, monitored feedback email, privacy URL, reviewer contact, sign-in requirement, demo username/password, and feature/setup notes. A reload confirmed persistence and no validation banner. The release owner entered the private phone number and password; neither was copied into this repository. Candidate-specific What to Test/known issues and the external go/no-go gate remain open. No build was submitted for review.

**Reviewer app check (2026-10-04):** After the saved Test Information was verified, the release owner signed in with the reviewer account in TestFlight, checked the seeded experience, and reported that everything looked good. This is owner-reported app evidence, not an independently observed screen-by-screen record. The owner did not provide a build number, device/OS, fresh-install status, or individual join/report/block/action results. The earlier reviewer-scoped RLS check and zero moderator grants remain the evidence for data access and ordinary-user role. Refresh the near-term seed before review if its start time passes.

## EXT-04 — TestFlight metadata and tester experience

**Tasks:**

- [ ] Add the external-beta description and final “What to Test” scope. Internal instructions for build 1.0 (2) are saved.
- [x] Add a monitored feedback email and reviewer contact information (saved and reloaded in App Store Connect on 2026-10-04).
- [x] Add the required export-compliance information for build 1.0 (2), with France excluded.
- [ ] Prepare screenshots or annotated test notes for flows that require setup.
- [ ] List known issues honestly and distinguish unsupported behavior from defects.
- [ ] Create an initial small external group before widening access.
- [ ] Define how testers should submit reproduction steps, screenshots, device/iOS version, and diagnostic context.

**Done when:** App Store Connect accepts the external testing configuration and testers have clear scope, setup, feedback, and support instructions.

## EXT-05 — Production backend and notification readiness

**Tasks:**

- [x] Deploy the two missing October 5 migrations, seven October 22 hardening/deletion migrations and the additional null-host scheduled-cleanup fix. All ten applied October 22; remote dry run reports up to date.
- [ ] Verify RLS is enabled and least-privilege policies behave correctly for anonymous, authenticated, blocked, and deleted users.
- [x] Configure `APNS_ENV=production` and verify the existing APNs key/team/bundle identifiers for TestFlight delivery (2026-09-17).
- [ ] Complete secret ownership documentation; the dedicated push cron secret is configured, while Brevo/email-hook ownership still requires verification.
- [ ] Confirm notification outbox cron schedules are active, idempotent, and monitored. The once-per-minute push schedule is active, but physical-device delivery remains open after the 2026-09-18 APNs provider-token correction.
- [ ] Exercise the production email-verification/reset hooks and failure path.
- [ ] Verify APNs invalid-token cleanup and delivery status handling.
- [ ] Verify push taps route to the correct session/chat and fail safely when content was deleted or access was revoked.
- [ ] Document deployment, migration, secret rotation, rollback, and incident-response procedures.
- [ ] Confirm production backups and restore expectations for user/session/report data.

**Done when:** Production services pass an end-to-end test using the candidate build, permissions are least-privilege, scheduled work is observable, and rollback/recovery procedures are documented.

**Preparation update (2026-09-30):**
`docs/operations/external-beta-operations.md` defines named ownership, moderator
provisioning, production RLS, email, push, deletion/retention, backup/restore,
rollback, and incident-response evidence. The checks remain open until executed
against production and recorded for the candidate build.

## EXT-06 — External-beta go/no-go checkpoint

**Dependencies:** EXT-01 through EXT-05 and all internal TestFlight gates.

- [ ] Repeat the full critical-path test on the exact external candidate build.
- [ ] Complete a two-account/two-device test for join/leave, chat, blocking, reporting, push notifications, token reassignment, and account deletion.
- [ ] Confirm accessibility checks on authenticated screens, not only Welcome.
- [ ] Confirm there are no open P0 defects and every accepted P1 defect has an owner and target build.
- [ ] Submit to Beta App Review and record the submitted build/configuration.
- [ ] After approval, release to a small cohort and monitor before expanding.

**Done when:** Beta App Review approves the build and the small external cohort has a monitored, supportable release with no unresolved P0 issue.

---



# Gate 3 — Beta fixes and hardening

These tasks should be prioritized from user feedback and production evidence. Finish **P1** items before a broad beta wherever practical; schedule **P2** work without destabilizing early builds.

## BETA-01 — Load the newest chat messages and paginate older history (**P1**)

**Original problem (fixed locally 2026-10-14):** The chat query ordered `created_at` ascending and applied `limit(50)`, which returned the oldest 50 messages rather than the newest 50.

**Evidence:** `ios/PickUpUCF/Repositories/ChatRepository.swift`

**Tasks:**

- [x] Query the newest page deterministically, then present it in chronological order.
- [x] Add cursor-based “load older messages” pagination.
- [x] Define stable ordering for identical timestamps, using a secondary unique key.
- [x] Preserve scroll position while prepending older messages (actual-button simulator regression).
- [x] Test conversations with 0, 1, 50, 51, and several hundred messages (synthetic HTTP tests, up to 301 messages).
- [x] Test pagination while realtime inserts arrive (request-boundary and view-model tests).

**Local implementation (2026-10-14):** The existing RLS-protected endpoint now queries descending `(created_at, id)` with one lookahead row, returns the newest 50 in chronological order, and retains the exact server timestamp for older-page cursors. Chat exposes loading/error/retry controls, retains loaded messages and the cursor after failure, filters blocked content, and deduplicates history/realtime/send results. An actual-button SwiftUI simulator test verifies reading-position restoration after a prepend. No migration or dependency upgrade is required for this chat change. Production/candidate verification remains separate; deployment is deferred. Focused plan: `docs/superpowers/plans/2026-10-14-local-beta-readiness.md`.

**Done when:** Opening chat shows the latest conversation, older history loads without duplicates/gaps/jumps, and tests cover more than 50 messages.

## BETA-02 — Make session creation atomic (**P1**)

**Problem:** Session creation inserts the session and host participant in separate operations. A failure between them can leave `player_count = 1` with no host participant row.

**Evidence:** `ios/PickUpUCF/Repositories/SessionRepository.swift`

**Tasks:**

- [x] Replace the client-side multi-step write with a transaction-backed RPC/database function.
- [x] Validate host identity and all creation invariants server-side.
- [x] Ensure the host participant row and count are created atomically.
- [x] Apply least-privilege execute grants to the function.
- [x] Add rollback/failure tests and duplicate-request/idempotency coverage.
- [x] Update client mapping for structured domain errors.

**Local implementation (2026-10-21):** Added `20261021155014_atomic_session_creation.sql`: an authenticated, least-privilege RPC creates the session, host membership, and private retry receipt in one transaction. The host comes from authoritative confirmed-UCF account data; server-side creation invariants and existing content/suspension rules are enforced. Receipts store a SHA-256 fingerprint, and concurrent matching retries return one game. The create form retains its request UUID across failures/edits, rejects conflicting committed requests, and never falls back to separate inserts. HTTP tests cover lost RPC/read responses and missing-RPC failure. SQL tests cover malformed input, unconfirmed/non-UCF/suspended accounts, rollback, matching/conflicting retries, mutable sessions, tombstones, and six concurrent requests. Focused evidence: `2026-10-21-atomic-session-creation.md`.

**Backend deployment (2026-10-21):** With owner approval, applied `20261021155014_atomic_session_creation.sql` to production. Verified recorded migration version, function signatures, execute grants, private-ledger RLS, API availability, and rolled-back synthetic authenticated creation/replay/conflict/validation/tombstone checks. The local filename matches the version assigned by Supabase; SQL content is unchanged from the reviewed migration. Existing released clients retain their legacy write behavior until replaced. Exact-candidate/offline/device checks and broader beta rollout gates remain open.

**Done when:** A session and its host membership either both exist correctly or neither exists, including on retry and simulated network failure.

## BETA-03 — Enforce server-side input and content limits (**P1**)

**Problem:** Chat currently enforces non-empty content but no practical maximum. Display names, session notes, custom sports, and custom locations also need aligned client/server bounds to prevent abuse, broken layouts, and oversized payloads.

**Tasks:**

- [x] Define normalized minimum/maximum lengths for chat messages, display names, session notes, custom sport names, and custom location names.
- [x] Decide whitespace, newline, emoji/grapheme, and Unicode normalization behavior.
- [x] Add database constraints or controlled RPC validation so crafted clients cannot bypass limits.
- [x] Mirror limits in the iOS UI with counters and accessible inline guidance.
- [x] Map rejected input to safe, specific errors.
- [x] Add boundary tests at below-minimum, exact-limit, over-limit, whitespace-only, multiline, and multi-byte Unicode inputs.
- [x] Coordinate limits with the UGC filter/moderation rules.

**Done when:** Client and server enforce the same documented rules and malicious/oversized input cannot enter the database.

**Local source evidence (2026-10-22):** Aligned NFC normalization, an explicit Unicode whitespace set, code-point limits (not grapheme clusters), raw C0/C1 rejection with TAB/LF/CR collapsing, required display/chat text, and optional blank-to-null behavior. Added accessible counters/guidance without truncating drafts across signup, chat, create/edit and custom-location inputs. The notes counter includes the stored Other-sport label. Existing UGC filters remain in place. New migration `20261022145737_input_content_boundaries.sql` and crafted-client SQL tests pass locally; deployment and exact-candidate device checks remain open. See the [October 22 plan](2026-10-22-input-boundaries-and-launch-gates.md).

## BETA-04 — Remove nested navigation and join/leave controls (**P1**)

**Problem:** A `NavigationLink` wraps a session card that contains Join/Leave buttons. Nested interactive controls can cause accidental navigation and ambiguous VoiceOver behavior, especially when card children are combined into one accessibility element.

**Tasks:**

- [x] Refactor the card so navigation and join/leave are separate, unambiguous actions.
- [x] Give each action a clear accessibility label, value, hint, and state.
- [x] Ensure joining/leaving cannot trigger navigation and vice versa.
- [ ] Verify keyboard/Switch Control/Voice Control behavior where applicable.
- [x] Add UI tests for tap targets and action routing.

**Local implementation (2026-10-21):** Discover/My Games now give the illustrated details an Open button and a separate participation button. Native rendered-control tests activate both independently and verify at least 44pt targets; normal/Accessibility XXXL renders were visually checked. Device keyboard, Switch Control, Voice Control, and full VoiceOver validation remain open. Focused plan: `2026-10-21-session-card-actions.md`.

**Done when:** Visual, touch, and assistive-technology users can independently open, join, or leave a session without accidental actions.

## BETA-05 — Request calendar write-only access (**P1**)

**Problem:** The app requests full calendar access even though it only creates events.

**Evidence:**

- `ios/PickUpUCF/Core/CalendarExportService.swift`
- `ios/project.yml`
- `ios/PickUpUCF/Info.plist`

**Tasks:**

- [x] On iOS 17+, request EventKit write-only access.
- [x] Add `NSCalendarsWriteOnlyAccessUsageDescription` with clear user-facing copy.
- [x] Remove full-access usage/configuration unless a documented feature truly needs calendar reads.
- [x] Revisit storage of event identifiers when read access is unavailable.
- [ ] Test first request, allow, deny, restricted, Settings recovery, duplicate export, and deleted calendar/event cases.
- [ ] Update the privacy policy and App Store privacy answers if the data flow changes.

**Local source update (2026-10-22):** See [focused implementation/device plan](2026-10-22-calendar-write-only.md). The adapter only creates/saves events and requests write-only permission. Prior exports are local receipts, not verified Calendar presence. Replacement requires duplicate confirmation; game edits/cancellation require managing the independent copy in Calendar. Denied access offers Settings; restrictions and missing destinations have separate guidance. The isolated simulator suite passed **255/255**, and the unsigned Release build/analyzer passed. Local privacy copy is updated; public-site/App Store review and actual iOS 17/current-iOS EventKit acceptance remain open.

**Done when:** Calendar export works with the minimum permission necessary and denial/recovery paths are clear.

## BETA-06 — Ask for notifications contextually (**P1**)

**Problem:** Notification permission is requested immediately after authenticated bootstrap, potentially before onboarding or before users understand its value.

**Tasks:**

- [x] Add an in-app explanation tied to a concrete reminder/chat benefit.
- [x] Trigger the system prompt only after an intentional user action or meaningful setup point.
- [x] Do not repeatedly nag users who decline.
- [x] Show the current authorization state and a Settings deep link when permission is denied.
- [ ] Keep token registration/unregistration correct across permission changes and account transitions.
- [ ] Measure prompt acceptance without collecting unnecessary personal data.

**Done when:** Users understand why notifications are useful before the system prompt, and every permission state has a coherent recovery path.

**Local source evidence (2026-10-22):** Removed the notification prompt from authenticated bootstrap. Notification Settings explains reminders/chat, requests permission only through Enable notifications, displays denied state and the system Settings link, and refreshes status on foreground. Authorization/ownership/quarantine tests pass locally. Physical allow/deny/Settings recovery and account-switch delivery remain open; no acceptance analytics or new SDK was added.

## BETA-07 — Replace sensitive custom-scheme links with Universal Links (**P1**)

**Problem:** Session sharing and password reset use `pickupucf://`. Custom schemes have no web fallback and are weaker for sensitive auth callbacks because another app can claim the same scheme.

**Tasks:**

- [x] Choose stable HTTPS routes for password reset and session sharing (local source uses the existing free Vercel host).
- [ ] Configure Associated Domains and host a valid `apple-app-site-association` file.
- [x] Configure Supabase/auth redirect allowlists for the HTTPS callback (hosted fields patched and re-read October 22).
- [x] Add a web fallback for recipients without the app (published October 22; accurately explains invitation-only TestFlight access while public App Store availability is pending).
- [ ] Keep the custom scheme only as a documented transition fallback if needed.
- [ ] Validate incoming paths, identifiers, authentication state, and authorization before navigation.
- [ ] Test installed/not-installed, signed-in/signed-out, expired reset, deleted session, revoked access, and malicious-link cases.

**Done when:** Auth and share links use verified HTTPS association, have a useful fallback, and reject malformed or unauthorized routing.

**Local follow-up (2026-10-22):** See [secure auth links](2026-10-22-secure-auth-links.md).
Prepared AASA, matching entitlements/XcodeGen, HTTPS routing/share/reset generation,
credential-free web fallbacks and strict PKCE callback boundaries. Repaired the
recovery hook's bare-redirect email defect and added new-password completion after
successful exchange. The previous signed archive confirms the association App ID.
Production AASA currently returns 404; Vercel publication, hosted auth allowlists,
email-function deployment, Associated Domains provisioning and exact device matrix
remain open. Sensitive custom-scheme callbacks are rejected locally; legacy session
notification links remain supported. No deployment or new archive/upload occurred.


## BETA-08 — Show the correct author for realtime chat inserts (**P1**)

**Problem:** Realtime messages are currently created with `author: nil`, so incoming messages may display the generic “Player” label until a reload.

**Evidence:** `ios/PickUpUCF/Features/Chat/ChatViewModel.swift`

**Tasks:**

- [x] Include safe author metadata in the realtime flow or resolve it from a bounded profile/roster cache.
- [x] Avoid an N+1 profile request for each incoming message.
- [x] Define behavior for deleted, blocked, or renamed users.
- [x] Keep profile visibility consistent with RLS/data-minimization rules.
- [x] Test simultaneous senders, cache misses, reconnect catch-up, edits to display name, and missing/deleted profile metadata with synthetic HTTP/state cases.

**Local implementation (2026-10-21):** Per-chat sender metadata is cached for 60 seconds with a 100-sender limit. Unknown senders are coalesced and resolved through session-scoped, RLS-protected message reads (at most 50 IDs/request) using the existing minimal author join. Missing metadata uses Player; blocking and lifecycle/revision checks prevent late reads restoring hidden names. Successful subscription/rejoin and foreground activation trigger catch-up to the last verified history boundary, retaining older history/cursors and handling multi-page gaps even when a newer realtime row is already present. Separate name/refresh errors have an accessible Retry action. Focused plan: `2026-10-21-realtime-chat-recovery.md`. Signed simulator tests cover state/HTTP behavior; real two-account WebSocket reconnect, foreground transport, and physical-device VoiceOver remain separate release checks.

**Done when:** New realtime messages immediately show the correct permitted author identity without excessive requests or privacy leakage.

## BETA-09 — Make account deletion and sign-out cleanup resilient (**P1**)

**Problem:** Database deletion followed by a failed auth sign-out can leave inconsistent local state. Token cleanup must also occur before the account disappears.

**Tasks:**

- [x] Define an explicit cleanup sequence for device token, Live Activities, local caches, widget/App Group state, realtime subscriptions, and auth state.
- [x] Unregister the APNs token before remote account deletion when possible.
- [x] Clear local authenticated state even if the final remote sign-out call fails.
- [x] Make retries safe and prevent deleted-account data from reappearing after relaunch. (local source/tests; device gate remains open)
- [x] Show clear progress, confirmation, failure, and irreversible-action copy. (local source/tests; device gate remains open)
- [ ] Test offline deletion, partial backend failure, token-unregister failure, relaunch, and a new user signing in on the same device.

**Done when:** After confirmed deletion, the device contains no usable prior-account session/data and a subsequent user cannot receive or see the deleted user’s information.

**Local source evidence (2026-10-22):** The owner chose retained games with an anonymized host. `20261022152043_anonymize_hosted_games_on_deletion.sql` cancels active hosted games, preserves game rows with null host references and other players' chat, removes the deleted account's ordinary messages/tokens/memberships/authored notification previews, reconciles counts/promotions, disables future recurrence, and makes retries idempotent. Attendance uses null-safe host authorization. Source UI shows Deleted host without a profile/block link; local privacy copy explains retained history and limited safety records. SQL tests prove forced-failure rollback and preserve other-user cancellation/activity cleanup. The account-before-session locks in `20261022155106_serialize_account_mutations_with_deletion.sql` prevent new joins/creation racing past deletion cleanup.

Account changes clear navigation, create prefills, banners and account-linked defaults/calendar identifiers; APNs quarantine remains available for recovery. A missing session at launch clears local references/notifications and quarantines the retained token. Real-Keychain synthetic tests cover deleted-account relaunch, offline restore and remote logout failure. Chat recovery revalidates older loaded rows so deleted messages disappear on successful refresh; failures retain history for retry. Exported calendar events are not removed by local identifier cleanup, and immediate deletion propagation to another open device is not claimed. **Production schema deployed October 22:** the nullable-host SET NULL FK and deletion functions are now applied and metadata-verified. Exact-candidate two-account/device deletion, offline/relaunch and notification isolation remain open.

## BETA-10 — Add privacy-safe observability (**P1**)

**Problem:** TestFlight crash feedback alone is not enough to diagnose backend, notification, realtime, and account-transition failures.

**Tasks:**

- [ ] Select a crash/error reporting approach and document its privacy implications.
- [ ] Add structured diagnostics for auth, session mutations, chat pagination/realtime, notification registration/delivery, deep links, and account deletion.
- [ ] Redact emails, auth credentials, APNs tokens, message bodies, precise locations, and other PII.
- [ ] Attach build/environment identifiers and safe correlation IDs.
- [ ] Define beta health signals: crash-free sessions, launch failures, auth failures, RPC errors, notification failures, and latency.
- [ ] Configure alert ownership and a triage workflow for P0/P1 beta issues.
- [x] Verify debug logging is not accidentally shipped at an unsafe verbosity (raw SDK payload logging removed in both configurations on October 22).

**Local evidence (October 24):** the first focused slice adds closed-schema local
Apple unified logs for session create RPC, post-create read, update/cancel/join/
leave. Attempts use ephemeral local correlation IDs; raw errors, server codes,
identities and content are excluded. Signed isolated simulator suite passes
270/270 on the established iPhone16e lane. See
[scope, privacy, environment prerequisite and evidence](2026-10-24-session-diagnostics.md).
This covers only session backend boundaries and local diagnostic collection;
the broad structured-diagnostics task and other BETA-10 gates remain open.

**Additional local evidence (October 24):** explicit auth operations now emit
closed local auth_operation records; change-password reauthentication/write share
an ephemeral attempt ID, while retries get fresh IDs. No credentials, identities,
URLs or raw SDK errors are serialized. Focused16/16/full signed isolated289/289,
unsigned Release simulator build/analyzer and independent review pass. See
[scope and evidence](2026-10-24-auth-diagnostics.md). Other flows, centralized reporting/metrics/alert ownership remain open.

**Additional local evidence (October25):** chat repository first/older pages,
send and targeted updates now emit closed local chat_operation JSON. Requests,
exact cursors, normalization/results/errors remain; no content, identity, raw
error or cursor enters records. Focused15/15, full signed isolated300/300 and
unsigned Release simulator build/analyzer pass; independent reviews have no
required findings. See [scope and evidence](2026-10-25-chat-diagnostics.md).
This does not establish realtime subscription/delivery or full refresh health;
remaining flows/reporting/metrics/alerts keep BETA-10 open.

**Additional local evidence (October25):** currentSession restoration now emits
one finite decision after original guards/cleanup: SDK session_missing (cause
unknown), unavailable, verified, rejected cached/remote, invalidated, superseded
(including SDK-cleared cache), or cached fallback. No false succeeded result;
requests, policy, cleanup and error suppression remain. Focused28/28 before final
additions and final full signed isolated311/311, unsigned Release build/analyzer
and independent final review pass. Actual logs retain the closed privacy schema.
See [scope and evidence](2026-10-25-restoration-diagnostics.md). Other critical
flows and reporting/metrics/alert ownership keep BETA-10 partial.

**Additional local evidence (October25 evening):** Live Activity token
registration now emits an allowlisted register_live_activity_rpc operation in the
existing device-token category. Exact RPC/params/errors remain, with no fallback,
retry or ActivityKit changes. Focused32/32/full signed isolated340/340, Release
build/analyzer, actual Logger schema/privacy checks and independent review pass.
See [scope and evidence](2026-10-25-live-activity-token-diagnostics.md).
This confirms only the backend stage, not physical ActivityKit/APNs lifecycle;
broader diagnostic/reporting/alert gates remain open.

**Additional local evidence (October25 evening):** account-transition push token
cleanup emits one finite completion decision: no stored token, first return,
return after retry, or recovery required. Original ordering, captured token,
bounded retry and second-error identity preserved; gated queue/activity/timing
and cancellation coverage. Focused44/44, final signed isolated347/347, Release
build/analyzer, actual Logger schema/privacy and fresh reviews pass. See
[scope/evidence](2026-10-25-push-cleanup-diagnostics.md). Other service decisions,
whole-account/device/provider health and reporting/metrics/alerts remain open.

**Additional local evidence (October25 evening):** account-deletion RPC now emits
closed auth_operation delete_own_account_rpc records with existing success/error
semantics. Exact no-body RPC, Void/errors preserved; PostgrestError is backend.
Focused38/38, final signed isolated351/351, unsigned Release build/analyzer,
actual Logger privacy/schema and fresh reviews pass. See
[scope/evidence](2026-10-25-account-deletion-diagnostics.md). No real account was
deleted; whole transition/data-retention/device/provider and reporting gates remain.

**Done when:** The team can diagnose critical beta failures from privacy-safe evidence without asking testers to reproduce everything manually.

October25 local device-token diagnostic slice: register/unregister RPCs and the
PGRST202-only owner-filtered delete emit separate closed backend-stage records.
No token/identity/error inputs logged; original calls/filters/errors and service
rotation/retry/quarantine/account-transition behavior retained. Real-SDK red proof,
focused33/33 and final full signed isolated322/322; Release build/analyzer,
fresh-context final review and actual Logger schema/privacy check pass. See
[contract/evidence](2026-10-25-device-token-diagnostics.md). Success means only a
backend stage returned, not delivery or affected rows. Service decisions, realtime
health, reporting/metrics/alerts and physical/provider acceptance remain open.

October25 local realtime subscription slice: actual ChatViewModel lifecycle emits
closed realtime_operation observations for subscription return/failure/caller
cancellation/supersession and finite active-lifecycle channel status. SDK-thrown
cancellation alone does not imply caller cancellation; stale lifecycle wins.
Original guards/stream/refresh/error/unsubscribe order retained. New real-SDK
loopback-only websocket harness proves synthetic success, rejection, timeout,
server close, caller cancellation, stop, retry and combined precedence. Focused34/34
and final signed isolated333/333 (11 new), Release build/analyzer, actual Logger
schema/privacy checks and fresh-context review pass. See
[scope and evidence](2026-10-25-realtime-diagnostics.md). A returned subscription or
subscribed observation does not prove delivery/caught-up history; full health,
reporting/metrics/alerts and other critical flows remain open.

## BETA-11 — Add an XCUITest smoke suite (**P1**)

**Problem:** Unit coverage is strong, but there is no automated UI suite covering the release-critical user journey.

**Tasks:**

- [x] Create deterministic test accounts/data or a dedicated test backend strategy (bounded synthetic read-only UI transport; broader workflows remain open).
- [ ] Cover launch, authentication, onboarding, Discover, create, join, leave, chat, profile, block/report, sign-out, and account deletion.
- [ ] Add accessibility identifiers without exposing implementation details to users.
- [ ] Cover permission alerts and denial paths using controllable test state.
- [x] Add at least one largest-Dynamic-Type smoke path.
- [x] Run the suite in CI or as a documented release-gate command.

**October 24 partial evidence:** First Debug simulator XCUITest lane passes 4/4
with backend URL/key absent. A single UI flag selects the synthetic HTTP-denying
client, no persistent auth storage, and skips restore/lifecycle/push side effects.
The runner rejects unsupported builds before launch and verifies its isolation
marker before actions. Actual Welcome intro/relaunch, account route replacement/
email carry, blank sign-in validation and accessibility5 navigation are covered;
retained screenshots inspected. See [scope, local gate and evidence](2026-10-24-ui-smoke.md).
Authenticated workflows, controllable permission paths, CI and physical acceptance
remain open. This does not close BETA-11.

**Follow-up local evidence (October 24):** full isolated UI gate now passes6/6,
adding blank sign-up and password-reset blank/non-school-email validation and
return to original sign-in. Backend URL/key remain absent; new screenshots
inspected. Test-only increment; authenticated flows/permissions/CI/device gates
remain open. See the same [UI plan](2026-10-24-ui-smoke.md).

**October25 bounded authenticated evidence:** isolated UI gate7/7 adds real
Discover/My Games upcoming/history/Profile reads and authenticated relaunch using
a synthetic SDK session and in-memory HTTP fixture allowlist. No backend
credentials; mutation/auth/unknown HTTP denied. My Games ActivityKit refresh is
suppressed in UI mode. Signed isolated units336/336 and unsigned Release
build/analyzer pass; screenshots and final fresh-context review verified. This
covers synthetic tab navigation, not provider sign-in, authenticated mutation,
permissions, CI or physical acceptance. See [contract/evidence](2026-10-25-authenticated-ui-smoke.md).

**Done when:** A repeatable automated smoke suite catches broken critical navigation and workflows before a build is uploaded.

## BETA-12 — Match the launch screen to the app experience (**P2**)

**Problem:** `UILaunchScreen` is empty, which can produce a white flash before the forced-dark Welcome screen.

**Evidence:**

- `ios/project.yml`
- `ios/PickUpUCF/Info.plist`

**Tasks:**

- [ ] Add a simple static launch background that matches the initial app surface in light/dark appearance.
- [ ] Avoid text, loading indicators, or marketing content that can become stale.
- [ ] Verify cold launch, warm launch, dark/light mode, and multiple device sizes.

**Done when:** Cold launch transitions cleanly into the first app screen without a distracting flash or misleading content.

## BETA-13 — Harden RLS, RPC grants, and server-owned invariants (**P1**)

**Problem:** Crafted clients must not be able to bypass client validation, manipulate server-owned counts/status, access more profile/roster data than needed, or execute `SECURITY DEFINER` functions through default/public grants.

**Tasks:**

- [x] Complete the local source/Data API table-policy threat model (18 application/private tables inventoried October 23; intentional exceptions documented; exact production role/API acceptance remains open).
- [x] Revoke default/public execute rights and grant each function only to required roles (deployed October 22; metadata rechecked October 23).
- [ ] Move player counts, host membership, capacity enforcement, status transitions, and other invariants behind transactional server logic.
- [x] Review profile, participant, roster, report, and blocked-user client reads (October 23 source audit; reproduced participant/helper leaks fixed locally; optional timestamp minimization deferred).
- [x] Verify anonymous users cannot call authenticated mutation functions (local SQL and October 23 production execute-permission metadata).
- [ ] Add SQL tests for cross-user access, crafted updates, blocked users, deleted users, and role escalation.
- [ ] Document intentional exceptions and the threat model.

**Done when:** The SQL security suite proves least-privilege access and clients cannot directly corrupt server-owned state.

**Partial local evidence (2026-10-22):** `20261022150215_restrict_application_rpc_grants.sql` revokes direct PUBLIC/anon/authenticated execution, restores only client/RLS-helper grants, closes maintenance/enqueue/recurrence functions, pins three advisor-reported search paths, and restricts direct profile/session/member mutations. Atomic creation and join/leave own membership/count changes; clients cannot write counts/statistics or insert memberships. SQL verifies ordinary-user denial plus allowed profile upsert/edit and host notes edit. **Read-only production audit confirms exposed enqueue/global maintenance grants.** This is a release blocker until the reviewed migration is deployed with a compatible candidate; legacy direct-insert clients must be retired/coordinated. Current-account school-data checks reject stale deleted-account email claims. The roster visibility migration shares a private access gate with session RLS, filters blocked identities and preserves true waitlist position/counts. `20261022154815_enforce_host_status_transitions.sql` denies crafted completion/reopening/closed-content edits and reconciles open/full after capacity changes. Full numeric/edit/read-minimization audit and exact production role-matrix verification remain open.

**Additional local evidence (2026-10-23):** Host numeric/schedule/pin edits are
protected in pending migration `20261023215028`; iOS edit payload regressions are
fixed in source `96b1278` (explicit nulls and normalized custom sport name).
Pending `20261023221000` closes direct participant reads of inaccessible history
and other waitlist identities. Pending `20261023222000` scopes public policy-helper
RPCs to the caller while preserving trusted internal checks. Full SQL/RLS now
passes 34 phase notices inside rollback; isolated concurrency passes four ordered
races, twelve cancellation/join races and six waitlist retries. Signed isolated
iOS tests pass 267/267, with unsigned Release build/analyzer passing. Read audit,
intentional identity/aggregate exceptions and limitations are documented in
[participant minimization](2026-10-23-participant-read-minimization.md) and
[helper scope](2026-10-23-policy-helper-reads.md). Verify production keeps
`pickup_private` out of API exposed schemas before any deployment. These fixes
are not deployed and the iOS fix is not in TestFlight build 5. BETA-13 remains open
for full table/role-matrix and compatible-candidate production/device acceptance.

**Further source audit (2026-10-23):** The [18-table/API threat model](2026-10-23-table-policy-audit.md)
records intentional exceptions and four more reproduced local fixes: current
account authorization for moderation reports, positive session visibility for
chat reads/inserts, server-owned message ID/timestamp columns, and own-only
attendance ledger reads preserving profile history. Migrations `20261023223500`
through `20261023230500` are undeployed. Complete candidate SQL/RLS passes **38
phase notices** inside rollback. Exact production/API role verification and
compatible-candidate/two-account/device acceptance remain open.

## BETA-14 — Test join/leave concurrency and idempotency (**P1**)

**Tasks:**

- [x] Review join and leave functions for consistent row locking and transaction boundaries (local fix).
- [ ] Guarantee capacity cannot be exceeded under concurrent joins.
- [ ] Guarantee counts cannot go negative or drift from participant rows.
- [ ] Make repeated join/leave requests idempotent or return stable domain errors.
- [ ] Add concurrent SQL tests for final-slot joins, simultaneous leave/join, retries, cancellation, and host actions.
- [ ] Add a reconciliation query/job only if invariants cannot be guaranteed transactionally.

**Done when:** Concurrency tests preserve capacity, membership, and count invariants under retries and simultaneous requests.

**Partial local evidence (2026-10-22):** Reproduced duplicate leave producing `player_count=0` with one joined host. `20261022150858_serialize_session_leave.sql` takes the same session lock as join before reading membership, rejects host leave, skips blocked/suspended waitlist candidates, and honors promotion notification preferences. The local concurrency harness passes duplicate leave, competing final-slot joins and mixed join/leave; serial SQL covers host denial/idempotent leave. Harness fixtures and original function are restored in `finally`. Account-deletion count reconciliation and a simultaneous join against a locked/deleting account also pass locally. Atomic creation now takes the same account lock. Broader host/cancellation stress and production/device gates remain open.

## BETA-15 — Break up oversized feature files after release blockers (**P2**)

**Observed hotspots:**

- `SessionDetailView.swift` — approximately 763 lines
- `SessionRepository.swift` — approximately 514 lines
- `DiscoverViewModel.swift` — approximately 491 lines
- `CreateSessionViewModel.swift` — approximately 460 lines
- `DiscoverView.swift` — approximately 449 lines
- `DiscoverMapView.swift` — approximately 421 lines

**Tasks:**

- [ ] Re-measure hotspots after P0/P1 fixes land.
- [ ] Extract cohesive view components, domain operations, validators, and mappers—not arbitrary line-count fragments.
- [ ] Preserve public behavior with characterization tests before moving code.
- [ ] Keep each refactor reviewable and separate from unrelated feature behavior.
- [ ] Stop when boundaries are clearer; do not chase a line-count target.

**Done when:** High-change areas have focused responsibilities and can be tested/reviewed independently without a risky release-sized rewrite.

## BETA-16 — Automate version/build provenance (**P2**)

**Tasks:**

- [ ] Ensure every upload gets a unique monotonically increasing build number.
- [ ] Decide whether marketing version remains manually controlled while build number is automated.
- [ ] Surface build/version/environment in an internal diagnostics or settings view.
- [ ] Associate each TestFlight build with a commit SHA and migration/configuration record.
- [ ] Add a release check that rejects duplicate or stale build numbers.

**Done when:** Every tester report can be tied unambiguously to source, backend state, and build metadata.

## BETA-17 — Audit dependency and supply-chain updates (**P2**)

**Context:** The resolved Supabase Swift dependency was newer than the minimum declared in project configuration during the audit.

**Tasks:**

- [ ] Confirm the checked-in resolved versions are intentional and reproducible in CI/archive builds.
- [ ] Review release notes and migration guidance before dependency updates.
- [ ] Add dependency changes to the normal code-review/test process.
- [ ] Remove unused dependencies and verify privacy manifests/signatures for included SDKs.
- [ ] Schedule routine vulnerability and license review.

**Done when:** Release builds resolve deterministically and dependency upgrades are deliberate, reviewed, and tested.

## BETA-18 — Operate a staged beta rollout (**P1**)

**Tasks:**

- [ ] Start with internal testers, then a small external cohort, then expand in measured groups.
- [ ] Define P0/P1 severity, response owner, and stop-ship criteria.
- [ ] Monitor the first hour/day after each release for crashes, auth failures, backend errors, moderation reports, and notification problems.
- [ ] Keep a rollback option: expire/remove the affected build, disable unsafe backend behavior, or deploy a compatible server-side fix.
- [ ] Maintain concise known issues and “What to Test” notes per build.
- [ ] Review feedback after each cohort before widening access.

**Done when:** Each expansion is an explicit go/no-go decision based on observed stability and support capacity.

---



# Recommended implementation-plan sequence

Create these focused plans one at a time. Each plan should use small, verifiable tasks and update this checklist when complete.

1. **Packaging, signing, app icon, privacy manifest** — TF-01, TF-02
2. **APNs token ownership and account cleanup** — TF-03, BETA-09
3. **Error mapping and server-side input boundaries** — TF-04, BETA-03
4. **Dynamic Type and accessibility pass** — TF-05, BETA-04
5. **Internal archive and physical-device test gate** — TF-06
6. **UGC moderation, blocking, policies, and support** — EXT-01, EXT-02
7. **Reviewer access, TestFlight metadata, and production services** — EXT-03 through EXT-06
8. **Session/chat correctness** — BETA-01, BETA-02, BETA-08, BETA-14
9. **Least-privilege permissions and secure links** — BETA-05, BETA-06, BETA-07, BETA-13
10. **Observability, UI automation, and staged rollout** — BETA-10, BETA-11, BETA-18
11. **Post-blocker polish and maintenance** — BETA-12, BETA-15, BETA-16, BETA-17

---



# Project-wide definition of done

Every implementation plan and task is complete only when applicable items below are satisfied.

- [ ] Acceptance criteria are demonstrated, not inferred.
- [ ] Unit, integration, SQL/RLS, Edge Function, and UI tests relevant to the change pass.
- [ ] Release build and static analysis pass.
- [ ] Error, offline, retry, cancellation, and account-transition paths are tested.
- [ ] Accessibility works at the largest Dynamic Type sizes and with VoiceOver.
- [ ] Security/privacy review covers authorization, data minimization, secrets, logs, and untrusted input.
- [ ] Migrations are forward-safe and have a documented rollback/mitigation path.
- [ ] Production configuration and third-party service behavior are verified on the exact candidate build.
- [ ] User-facing copy, privacy disclosures, reviewer notes, and support docs are updated when behavior changes.
- [ ] No unrelated refactor or unreviewed dependency change is bundled into a release-critical fix.
- [ ] This checklist and the relevant focused plan are updated with evidence and the completed build number.

---



# Reference links

- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple — TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [Apple — Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [Apple — Configuring your app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon/)
- [Apple — Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple — Describing use of required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple — Accessing the calendar with EventKit](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui)


## Notification and Live Activity follow-up — 2026-10-05

Physical-device testing reported a Tennis Live Activity appearing after joining a
session approximately 19 hours away. The supplied Dynamic Island screenshot also
showed a crowded sport/location/countdown layout. This reopens the earlier general
physical-device sign-off for these specific behaviors.

- [x] Reproduced the early-start bug with an iOS regression test: the previous
  eligibility window was 24 hours. Cancelled/completed sessions were also eligible.
- [x] Limited eligibility to the final hour before start and the active session;
  cancelled/completed sessions are excluded. Previously started early activities
  are dismissed when the app becomes active.
- [x] Refresh confirmed-player/host eligibility on foreground activation and session
  detail load, including opening a reminder. My Games excludes waitlisted players
  from Live Activity selection. Reloading the same activity updates it in place.
- [x] Changed the expanded Dynamic Island layout to place sport/location below the
  glyph and timer. Reserved timer width, used a minutes/seconds countdown, added
  single-line scaling, and allowed two location lines on expanded/Lock Screen views.
- [x] Added migration `20261005140000_quiet_session_reminders.sql`: retain one
  reminder approximately one hour before start (five-minute cron cadence), remove
  the 15-minute job and unsent 15-minute reminders, exclude waitlisted players, and
  avoid sending both player and host reminders to the host. Existing preferences
  and reminder deduplication remain enforced. Updated settings wording.
- [x] Verified the failure before the fix: 19-hour and one-hour boundary eligibility
  tests failed; SQL reproduced three reminders for one host and one player.
- [x] Verified the fix locally: **181/181 iOS tests**, widget compilation,
  **19/19 send-push Deno tests**, and the complete `supabase/tests/run_all.sql`
  suite passed against local Supabase with the new migration applied. SQL covers repeated cron calls,
  host roster membership, waitlist exclusion, and disabled 15-minute reminders.
- [ ] Apply the new migration to production and distribute an updated iOS build.
- [ ] Repeat physical-device testing: join a game 19 hours away (no activity), open
  the app/reminder during the final hour, check compact/expanded/Lock Screen layouts
  with long sport/location names and larger text, cross the session start/end
  boundaries, leave/cancel, and confirm one
  reminder with preferences enabled and none with preferences disabled.

**Remaining limitation:** Live Activities start from foreground app activity.
There is no push-to-start or future-start scheduling in this implementation, so
an activity is not guaranteed to appear automatically at the one-hour mark while
the app stays closed. The server reminder is independent of that limitation.
The revised visual layout is compiled but still requires device visual confirmation.


### Full lifecycle and time audit — 2026-10-05

Follow-up request: completely remove finished-session notifications/activities and
verify that displayed times reflect the actual session schedule.

Additional findings and fixes:

- [x] Reproduced a multi-device bug: the `(user_id, session_id)` token key allowed
  the second device to replace the first device's activity token. Migration
  `20261005150000_live_activity_lifecycle.sql` now retains each activity token.
- [x] Added silent ActivityKit updates at session start and after schedule changes.
  End events retain a past `dismissal-date` for immediate system dismissal. Due
  activities are processed before ordinary alerts; individual delivery failures
  remain retryable without blocking other devices. A schedule changed during a
  request is not acknowledged using an outdated database version.
- [x] Server registration requires a confirmed player/host in the final-hour
  window. Leaving, cancellation, completion, or moving outside the final hour
  makes existing tokens due to end. Later edits cannot revive those tokens.
  The migration also ends activities created under the old early/waitlist policy.
- [x] Serialized local ActivityKit mutations to avoid overlapping requests and
  cleanup. Token network registration does not block local dismissal. Opening
  a later game's details preserves an earlier current activity; immutable sport
  and location changes replace the activity rather than keep old attributes.
- [x] Added delivered Notification Center cleanup using canonical session end
  timestamps, silent `session_finished` pushes, and foreground cleanup. Existing
  delivered alerts can resolve their session from the server. Foreground activity
  cleanup wakes at the activity's end; ordinary alert expiry is checked at most
  every 30 seconds. Leaving also clears local session alerts and queued reminders.
- [x] Added timestamps to notification payloads and backfilled pending payloads.
  Reminder APNs requests expire at session start, and the dispatcher suppresses
  expired or far-future reminders rather than delivering stale countdown alerts.
- [x] Timestamp verification: Swift JSONEncoder content dates match the server's
  Apple-reference-date conversion, including fractional seconds. Equivalent UTC
  and timezone-offset dates match, including a daylight-saving boundary.
- [x] Local validation: **185/185 iOS tests**, including a real simulator
  ActivityKit request followed by end-time cleanup and immediate dismissal;
  **26/26 send-push Deno tests**; the complete SQL suite after a clean local
  migration reset. SQL covers multiple devices, departed-player rejection,
  queued reminder cleanup, rescheduling, terminal cleanup, and deduplication.
- [ ] Deploy both notification migrations, then the updated `send-push` function,
  then the updated iOS build. Verify the production minute-based dispatch/cleanup
  jobs and APNs configuration.
- [ ] Repeat on physical devices with the app backgrounded/closed: actual start
  transition, schedule edits, cancellation, leaving on another device, natural
  end, manual completion, and no residual Lock Screen/Notification Center entry.
  Include network interruption/recovery and notification preference checks.

**Delivery limits:** ActivityKit `staleDate` marks content stale; it does not end
an activity. When the app is foregrounded it explicitly ends expired activities.
When the app is closed the server requests immediate dismissal on its next
minute-based dispatch. APNs delivery and silent background execution can be
late or unavailable, especially offline; exact closed-app removal at the end
second cannot be guaranteed. The simulator verifies local ActivityKit dismissal,
not production APNs delivery. Automatic closed-app starts still require a
separate push-to-start/future-start implementation.

## Player count clarity — 2026-10-06

- [x] Replaced capacity dots with a static people icon and explicit `X/Y players`
  text everywhere the shared indicator appears: session cards, hero, and roster.
- [x] Debug simulator build passed; visually verified cards/hero/roster at normal
  size and the roster at Accessibility XXXL. The accessibility tree exposes a
  single descriptive player-count label.
- [ ] Verify the revised player counts on the next physical-device candidate build.

Focused plan: `docs/superpowers/plans/2026-10-06-player-count-clarity.md`.

## Clickable profile statistics — 2026-10-07

- [x] Games and Streak open host-confirmed attendance history with session links.
- [x] Sports retains the preferred-sports count and opens the existing sports editor.
- [x] Five history tests pass; authenticated simulator navigation verified.
- [ ] Candidate-device check of all three links and largest-text history rows.
- [x] ActivityKit runtime dismissal test now waits for the asynchronous system
  state update; the complete 190-test iOS suite passed on 2026-10-07.

Focused plan: `docs/superpowers/plans/2026-10-07-profile-stat-history.md`.

## Notification pre-push verification — 2026-10-07

- [x] Reviewed the pending iOS/widget, push function, and notification migrations.
- [x] Fixed the runtime test race by awaiting ActivityKit's state update, with a
  bounded two-second timeout, before asserting dismissal. No dismissal behavior
  was relaxed in production.
- [x] Full iOS suite: 190/190 passed. Push-function suite: 26/26 passed.
- [x] Unsigned Release device build and Xcode static analysis passed.
- [x] Complete SQL/RLS suite passed against local Supabase with both migrations
  present; test mutations were rolled back.
- [ ] Production migration/function deployment and physical-device checks remain
  required before distributing the updated iOS candidate.

## Local readiness and chat follow-up — 2026-10-14

- [x] Reconciled EXT-01's implemented source/local-test tasks with the separate production, candidate-device, backup-coverage, and age-rating gates. Corrected stale moderator-deployment and reviewer sign-in notes without re-auditing production.
- [x] Completed BETA-01 locally: newest-message queries, exact-timestamp keyset pagination, retry states, block filtering, chronological deduplication, and actual-button reading-position restoration.
- [x] Final verification: **202/202 iOS tests**, **36/36 Deno tests**, full local SQL/RLS suite with **24 phase success notices** inside explicit rollback, unsigned Release device build, static analyzer, and `git diff --check` passed. Local database head was `20261005150000`; no clean reset or venue migration was performed in this audit.
- [x] Visually inspected synthetic chat at normal and Accessibility XXXL sizes on iPhone 16e / iOS 26.3; screenshots and scroll metrics are in ignored `docs/testflight-evidence/beta-01/`. Device and VoiceOver checks remain separate.
- [x] Updated reviewer chat instructions and documented foreground-only Live Activity starts and APNs-dependent closed-app cleanup.
- [ ] Deployment, new candidate distribution, production evidence, physical-device verification, and external submission remain deferred/open. No commit, push, deployment, upload, or submission was performed.

Focused plan and detailed evidence: `docs/superpowers/plans/2026-10-14-local-beta-readiness.md`. The next source workstream is **BETA-02 — Make session creation atomic**; BETA-08's realtime recovery work remains separate.


## UI, UX, and atomic creation follow-up — 2026-10-21

- [x] Applied the shared visual system across screens and retained the original logo in welcome/account/onboarding headers.
- [x] Added direct account-form switching without stacked forms, email handoff into recovery, clear recovery/back actions, readable prompts, and loading locks.
- [x] Added sticky sport-selection actions, onboarding account escape, empty-state discovery actions, filter reset, profile retry, and venue failure/custom-location recovery.
- [x] Completed BETA-02 in local source and SQL: atomic creation, authoritative host validation, private fingerprint receipts, rollback and concurrent retry coverage.
- [x] Completed BETA-04 source/action tests and normal/largest-text visual inspection; assistive-technology candidate checks remain open.
- [x] Final verification: **217/217 iOS tests**, **36/36 Deno tests**, complete local SQL/RLS suite (**25 phase notices**), six concurrent duplicate requests, schema lint, unchanged security-advisor baseline, unsigned Release build, static analysis, and `git diff --check` passed. No local database reset was performed; trial schema/fixtures were removed afterward.
- [x] Applied the atomic-creation migration to production with owner approval; verified API availability, authorization, and rolled-back authenticated creation/retry invariants.
- [ ] Verify exact-candidate authenticated/offline creation/retry and accessibility on physical devices.
- [ ] Other open source/production/operations gates in this checklist, including BETA-08 realtime author/catch-up work, remain separate.

Detailed UX audit: `docs/design/2026-10-21-ux-audit.md`. Production atomic-creation deployment was subsequently approved and applied at 15:50 UTC. No commit, push, archive upload, or external submission was performed.

## Launch-critical follow-up — 2026-10-22

- Preserved and reviewed the uncommitted BETA-08 source; no new blocker found in its ordering, authorization, bounded identity lookup, pagination and lifecycle guards. Live two-account/device checks remain separate.
- Local implementation and validation details: [input boundaries and launch gates](2026-10-22-input-boundaries-and-launch-gates.md).
- Read-only production migration history confirms atomic creation and the venue correction are recorded, while `20261005140000` and `20261005150000` remain absent. The old 15-minute reminder cron is still active. No migration/function deployment was performed; see the test-host bootstrap exception below.
- Do not publish until exposed production RPCs, pending notification migration/function parity, hosted-account deletion, exact-candidate device/accessibility checks and the remaining EXT gates are resolved. Optional polish stays deferred.

### October 22 test-host bootstrap exception

Earlier unit-test hosts executed the existing startup path against production. Request-ID-paired SDK diagnostics confirm existing-profile upserts and device-token registration refreshes, plus auth-session refreshes. These requests involved one profile and one stored APNs token; read-only verification confirms that token currently belongs to that profile. Previous field values/ownership were not captured, so they cannot be reconstructed or safely restored. No migration, account deletion or session-content mutation was issued. This is an unintended production side effect, not device/integration validation.

The Test action now sets `PICKUP_UNIT_TESTS=1`; the app skips live bootstrap and the shared client uses a synthetic host with HTTP rejected by URLProtocol. A regression verifies the flag and actual HTTP denial. Explicit repository tests keep their synthetic transports and real Keychain coverage. SDK payload logging was removed, earlier owned text logs were redacted, and result bundles containing earlier diagnostics were restricted to the current user. The final isolated suite passed **248/248**, and the Edge suite passed **36/36**. Local SQL/RLS and concurrency checks passed; full evidence and remaining gates are in the October 22 plan.


## Authorized production rollout — October 22

[Rollout evidence](../../operations/2026-10-22-production-rollout.md) supersedes the
earlier undeployed/publication-blocked statements above. Source `b8349d2` is pushed
to main. All ten pending migrations are applied; internal enqueue execution/direct
membership writes are closed, null-host retention is enabled, and the scheduled
cleanup preflight defect is fixed. send-auth-email v23 and send-push v18 are ACTIVE
with exact source parity. Vercel privacy/AASA/fallback pages are published; origin
and Apple CDN association JSON match, and hosted auth now uses exact HTTPS routes.
The new cleanup cron has succeeded; the 15-minute reminder cron is removed.

Prior validation remains 261/261 isolated simulator tests, 39/39 Edge Function tests,
Release build/analyzer plus the newly rerun local SQL/RLS regression suite. This is
not a new iOS candidate or proof of live user/device/provider acceptance. Existing
old TestFlight direct-write/custom-auth-link clients must be replaced; signed
Associated Domains provisioning, unique candidate build/archive/distribution,
physical-device acceptance and Beta App Review remain open. Restricted logical
recovery material was captured; a restore exercise and complete operational
recovery readiness remain open. No paid service, iOS upload or invitation occurred.


## October 22 — Build 5 packaging

Version 1.0 (5), source `53ac5c7`, has a successful signed Release archive and
local App Store distribution export. Strict app/widget signature checks passed;
the exported app has production APNs, the expected App ID and Associated Domains,
and App Store profiles with debugging disabled. This supersedes the earlier
build-number/archive/provisioning preparation gap. See
[build 5 record](../../testflight/2026-10-22-build-5.md). No upload or Apple server
validation/processing occurred. Device/provider acceptance and release gates remain
open; historical owner attestation does not establish this candidate's acceptance.


## October 22 — Build 5 internal distribution

The owner approved upload. Xcode upload succeeded at 2:48 PM America/New_York.
App Store Connect independently confirms build 1.0 (5) processing Complete,
export compliance saved, and Testing status in the existing Internal Testers group
(one existing tester). Candidate-specific What to Test is saved. Build ID:
`1d97439c-57b6-487f-841b-f75ee1c371f2`. This supersedes the prior no-upload status.
See the build 5 record for encryption evidence. No Beta App Review submission,
new tester invitation or physical/provider acceptance was performed.

## October 23 — Installation metadata and scoped restore exercise

The connected iPhone 17 / iOS 27.0.1 reports installed version 1.0 (5), marked
as a developer app by CoreDevice. TestFlight origin and exact binary provenance
remain unconfirmed; no hands-on acceptance was performed. Both device lanes and
provider/two-account checks remain open. See the build 5 record.

The actual October 22 pre-rollout logical snapshot was restored in a fresh,
network-disabled, tmpfs-only PostgreSQL container. All 38 imported table-count
checks and 44 foreign-key checks passed, along with sequence and RLS-enabled
checks. Six incompatible empty auth COPY blocks were explicitly excluded; all
populated blocks were restored. The container was removed after validation.
This advances the logical restore exercise only. Managed auth schema, platform
configuration/secrets/storage, forward migrations and operational recovery
readiness remain open. See [restore evidence and replay procedure](../../operations/2026-10-23-isolated-restore.md).

The owner subsequently confirmed build 5 was installed through TestFlight and
the phone is available for hands-on checks. Installation origin is now
owner-attested. iPhone Mirroring reports Mac Bluetooth off and cannot connect;
no functional acceptance row has passed from this attempt. Enable Bluetooth and
connect mirroring to continue with authenticated launch/relaunch and controlled
account checks.

**Later October 23 device evidence (approximately 5:27–5:30 PM):** Mirroring
connected after the owner resolved its prerequisites. On the physical iPhone 17,
build 5 reached Discover/Profile, restored the same reviewer session after
app-switcher dismissal and reopening, and opened the expected Privacy Policy and
Terms pages from Settings. My Games history expanded to four entries; no upcoming
games were visible. See the build 5 record for exact scope and screenshot location.
Fresh/provider sign-in, offline/revoked-session behavior, Calendar, APNs,
two-account chat/deletion and accessibility remain open, as does the iOS 17 lane.
No reviewer-account/game/message changes were made during these smoke checks.

**Later October 23 recovery evidence (approximately 5:46 PM):** A second fresh,
network-disabled tmpfs restore replayed all ten deployed migrations unchanged.
pg_cron's API was available with job launching off, max_worker_processes=0 and no
cron worker; no jobs ran. All 38 count/44 FK checks, migrated boundary assertions
and a synthetic create/retry/join/chat/anonymized-delete/cleanup transaction passed;
the transaction rolled back. Read-only production catalog comparison matched 46
application functions and 148 table/policy/constraint/index/trigger entries,
including effective client privileges. Both restore containers were removed.
This supersedes the earlier untested-forward-migration limitation and historical
exposed-grant audit. It does not complete BETA-13's numeric/edit/read-minimization
audit or managed-auth/platform recovery. See the isolated restore record.

**October 23 BETA-13 source follow-up:** A crafted host UPDATE accepted capacity 1
despite creation's 2–50 contract. New migration `20261023215028` extends the existing
status guard to validate changed capacity, schedule/duration and location-pin
groups, retaining legacy notes/cancellation and current build-5 venue patches.
The local reproduction first failed; all 31 candidate SQL/RLS phase notices then
passed in rollback. No production deployment or binary change occurred. Full
location/sport representation and read-minimization audits remain open. See
[host edit evidence](2026-10-23-host-edit-boundaries.md).

**October 23 BETA-14 source follow-up:** Retrying join on a full game reset a
waiter's joined_at and queue priority. A synthetic regression failed against the
previous function; migration `20261023215505` skips conflict updates for existing
waitlist rows, preserving priority while retaining explicit leave/rejoin behavior.
All 32 candidate SQL/RLS phase notices passed in rollback. Local source only;
production and build 5 are unchanged. See [waitlist retry evidence](2026-10-23-waitlist-retry.md).

**October 23 BETA-14 concurrency follow-up:** The new local-only
`supabase/tests/host_action_concurrency.py` clones schema/history (no rows) into a
fresh network-disabled tmpfs container. Four ordered cancellation/join and
capacity/join races, twelve simultaneous cancellation/join races and six
waitlist retries passed count/capacity/lifecycle/priority checks. No source-local
database edit occurred; the disposable container was removed. This supplies the
previously missing host/cancellation exercise; physical two-account acceptance
and deployment of the two October 23 fixes remain open. See
[concurrency evidence](2026-10-23-host-action-concurrency.md).
