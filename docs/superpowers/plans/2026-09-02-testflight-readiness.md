# PickUp UCF — TestFlight Readiness Checklist

> **Purpose:** Single source of truth for preparing PickUp UCF for internal TestFlight, external testers, and beta stabilization. Complete the checklist in order, update each checkbox as work lands, and create a focused step-by-step implementation plan for each workstream before changing production code.

**Status:** Internal TestFlight build uploaded and processed; physical-device validation pending

**Last audited:** 2026-09-16

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
- [ ] Physical-device push notification and Live Activity behavior.
- [ ] Production Supabase migrations, secrets, cron jobs, email hook, and APNs configuration.
- [x] SQL/RLS integration suite passed against a clean local Supabase reset on 2026-09-11.
- [ ] Authenticated UI flows at runtime; audit credentials were not available.
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
- [ ] Install the processed build through TestFlight on at least one physical iPhone running iOS 17 and one current-iOS device when available.
- [ ] Smoke test launch, sign-up/sign-in, email verification, onboarding, discover, create, join, leave, chat, edit/cancel, reporting/blocking, profile editing, sign-out, and account deletion.
- [ ] Test poor connectivity, airplane-mode relaunch, background/foreground transitions, force quit, and expired sessions.
- [ ] Verify push notifications, deep-link routing, badge behavior, and Live Activities on physical hardware.
- [ ] Verify calendar export and location permission denial/recovery.
- [ ] Confirm crash-free launch and no high-severity runtime console errors.
- [x] Record the build number, commit SHA, environment, migration version, known issues, and tester instructions.

**Evidence (2026-09-13):** TF-06 began from clean `main` at `f54880285026010be5ec5c1d48137fc41374a21e`; a fresh read-only remote check confirmed `origin/main` at the same SHA with zero divergence. The final review baseline is `7076810`, immediately before the seven candidate commits that added/fixed Live Activity delivery and then completed TF-02 through TF-05. The optimized Release-configured simulator suite passed **157/157** with `ENABLE_TESTABILITY=YES`, 0 failures, 0 skipped, on iPhone 16e / iOS 26.3.1. An initial unmodified Release test attempt failed before execution because shipping Release correctly has testability disabled while the suite uses `@testable import`; this was a test-configuration constraint, not an application build failure. The Deno suites passed **24/24** (send-push 14/14; fetch-weather 10/10). A clean local Supabase reset applied all 24 migrations, and the complete SQL/RLS suite passed all **23** phase assertions with stop-on-error enabled. The unsigned generic-device Release build and Release static analyzer passed with no emitted application warnings; the built app contains `Assets.car` and a byte-identical privacy manifest, while the widget correctly has no separate manifest. Source plists and the built app/widget report version **1.0 (1)**. The local Release configuration contains present, non-placeholder, HTTPS Supabase settings and targets the same linked project, but secret values were not displayed or recorded.

The final baseline-to-candidate review covered tests first, then authentication/session transitions, APNs ownership, Live Activities, push payload/deep-link routing, privacy resources, error mapping, RLS/RPC grants, migrations, accessibility changes, and dependency/configuration scope. It found and repaired two TF-06 defects in the uncommitted working tree: invalid app configuration previously fell back to a placeholder service and showed developer setup instructions to users, and `send-auth-email` logged a rejected full address plus raw verification/provider error details. `AppConfig` now validates and fails closed, renders a service-unavailable state without constructing the backend client, and blocks backend deep-link handling until configuration is valid; 4/4 focused tests were demonstrated red then green. The email function now logs only bounded event/status metadata and passes `deno check`. A static diagnostics audit found no iOS app logging APIs and no remaining email/token/body/error-detail arguments in the email function's logs. A high-confidence tracked-history scan found only the documented private-key marker example in `README.md`; no sensitive-path file has been tracked. `deno fmt --check` remains red for the pre-existing formatting of `send-auth-email/index.ts`; a broad unrelated reformat was intentionally not bundled into TF-06.

Safe simulator checks on the current working tree confirmed authenticated cold launch, force-quit/relaunch, background/foreground restoration, and rejection of a malformed custom-scheme session link without mutating account data. The app remained on the authenticated Discover surface. Fourteen initial and two final high-severity unified-log entries were all Apple Network framework connection-state queries (`unconnected connection` / `no local endpoint`); there was no crash, assertion, app-owned error log, or PII-bearing app diagnostic. This does not close the processed-build/physical-device console check.

The linked production backend is **not at migration parity**: a fresh dry run shows exactly `20260822000000`, `20260909000000`, and `20260910120000` remain pending. They were not applied because no recoverable hosted backup is available without a Supabase plan upgrade, which the user chose to defer for this internal beta. The privacy-hardened `send-auth-email` revision was type-checked and deployed successfully; `fetch-weather` and `send-push` remain active. The six required APNs/cron secret names are now present, but no secret values were read. Production cron status and exact `send-push` code parity remain unverified.

Build **1.0 (2)** is committed and pushed at `316b29bd59f5efafcf43151f634ad55b46921b8f`. Xcode created a Release archive, exported it with cloud-managed Apple Distribution signing, and confirmed production APNs entitlement, matching app/widget build numbers, App Store profiles, and the root privacy manifest. The generated privacy report was visually reviewed and stored in the ignored evidence directory. Xcode Organizer validation passed every check.

**Processed-build update (2026-09-15):** Xcode uploaded build **1.0 (2)** on Sep 14, 2026, and App Store Connect completed processing and export compliance. The build is `Ready to Submit`; Build Metadata reports binary state `Validated`, bundle ID `edu.ucf.pickup`, minimum iOS 17.0, arm64, symbols included, `get-task-allow: false`, production `aps-environment`, and the matching `edu.ucf.pickup.widget` extension. It reports `App Uses Non-Exempt Encryption: No` and `App Icon Hidden: No`. The submitted compliance answers identify standard encryption and exclude France, avoiding a separate French encryption filing for this build. The compiled distribution asset catalog contains the 1024×1024 `AppIcon` rendition, although App Store Connect may continue to show a placeholder until the build is attached to a version.

The user published the App Store privacy answers and saved the public privacy-policy URL. The six required APNs/cron secret names are present without their values being read. By user choice, the Supabase upgrade and the three pending production migrations remain deferred for this internal beta; scheduler execution and exact deployed `send-push` parity remain unverified. Physical-device installation and every iOS 17/current-iOS matrix row remain open. Detailed tester instructions are in `docs/testflight/tf-06-device-runbook.md`.

**Internal-testing update (2026-09-16):** The internal TestFlight group **Internal Testers** exists. Build **1.0 (2)** is assigned to the group with status **Testing**, one internal Apple Account has been invited, and the internal “What to Test” instructions are saved. This completes the upload and internal-group setup portion of TF-06 only. It does not close TF-06: invitation acceptance, TestFlight installation, and every iOS 17/current-iOS physical-device row still require direct device evidence.

**Live Activity and in-app privacy update (2026-09-15):** Settings → Privacy now includes a native system `Link` labeled **Privacy Policy** that opens the published `https://pickup-ucf-privacy.vercel.app` page. Live Activity content now carries both session start and end times, derives pre-session/live/ended presentation from those dates, and uses the session end as the stale boundary instead of treating staleness as the start signal. The app immediately ends expired activities when it launches, becomes active, or refreshes My Games session data, while leave, host cancellation, cancellation notifications, sign-out, and account transitions retain immediate local cleanup. The APNs end payload now includes `startsAt` and `endsAt`, matching the Swift content state. Regression tests were demonstrated red before the fix and green afterward; focused checks passed 13/13 iOS and 3/3 Live Activity Edge Function tests, the complete iOS suite passed 159/159, all 14 `send-push` tests passed, Deno formatting passed, and the unsigned Release build and Release analyzer passed.

This update does **not** make removal reliable while the app is suspended or the phone is locked. Fully reliable background removal still requires deploying the intentionally deferred `20260909000000_live_activity_end_pushes.sql` migration, deploying the current `send-push` function revision, and verifying the production scheduler invokes it successfully. None of those production actions were performed in this work, and no new TestFlight build was uploaded.

**Done when:** All automated checks pass, a processed TestFlight build completes the physical-device critical-path smoke test, and the build’s exact backend/configuration state is recorded.

---



# Gate 2 — Before inviting external testers

All `EXT-*` items are **P1** and must be complete before a build is submitted to Beta App Review or shared outside the internal team.

## EXT-01 — User-generated-content safety and moderation

**Why this is required:** Session notes and chat are user-generated content. Current reporting/blocking is session/host oriented and does not yet provide complete content filtering, message/user reporting, broad user blocking, moderator operations, or published support contact details.

**Tasks:**

- [ ] Publish clear community rules and prohibited-content standards.
- [ ] Add reasonable objectionable-content filtering for session notes, display names, custom sports/locations, and chat messages.
- [ ] Let users report an individual message, user, and session with a reason and optional context.
- [ ] Let users block an abusive user across discovery, sessions, chat, notifications, and future interactions—not only one session.
- [ ] Define what happens to existing shared sessions and chat history after a block.
- [ ] Prevent blocked users from contacting or notifying each other through alternate app flows.
- [ ] Build an authenticated moderation workflow for reviewing reports, removing content, warning/suspending users, and recording actions.
- [ ] Define a response-time target and escalation path for urgent safety reports.
- [ ] Publish an accessible support/contact method in the app and store metadata.
- [ ] Rate-limit report creation and protect moderation functions with least-privilege RLS/RPC permissions.
- [ ] Test abusive-content, false-report, duplicate-report, block/unblock, deleted-account, and notification edge cases.
- [ ] Complete the App Store age-rating/content questionnaire based on actual UGC behavior.

**Done when:** Users can filter/avoid, report, and block abusive content or users; moderators can act on reports promptly; the policy and contact path are visible; abuse tests pass.

## EXT-02 — Privacy policy, terms, data disclosures, and support

**Tasks:**

- [x] Publish a stable HTTPS privacy-policy URL.
- [x] Link the privacy policy from an easily discoverable in-app location. The App Store Connect URL is saved.
- [x] Document what is collected and why: email, profile identity, sessions, attendance, chat, reports, device tokens, location permission behavior, calendar identifiers, and notification data.
- [x] Name relevant processors/services, including Supabase, Brevo, Open-Meteo, and Apple/APNs, and explain their roles accurately.
- [x] Document retention, deletion, account deletion, consent withdrawal, security practices, and contact details.
- [ ] Publish Terms of Use/community rules appropriate for a campus social/sports app.
- [ ] Confirm in-app account deletion removes or anonymizes data according to the published policy and any safety/legal retention needs.
- [x] Complete and publish App Store Connect App Privacy answers from the production data-flow inventory.
- [ ] Ensure support email, privacy contact, and response ownership are monitored.

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

**Done when:** In-app links work, policies match the shipped product and backend, App Store disclosures are consistent, and deletion/retention behavior has been tested.

## EXT-03 — Beta App Review access and reviewer notes

**Why this matters:** Registration is restricted to UCF email addresses, so the reviewer needs a reliable preverified path into the app.

**Tasks:**

- [ ] Create a dedicated, preverified UCF demo account for Beta App Review.
- [ ] Seed safe sample data so Discover, My Games, session detail, chat, report/block, and profile flows can be reviewed.
- [ ] Ensure the demo account does not expose real student data or production secrets.
- [ ] Add credentials and exact login steps to Beta App Review Information.
- [ ] Explain the UCF-email restriction and any one-time verification behavior.
- [ ] Add reviewer notes for notification, location, calendar, widget, Live Activity, deep-link, reporting, and account-deletion flows.
- [ ] Confirm the review account remains usable for the duration of review.

**Done when:** A reviewer starting from a fresh install can access and exercise every review-relevant feature without contacting the developer.

## EXT-04 — TestFlight metadata and tester experience

**Tasks:**

- [ ] Add the external-beta description and final “What to Test” scope. Internal instructions for build 1.0 (2) are saved.
- [ ] Add a monitored feedback email and contact information.
- [x] Add the required export-compliance information for build 1.0 (2), with France excluded.
- [ ] Prepare screenshots or annotated test notes for flows that require setup.
- [ ] List known issues honestly and distinguish unsupported behavior from defects.
- [ ] Create an initial small external group before widening access.
- [ ] Define how testers should submit reproduction steps, screenshots, device/iOS version, and diagnostic context.

**Done when:** App Store Connect accepts the external testing configuration and testers have clear scope, setup, feedback, and support instructions.

## EXT-05 — Production backend and notification readiness

**Tasks:**

- [ ] Deploy every required Supabase migration to the production project in order.
- [ ] Verify RLS is enabled and least-privilege policies behave correctly for anonymous, authenticated, blocked, and deleted users.
- [ ] Configure `APNS_ENV=production`, APNs key/team/bundle identifiers, and rotation ownership.
- [ ] Configure Edge Function secrets, Brevo/email-hook secrets, cron secret, and environment-specific URLs.
- [ ] Confirm notification outbox cron schedules are active, idempotent, and monitored.
- [ ] Exercise the production email-verification/reset hooks and failure path.
- [ ] Verify APNs invalid-token cleanup and delivery status handling.
- [ ] Verify push taps route to the correct session/chat and fail safely when content was deleted or access was revoked.
- [ ] Document deployment, migration, secret rotation, rollback, and incident-response procedures.
- [ ] Confirm production backups and restore expectations for user/session/report data.

**Done when:** Production services pass an end-to-end test using the candidate build, permissions are least-privilege, scheduled work is observable, and rollback/recovery procedures are documented.

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

**Problem:** The chat query orders `created_at` ascending and applies `limit(50)`, which returns the oldest 50 messages rather than the newest 50.

**Evidence:** `ios/PickUpUCF/Repositories/ChatRepository.swift`

**Tasks:**

- [ ] Query the newest page deterministically, then present it in chronological order.
- [ ] Add cursor-based “load older messages” pagination.
- [ ] Define stable ordering for identical timestamps, using a secondary unique key.
- [ ] Preserve scroll position while prepending older messages.
- [ ] Test conversations with 0, 1, 50, 51, and several hundred messages.
- [ ] Test pagination while realtime inserts arrive.

**Done when:** Opening chat shows the latest conversation, older history loads without duplicates/gaps/jumps, and tests cover more than 50 messages.

## BETA-02 — Make session creation atomic (**P1**)

**Problem:** Session creation inserts the session and host participant in separate operations. A failure between them can leave `player_count = 1` with no host participant row.

**Evidence:** `ios/PickUpUCF/Repositories/SessionRepository.swift`

**Tasks:**

- [ ] Replace the client-side multi-step write with a transaction-backed RPC/database function.
- [ ] Validate host identity and all creation invariants server-side.
- [ ] Ensure the host participant row and count are created atomically.
- [ ] Apply least-privilege execute grants to the function.
- [ ] Add rollback/failure tests and duplicate-request/idempotency coverage.
- [ ] Update client mapping for structured domain errors.

**Done when:** A session and its host membership either both exist correctly or neither exists, including on retry and simulated network failure.

## BETA-03 — Enforce server-side input and content limits (**P1**)

**Problem:** Chat currently enforces non-empty content but no practical maximum. Display names, session notes, custom sports, and custom locations also need aligned client/server bounds to prevent abuse, broken layouts, and oversized payloads.

**Tasks:**

- [ ] Define normalized minimum/maximum lengths for chat messages, display names, session notes, custom sport names, and custom location names.
- [ ] Decide whitespace, newline, emoji/grapheme, and Unicode normalization behavior.
- [ ] Add database constraints or controlled RPC validation so crafted clients cannot bypass limits.
- [ ] Mirror limits in the iOS UI with counters and accessible inline guidance.
- [ ] Map rejected input to safe, specific errors.
- [ ] Add boundary tests at below-minimum, exact-limit, over-limit, whitespace-only, multiline, and multi-byte Unicode inputs.
- [ ] Coordinate limits with the UGC filter/moderation rules.

**Done when:** Client and server enforce the same documented rules and malicious/oversized input cannot enter the database.

## BETA-04 — Remove nested navigation and join/leave controls (**P1**)

**Problem:** A `NavigationLink` wraps a session card that contains Join/Leave buttons. Nested interactive controls can cause accidental navigation and ambiguous VoiceOver behavior, especially when card children are combined into one accessibility element.

**Tasks:**

- [ ] Refactor the card so navigation and join/leave are separate, unambiguous actions.
- [ ] Give each action a clear accessibility label, value, hint, and state.
- [ ] Ensure joining/leaving cannot trigger navigation and vice versa.
- [ ] Verify keyboard/Switch Control/Voice Control behavior where applicable.
- [ ] Add UI tests for tap targets and action routing.

**Done when:** Visual, touch, and assistive-technology users can independently open, join, or leave a session without accidental actions.

## BETA-05 — Request calendar write-only access (**P1**)

**Problem:** The app requests full calendar access even though it only creates events.

**Evidence:**

- `ios/PickUpUCF/Core/CalendarExportService.swift`
- `ios/project.yml`
- `ios/PickUpUCF/Info.plist`

**Tasks:**

- [ ] On iOS 17+, request EventKit write-only access.
- [ ] Add `NSCalendarsWriteOnlyAccessUsageDescription` with clear user-facing copy.
- [ ] Remove full-access usage/configuration unless a documented feature truly needs calendar reads.
- [ ] Revisit storage of event identifiers when read access is unavailable.
- [ ] Test first request, allow, deny, restricted, Settings recovery, duplicate export, and deleted calendar/event cases.
- [ ] Update the privacy policy and App Store privacy answers if the data flow changes.

**Done when:** Calendar export works with the minimum permission necessary and denial/recovery paths are clear.

## BETA-06 — Ask for notifications contextually (**P1**)

**Problem:** Notification permission is requested immediately after authenticated bootstrap, potentially before onboarding or before users understand its value.

**Tasks:**

- [ ] Add an in-app explanation tied to a concrete reminder/chat benefit.
- [ ] Trigger the system prompt only after an intentional user action or meaningful setup point.
- [ ] Do not repeatedly nag users who decline.
- [ ] Show the current authorization state and a Settings deep link when permission is denied.
- [ ] Keep token registration/unregistration correct across permission changes and account transitions.
- [ ] Measure prompt acceptance without collecting unnecessary personal data.

**Done when:** Users understand why notifications are useful before the system prompt, and every permission state has a coherent recovery path.

## BETA-07 — Replace sensitive custom-scheme links with Universal Links (**P1**)

**Problem:** Session sharing and password reset use `pickupucf://`. Custom schemes have no web fallback and are weaker for sensitive auth callbacks because another app can claim the same scheme.

**Tasks:**

- [ ] Choose stable HTTPS routes for password reset and session sharing.
- [ ] Configure Associated Domains and host a valid `apple-app-site-association` file.
- [ ] Configure Supabase/auth redirect allowlists for the HTTPS callback.
- [ ] Add a web/App Store fallback for recipients without the app.
- [ ] Keep the custom scheme only as a documented transition fallback if needed.
- [ ] Validate incoming paths, identifiers, authentication state, and authorization before navigation.
- [ ] Test installed/not-installed, signed-in/signed-out, expired reset, deleted session, revoked access, and malicious-link cases.

**Done when:** Auth and share links use verified HTTPS association, have a useful fallback, and reject malformed or unauthorized routing.

## BETA-08 — Show the correct author for realtime chat inserts (**P1**)

**Problem:** Realtime messages are currently created with `author: nil`, so incoming messages may display the generic “Player” label until a reload.

**Evidence:** `ios/PickUpUCF/Features/Chat/ChatViewModel.swift`

**Tasks:**

- [ ] Include safe author metadata in the realtime flow or resolve it from a bounded profile/roster cache.
- [ ] Avoid an N+1 profile request for each incoming message.
- [ ] Define behavior for deleted, blocked, or renamed users.
- [ ] Keep profile visibility consistent with RLS/data-minimization rules.
- [ ] Test simultaneous senders, cache misses, reconnects, edits to display name, and deleted accounts.

**Done when:** New realtime messages immediately show the correct permitted author identity without excessive requests or privacy leakage.

## BETA-09 — Make account deletion and sign-out cleanup resilient (**P1**)

**Problem:** Database deletion followed by a failed auth sign-out can leave inconsistent local state. Token cleanup must also occur before the account disappears.

**Tasks:**

- [ ] Define an explicit cleanup sequence for device token, Live Activities, local caches, widget/App Group state, realtime subscriptions, and auth state.
- [ ] Unregister the APNs token before remote account deletion when possible.
- [ ] Clear local authenticated state even if the final remote sign-out call fails.
- [ ] Make retries safe and prevent deleted-account data from reappearing after relaunch.
- [ ] Show clear progress, confirmation, failure, and irreversible-action copy.
- [ ] Test offline deletion, partial backend failure, token-unregister failure, relaunch, and a new user signing in on the same device.

**Done when:** After confirmed deletion, the device contains no usable prior-account session/data and a subsequent user cannot receive or see the deleted user’s information.

## BETA-10 — Add privacy-safe observability (**P1**)

**Problem:** TestFlight crash feedback alone is not enough to diagnose backend, notification, realtime, and account-transition failures.

**Tasks:**

- [ ] Select a crash/error reporting approach and document its privacy implications.
- [ ] Add structured diagnostics for auth, session mutations, chat pagination/realtime, notification registration/delivery, deep links, and account deletion.
- [ ] Redact emails, auth credentials, APNs tokens, message bodies, precise locations, and other PII.
- [ ] Attach build/environment identifiers and safe correlation IDs.
- [ ] Define beta health signals: crash-free sessions, launch failures, auth failures, RPC errors, notification failures, and latency.
- [ ] Configure alert ownership and a triage workflow for P0/P1 beta issues.
- [ ] Verify debug logging is not accidentally shipped at an unsafe verbosity.

**Done when:** The team can diagnose critical beta failures from privacy-safe evidence without asking testers to reproduce everything manually.

## BETA-11 — Add an XCUITest smoke suite (**P1**)

**Problem:** Unit coverage is strong, but there is no automated UI suite covering the release-critical user journey.

**Tasks:**

- [ ] Create deterministic test accounts/data or a dedicated test backend strategy.
- [ ] Cover launch, authentication, onboarding, Discover, create, join, leave, chat, profile, block/report, sign-out, and account deletion.
- [ ] Add accessibility identifiers without exposing implementation details to users.
- [ ] Cover permission alerts and denial paths using controllable test state.
- [ ] Add at least one largest-Dynamic-Type smoke path.
- [ ] Run the suite in CI or as a documented release-gate command.

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

- [ ] Inventory every table policy, RPC, trigger, and `SECURITY DEFINER` function.
- [ ] Revoke default/public execute rights and grant each function only to required roles.
- [ ] Move player counts, host membership, capacity enforcement, status transitions, and other invariants behind transactional server logic.
- [ ] Review whether profile, participant, roster, report, and blocked-user reads expose more data than each screen needs.
- [ ] Verify anonymous users cannot call authenticated mutation functions.
- [ ] Add SQL tests for cross-user access, crafted updates, blocked users, deleted users, and role escalation.
- [ ] Document intentional exceptions and the threat model.

**Done when:** The SQL security suite proves least-privilege access and clients cannot directly corrupt server-owned state.

## BETA-14 — Test join/leave concurrency and idempotency (**P1**)

**Tasks:**

- [ ] Review join and leave functions for consistent row locking and transaction boundaries.
- [ ] Guarantee capacity cannot be exceeded under concurrent joins.
- [ ] Guarantee counts cannot go negative or drift from participant rows.
- [ ] Make repeated join/leave requests idempotent or return stable domain errors.
- [ ] Add concurrent SQL tests for final-slot joins, simultaneous leave/join, retries, cancellation, and host actions.
- [ ] Add a reconciliation query/job only if invariants cannot be guaranteed transactionally.

**Done when:** Concurrency tests preserve capacity, membership, and count invariants under retries and simultaneous requests.

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
