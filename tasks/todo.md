# TF-05 Task Checklist

## Preserved Prior Work and Scope

- [x] Preserve TF-02, TF-03, and TF-04 evidence in the main readiness checklist.
- [x] Confirm clean `main` at `7a81129`, matching `origin/main`.
- [x] Keep TF-02 archive/App Store Connect verification and TF-03 deployment/device verification open.
- [x] Do not start TF-06, BETA-04, or later workstreams.
- [x] Do not deploy, archive, upload, commit, or push.

## Baseline and Regression Proof

- [x] Reproduce Welcome truncation at Accessibility XXXL on iPhone 16e / iOS 26.3.
- [x] Reproduce clipped Sign Up and Sign In labels.
- [x] Confirm shared buttons use fixed 50-point heights.
- [x] Confirm Welcome is non-scrollable and uses large minimum spacers.
- [x] Preserve the pre-fix screenshot in the TF-05 evidence directory.
- [x] Add focused layout-contract tests and run them red-first.

## Shared Foundations

- [x] Use semantic/relative Dynamic Type for display typography.
- [x] Replace shared fixed button heights with 44-point minimums and vertical padding.
- [x] Allow shared button labels to wrap without losing meaning.
- [x] Give reusable compact controls and chips at least 44×44-point hit regions.
- [x] Make session cards and numeric stepper rows adapt when horizontal space is constrained.
- [x] Respect Reduce Motion in shared decorative transitions/effects.
- [x] Run focused tests/build checks.

## Welcome and Authentication

- [x] Make Welcome content scrollable and viewport-aware.
- [x] Allow the headline, body, button labels, and email guidance to grow.
- [x] Add stable Welcome accessibility identifiers.
- [ ] Verify Sign Up, Sign In, forgot password, email verification, banners, keyboard focus, and navigation dismissal.
- [x] Capture corrected normal-size and Accessibility XXXL screenshots.

## Major Screen Audit and Repairs

- [x] Onboarding static/layout audit.
- [x] Discover list, filters, map controls, loading/error/empty states static/layout audit.
- [x] My Games, history, cards, loading/error/empty states static/layout audit.
- [x] Session creation steps, map/location picker, adaptive bottom bar, validation, keyboard, and success overlay static/layout audit.
- [x] Session editing form and dismissal paths static/layout audit.
- [x] Session detail hero, map, roster, notes, chat/calendar entries, sticky actions, cancel/edit/run-it-back static/layout audit.
- [x] Attendance and report sheets, including scrolling and dismissal static/layout audit.
- [x] Chat messages, composer, send target, loading/error/empty states, and keyboard focus static/layout audit.
- [x] Profile, host profile, stat tiles, preferred sports, settings rows, notification toggles, blocked users, edit forms, sign-out, and deletion static/layout audit.
- [x] Global banners, sheets, alerts, buttons, empty states, and loading/error states static/layout audit.
- [x] Record but do not fix the BETA-04 nested session-card navigation/action issue.
- [x] Exercise safe authenticated Discover, My Games/history, create, session detail/chat, profile/host profile, and settings paths at Accessibility XXXL without submitting or changing account data.
- [x] Recheck authenticated Discover, My Games, Create, and Profile at Large after accessibility-specific adaptations.
- [x] Preserve authenticated Accessibility XXXL screenshots for create details, session detail, notification settings, and blocked-users empty state.

## Accessibility Settings and Assistive Technologies

- [x] Verify all standard Dynamic Type categories on safe unauthenticated surfaces on iPhone 16e / iOS 26.3.
- [x] Verify all accessibility Dynamic Type categories on safe unauthenticated surfaces on iPhone 16e / iOS 26.3.
- [ ] Verify VoiceOver labels, values, hints, traits, order, focus, actions, and dismissal.
- [x] Verify light and dark appearance.
- [x] Verify Bold Text.
- [x] Verify Increase Contrast.
- [x] Verify Reduce Motion.
- [x] Verify button shapes.
- [ ] Verify relevant keyboard and focus behavior.
- [x] Inspect authenticated accessibility-tree labels, values, hints, order, decorative-element hiding, and dismissal actions.
- [x] Document destructive, state-changing, auditory VoiceOver, and physical-device paths that remain manual.

## Final Verification

- [x] Focused accessibility/layout tests pass (4/4).
- [x] Complete iOS Debug simulator suite passes (153/153).
- [x] Unsigned generic-device Release build passes.
- [x] Release static analyzer passes.
- [x] `git diff --check` passes.
- [x] Final correctness/accessibility/scope/security review passes.
- [x] Only evidence-supported TF-05 checklist boxes are updated.
- [x] Recommended clean commit boundary is documented without committing.
