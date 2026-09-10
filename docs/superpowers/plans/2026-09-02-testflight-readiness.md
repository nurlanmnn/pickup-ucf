# PickUp UCF — TestFlight Readiness Checklist

> **Purpose:** Single source of truth for preparing PickUp UCF for internal TestFlight, external testers, and beta stabilization. Complete the checklist in order, update each checkbox as work lands, and create a focused step-by-step implementation plan for each workstream before changing production code.

**Status:** Not ready for TestFlight upload

**Last audited:** 2026-09-02

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

- [ ] Signed archive and App Store Connect validation.
- [ ] Physical-device push notification and Live Activity behavior.
- [ ] Production Supabase migrations, secrets, cron jobs, email hook, and APNs configuration.
- [ ] SQL/RLS integration suite; the local Docker/Supabase environment was unavailable during the audit.
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
- [ ] Enable the Push Notifications capability and verify the generated signed entitlement contains the correct production APNs environment.
- [x] Confirm regenerating the Xcode project from `ios/project.yml` does not remove signing or capability configuration.
- [ ] Set the correct distribution bundle identifiers and provisioning profiles in the Release/archive configuration.
- [ ] Increment the build number for the upload.
- [ ] Create a signed Archive using the Release configuration.
- [ ] Run Xcode Organizer validation and resolve every blocking error or warning.
- [ ] Upload the archive and confirm App Store Connect finishes processing it.

**Done when:** A signed archive validates, uploads, processes in App Store Connect, contains the app icon and required entitlements, and installs from TestFlight on a physical device.

## TF-02 — App privacy manifest and required-reason API declaration

**Why this blocks release:** The app directly uses `UserDefaults`, but the audited app target and bundle had no root `PrivacyInfo.xcprivacy`. Required-reason API declarations must reflect the app’s actual use, not only dependency manifests.

**Tasks:**

- [x] Inventory app and extension use of Apple required-reason APIs.
- [x] Add `PrivacyInfo.xcprivacy` to the main app target.
- [x] Declare `NSPrivacyAccessedAPICategoryUserDefaults` with an Apple-approved reason matching the actual usage.
- [x] Add a separate manifest to the widget target if its own code requires one. (Inventory confirmed it does not.)
- [x] Declare tracking and collected-data fields accurately; do not copy dependency declarations blindly.
- [ ] Verify the manifest is included in the archived app bundle.
- [ ] Generate and review Xcode’s privacy report for the archive.
- [ ] Ensure App Store Connect privacy answers match the manifest and real production behavior.

**Evidence (2026-09-10):** Added `ios/PickUpUCF/PrivacyInfo.xcprivacy` to the main app resources only. First-party and resolved-package inspection found only app `UserDefaults` required-reason use; its app-only defaults domain matches Apple reason `CA92.1`. The widget has no required-reason API use, independent collection/tracking, or third-party dependency, so it has no separate manifest. The manifest declares tracking false, no tracking domains, and nine linked/non-tracking categories based on repository behavior: name, email address, fitness, precise custom game coordinates, emails/text messages, other user content, user ID, device ID, and product interaction. Fitness and the user ID used to retrieve preferred sports are used for app functionality and product personalization; the remaining categories are used for app functionality. `xcodegen generate` placed the file only in the app resources phase. Source, Debug, and unsigned Release app manifests match byte-for-byte and pass `plutil`; both built widget bundles correctly contain no manifest. Debug simulator tests passed (123/123), as did the unsigned Release device build and Release static analyzer. The user confirmed the main App Store Connect record exists for bundle ID `edu.ucf.pickup` (Apple ID `68107128702`, Prepare for Submission); no widget record was created. Archive placement, Xcode's archive privacy report, production-provider confirmation, and App Store Connect privacy answers remain unverified/user-owned.

**Done when:** The signed archive contains valid privacy manifests, Xcode’s privacy report has been reviewed, and App Store Connect privacy answers are consistent with the app.

## TF-03 — Prevent APNs device-token ownership leaks across accounts

**Why this blocks release:** `device_tokens` currently allows the same APNs token to remain associated with more than one user because its key is `(user_id, apns_token)`. Sign-out and account deletion do not unregister the device token. On a shared phone, user A could continue receiving notifications—including chat previews—after user B signs in.

**Evidence:**

- `supabase/migrations/20260517120000_initial_schema.sql`
- `ios/PickUpUCF/Repositories/DeviceTokenRepository.swift`
- `ios/PickUpUCF/Repositories/AuthRepository.swift`
- `ios/PickUpUCF/Core/AppDelegate.swift`
- `supabase/functions/send-push/index.ts`

**Tasks:**

- [ ] Make each APNs token have one current account owner at the database level.
- [ ] Prefer an authenticated RPC that atomically reassigns the token to `auth.uid()` instead of a client-side delete/insert sequence.
- [ ] Revoke broad execution rights on the RPC and grant only the roles that need it.
- [ ] Store the most recently registered token locally so it can be removed during account transitions.
- [ ] Unregister the token before sign-out and before account deletion.
- [ ] Define safe behavior when unregistering fails: local auth state must still be cleared, and the failure must be recoverable/observable without exposing the token.
- [ ] Re-register/reassign the token after login, token rotation, app reinstall, and authorization changes.
- [ ] Preserve server cleanup for APNs responses indicating an invalid or unregistered token.
- [ ] Add migration tests proving one token cannot remain attached to two users.
- [ ] Add regression coverage for: user A signs in → token registers → A signs out → user B signs in on the same device → only B receives notifications.
- [ ] Confirm notification payload previews do not expose sensitive chat content to a stale account/device mapping.

**Done when:** Database constraints and end-to-end tests prove that an APNs token has exactly one current owner and account transitions cannot deliver one user’s notifications to another user.

## TF-04 — Fix user-facing error mapping

**Why this blocks release:** `AppErrorMapper` returns any `LocalizedError` before reaching friendly Supabase-specific mappings. Supabase `AuthError` and `PostgrestError` also conform to `LocalizedError`, so raw backend text can reach users and intended recovery guidance can be skipped.

**Evidence:** `ios/PickUpUCF/Core/AppErrorMapper.swift`

**Tasks:**

- [ ] Reorder or redesign mapping so known auth, database, networking, validation, and domain errors are handled before a generic `LocalizedError` fallback.
- [ ] Ensure unexpected server details, SQL text, internal identifiers, and implementation messages never appear in the UI.
- [ ] Preserve actionable copy for common states such as duplicate accounts, invalid credentials, expired links, connectivity loss, conflicts, and capacity limits.
- [ ] Add tests using real `AuthError`/`PostgrestError` values where constructible, or accurate test doubles that conform to `LocalizedError`.
- [ ] Add a safe generic fallback and retain detailed diagnostics only in privacy-safe internal logging.
- [ ] Audit all views/view models that show repository errors to ensure they use the mapper consistently.

**Done when:** Known failures produce specific, friendly recovery messages; unknown failures produce safe generic copy; raw backend errors are covered by regression tests and do not reach users.

## TF-05 — Make the app usable with accessibility text sizes

**Why this blocks release:** At Accessibility XXXL, the welcome headline/body truncate and the Sign Up/Sign In controls clip. The shared buttons use a fixed 50-point height, and the Welcome layout is not scrollable. Shared components can reproduce the problem throughout the app.

**Evidence:**

- `ios/PickUpUCF/DesignSystem/Components/PrimaryButton.swift`
- `ios/PickUpUCF/DesignSystem/Components/SecondaryButton.swift`
- `ios/PickUpUCF/Features/Auth/WelcomeView.swift`

**Tasks:**

- [ ] Replace fixed button heights with a minimum height plus vertical padding that allows labels to grow.
- [ ] Make the Welcome screen scroll or adapt with `ViewThatFits`/equivalent when content no longer fits.
- [ ] Allow multiline labels where truncation would remove meaning.
- [ ] Review fixed frames, hard-coded spacers, and combined accessibility elements across all major screens.
- [ ] Verify touch targets remain at least 44×44 points.
- [ ] Test every screen at all Dynamic Type accessibility sizes on the smallest supported iPhone.
- [ ] Test VoiceOver reading order, labels, hints, actions, focus behavior, and modal dismissal.
- [ ] Test Increase Contrast, Reduce Motion, Bold Text, button shapes, light mode, and dark mode.
- [ ] Add accessibility identifiers needed for repeatable UI checks.
- [ ] Add focused tests for shared component sizing where practical and preserve screenshots/manual evidence for the release checklist.

**Done when:** Core flows are readable and operable without clipping, truncation, overlapping, or unreachable controls at the largest supported text size and with VoiceOver.

## TF-06 — Internal TestFlight release gate

**Dependencies:** TF-01 through TF-05.

**Tasks:**

- [ ] Run the full iOS unit suite in Release-compatible conditions.
- [ ] Run the Deno Edge Function suite.
- [ ] Start local Supabase/Docker and run the SQL/RLS integration suite.
- [ ] Review the final app diff with special attention to auth, privacy, RLS, migrations, notifications, and secrets.
- [ ] Confirm production configuration contains no placeholders, test endpoints, debug flags, or development credentials.
- [ ] Verify no secrets, APNs tokens, emails, message bodies, or other PII are logged.
- [ ] Install the processed build through TestFlight on at least one physical iPhone running iOS 17 and one current-iOS device when available.
- [ ] Smoke test launch, sign-up/sign-in, email verification, onboarding, discover, create, join, leave, chat, edit/cancel, reporting/blocking, profile editing, sign-out, and account deletion.
- [ ] Test poor connectivity, airplane-mode relaunch, background/foreground transitions, force quit, and expired sessions.
- [ ] Verify push notifications, deep-link routing, badge behavior, and Live Activities on physical hardware.
- [ ] Verify calendar export and location permission denial/recovery.
- [ ] Confirm crash-free launch and no high-severity runtime console errors.
- [ ] Record the build number, commit SHA, environment, migration version, known issues, and tester instructions.

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

- [ ] Publish a stable HTTPS privacy-policy URL.
- [ ] Link the privacy policy from an easily discoverable in-app location and App Store Connect.
- [ ] Document what is collected and why: email, profile identity, sessions, attendance, chat, reports, device tokens, location permission behavior, calendar identifiers, and notification data.
- [ ] Name relevant processors/services, including Supabase, Brevo, Open-Meteo, and Apple/APNs, and explain their roles accurately.
- [ ] Document retention, deletion, account deletion, consent withdrawal, security practices, and contact details.
- [ ] Publish Terms of Use/community rules appropriate for a campus social/sports app.
- [ ] Confirm in-app account deletion removes or anonymizes data according to the published policy and any safety/legal retention needs.
- [ ] Complete App Store Connect App Privacy answers from the production data-flow inventory.
- [ ] Ensure support email, privacy contact, and response ownership are monitored.

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

- [ ] Add beta description and concise “What to Test” instructions.
- [ ] Add a monitored feedback email and contact information.
- [ ] Add the required export-compliance information.
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
