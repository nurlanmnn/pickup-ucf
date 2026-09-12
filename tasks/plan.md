# Implementation Plan: TF-05 Dynamic Type and Assistive Technology

## Overview

Complete TF-05 only. Make the iOS app readable and operable through every supported Dynamic Type category, especially Accessibility XXXL on the smallest installed iPhone, while preserving the existing visual identity and behavior. Repair shared layout contracts first, then the unauthenticated and authenticated feature surfaces that inherit or repeat those constraints. Do not start TF-06 or BETA-04.

## Preserved Prior Work

- TF-02 privacy-manifest implementation evidence remains complete; archive placement, Xcode privacy-report review, and App Store Connect privacy answers remain open and user-owned.
- TF-03 implementation and agent-owned verification remain complete at `ab9e67b`; production migration deployment and physical-device APNs/account-switch verification remain open.
- TF-04 implementation and verification remain complete at `7a81129`: 149/149 Debug simulator tests, unsigned Release build, Release analyzer, and `git diff --check` passed.
- The TF-05 changes are iOS UI/test/documentation only. They require no migration, Edge Function change, deployment, archive, upload, or commit.

## Verified Baseline and Root Causes

- Work begins from clean `main` at `7a81129`, matching `origin/main`.
- Accessibility XXXL was reproduced on iPhone 16e / iOS 26.3 before implementation. The Welcome headline/body and email guidance truncate, and Sign Up/Sign In labels overflow fixed 50-point containers.
- `PrimaryButton` and `SecondaryButton` force a 50-point height after applying a Dynamic Type font. The label grows but the container cannot.
- `WelcomeView` uses a non-scrollable `VStack`, two large minimum spacers, and fixed-size brand typography, so vertical overflow becomes unreachable.
- `AppFont.display` uses an absolute point size instead of a text style, so display text does not participate correctly in Dynamic Type.
- Repeated compact controls use 30–36-point explicit frames or padding that produces sub-44-point hit regions: session-card actions, Discover presentation/map controls, chat send, and compact chips.
- `SessionCard` keeps all metadata and its action in one horizontal row, forces location to one line, and combines the full card accessibility tree even though a nested quick action exists.
- Session detail uses a fixed 148-point hero and fixed 50-point custom action labels; create-session keeps Back/Next side-by-side; profile stat tiles and numeric stepper rows assume ample horizontal space.
- Many major screens already scroll and use semantic text styles. Auth forms, onboarding, My Games, create/edit forms, session detail, attendance/reporting, chat, and profile/settings therefore need focused constraint and accessibility fixes rather than redesigns.
- BETA-04 remains separate: `NavigationLink` wrapping `SessionCard` while the card contains Join/Leave is a nested-interaction and VoiceOver ambiguity. TF-05 will not refactor that routing contract.

## Accessibility Invariants

- Text that conveys meaning may wrap and grow vertically; it must not be made to fit through truncation or scale reduction.
- Custom controls have at least a 44×44-point interactive region and allow multiline labels.
- Full-screen and sheet content that can exceed the viewport remains scrollable, including with the keyboard and sticky action bars present.
- Horizontal compositions fall back to vertical/adaptive arrangements when Accessibility Dynamic Type cannot fit.
- Decorative imagery is hidden from assistive technologies; actionable elements expose concise labels, values, hints, traits, and identifiers where repeatable checks need them.
- Reading/focus order follows visual task order. Sheets retain explicit Close/Cancel actions and keyboard accessories remain reachable.
- Reduce Motion suppresses nonessential bounce, scale, slide, and spring effects without changing navigation or state.
- Light/dark appearance, Bold Text, Increase Contrast, button shapes, and keyboard/focus settings do not hide or disable content.

## Phase 1: Regression Contracts and Evidence

- [ ] Preserve the pre-fix Accessibility XXXL screenshot in `docs/testflight-evidence/tf-05/`.
- [ ] Add focused tests for shared minimum control height, vertical padding, accessibility-size breakpoints, and any extracted layout policy.
- [ ] Confirm the regression tests fail for the current fixed-height/shared-layout contracts before implementation.
- [ ] Add stable accessibility identifiers for Welcome actions and other repeatable unauthenticated checks.

## Phase 2: Shared Typography, Buttons, Controls, and Motion

- [ ] Replace fixed 50-point shared button heights with a minimum 44-point height plus vertical padding; allow centered multiline labels and preserve loading/disabled states.
- [ ] Make display typography relative to a semantic text style.
- [ ] Give compact reusable chips and session-card quick actions a 44-point minimum hit target and allow meaningful labels to wrap.
- [ ] Make session-card content adaptive at accessibility sizes and stop truncating the location.
- [ ] Make numeric stepper rows fall back to a vertical arrangement instead of compressing the title or controls.
- [ ] Respect Reduce Motion in shared appearance, card-press, banner, keyboard accessory, and decorative symbol effects.
- [ ] Run focused tests and a Debug simulator build after this slice.

**Likely files:** `Typography.swift`, `AccessibilityLayout.swift`, shared button/card/chip/stepper components, shared motion modifiers, and `RootView.swift`.

## Phase 3: Welcome and Authentication

- [ ] Make Welcome vertically scrollable with viewport-aware centering at ordinary sizes and reachable content at accessibility sizes.
- [ ] Remove fixed-size text assumptions, allow headline/body/guidance to wrap, and preserve the dark/gold identity.
- [ ] Verify Sign Up, Sign In, forgot-password, verification, form validation, loading/error banners, navigation dismissal, and keyboard focus order.
- [ ] Capture corrected Welcome screenshots at normal text and Accessibility XXXL.
- [ ] Run focused tests and launch checks after this slice.

## Phase 4: Core Authenticated Layouts

- [ ] Audit and repair onboarding sports selection and call-to-action growth.
- [ ] Repair Discover list/filter/map control hit regions and accessibility labels without changing nested card routing.
- [ ] Verify My Games sections, cards, empty/error/loading states, and history expansion.
- [ ] Make create-session bottom actions adaptive; verify each step, embedded location/map picker, validation scrolling, keyboard accessory, success overlay, and sheet dismissal.
- [ ] Verify edit-session `Form` rows and apply the shared adaptive numeric-row behavior.
- [ ] Make session-detail hero/actions adaptive; verify roster, notes, map, calendar, chat entry, attendance, report, edit/cancel/run-it-back, errors, and sticky action reachability.
- [ ] Give chat composer/send controls sufficient hit area and verify long message/author text and keyboard focus.
- [ ] Make profile/host stat tiles adaptive and verify preferred-sport chips, settings rows, notification toggles, blocked users, password/username/sport forms, sign-out, and deletion.
- [ ] Run focused tests/build checks after each meaningful screen group.

## Phase 5: Assistive-Technology and Appearance Verification

- [ ] On iPhone 16e / iOS 26.3, exercise every standard and accessibility content-size category; give extra visual scrutiny to XS, XXL, Accessibility Medium, and Accessibility XXXL.
- [ ] Verify VoiceOver labels, values, hints, traits, reading order, focus order, actionable names, sheet dismissal, and that important child content is not hidden by `.combine`.
- [ ] Verify light mode, dark mode, Bold Text, Increase Contrast, Reduce Motion, button shapes, and keyboard/focus behavior.
- [ ] Exercise all safe unauthenticated runtime paths. Statically audit authenticated-only screens and identify exact manual steps if safe credentials are unavailable.
- [ ] Preserve corrected screenshots and a concise evidence matrix in the focused plan/checklist.

## Phase 6: Final Verification and Checklist Update

- [ ] Run all focused accessibility/layout tests.
- [ ] Run the complete iOS Debug simulator suite.
- [ ] Run an unsigned generic-device Release build.
- [ ] Run the Release static analyzer.
- [ ] Run `git diff --check`.
- [ ] Review the final diff for correctness, accessibility semantics, scope, security/privacy, accidental behavior changes, and unrelated formatting.
- [ ] Update only TF-05 checklist boxes supported by concrete evidence; keep authenticated/device-only items open if they were not exercised.

## Verification Commands

```sh
cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=<iphone-16e-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution -only-testing:PickUpUCFTests/AccessibilityLayoutTests test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=<iphone-16e-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze

cd ..
git diff --check
```

## Rollback and Scope

- Rollback is limited to SwiftUI layout/accessibility code, focused tests, and TF-05 documentation/evidence.
- No persisted model, database, API, migration, Edge Function, notification ownership, error mapping, or production configuration changes are required.
- Do not refactor nested `NavigationLink` plus Join/Leave behavior (BETA-04), start a broad XCUITest suite (BETA-11), perform archive/upload work (TF-06), or commit/push without authorization.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Fixing one screen leaves the shared constraint elsewhere | High | Repair/test shared controls first, then audit every call site and custom duplicate |
| Accessibility layouts materially change normal-size visuals | Medium | Use minimums, semantic fonts, and accessibility-only fallbacks; capture normal-size screenshots |
| Sticky bars or keyboards cover enlarged controls | High | Keep main content scrollable and use safe-area insets; test focus and dismissal paths |
| Broad motion changes alter behavior | Medium | Suppress only nonessential animation when Reduce Motion is enabled; preserve state transitions |
| Authenticated flows cannot be launched safely | High | Complete static/shared fixes and provide exact numbered manual verification without requesting credentials |
| BETA-04 is accidentally pulled into TF-05 | High | Record the nested-interaction finding but do not change navigation/action routing |

## Verification Results

- Focused layout-contract tests were demonstrated red before `AccessibilityLayout` existed, then passed 4/4.
- All 12 Simulator-supported Dynamic Type categories were exercised on iPhone 16e / iOS 26.3.1; Large and Accessibility XXXL evidence is preserved under `docs/testflight-evidence/tf-05/`.
- The Welcome and Sign Up accessibility trees expose complete content in visual task order, stable action names, and no decorative auth-header elements.
- An existing authenticated test session was used without entering or transmitting credentials. At Accessibility XXXL, runtime checks covered Discover list/map/filter states; My Games empty/history states; all three create-session steps without submission; completed/cancelled session details; empty session chat without sending; profile and host profile; settings, notification toggles without changing values, blocked users, username/password/delete-account forms without submission, and navigation/sheet/keyboard dismissal paths. The session-detail metadata, create details stepper/actions, notification rows, My Games section title, and shared empty states were repaired from issues found during this pass.
- Authenticated Large checks confirmed the standard Discover, My Games, Create, and Profile layouts remain intact after the accessibility-size adaptations.
- Light/Dark, Increase Contrast, Bold Text, Button Shapes, and Reduce Motion were enabled and checked on safe unauthenticated screens; Simulator preferences were reset afterward.
- The complete Debug suite passed 153/153, the unsigned generic-device Release build passed, the Release analyzer passed, and `git diff --check` passed.

## Open Verification Constraints

- Auditory VoiceOver output and rotor/focus movement, Switch Control/Voice Control, and physical-device assistive-technology behavior remain user-owned manual verification. The simulator accessibility tree was inspected for labels, values, hints, order, decorative-element hiding, and dismissal actions, but that is not equivalent to operating VoiceOver itself.
- Destructive or state-changing account/network actions were deliberately not performed: join/leave, create/edit/cancel/run-it-back submission, attendance/report submission, chat send, notification changes, block/unblock, sign-out, password change, and account deletion. These require purpose-built test data or explicit action-time confirmation and remain part of the candidate-build manual pass.
- The broad "every screen at all accessibility sizes" task remains open because all 12 sizes were exercised on safe unauthenticated surfaces while authenticated coverage concentrated on Large and Accessibility XXXL. Keep BETA-04's nested session-card routing/action issue separate.
