# PickUp UI refresh

## Direction

Make the first launch welcoming and the rest of the app feel like one product. Use the clarity and calm hierarchy of a polished travel app while keeping UCF gold and a distinct campus-sports identity.

- Preserve the original gold location-pin/court logo. Welcome, account flows, and onboarding share the same logo lockup, using the existing app-icon artwork unchanged.
- Warm neutral backgrounds, crisp system typography, dark readable text, restrained gold actions.
- Consistent bordered surfaces, control radii, navigation tint, and short press transitions.
- Three skippable introduction steps: find a game, meet your people, host a session. Sign in is always available. Returning visitors can go straight to account creation.
- Original vector court artwork shared by the introduction, session cards, and session detail.
- Carry the system through auth, sport selection, Discover, My Games, profiles/settings, create/edit, chat, maps, and moderation using shared tokens and components.
- Preserve existing account, game, chat, notification, and moderation behavior. Support light/dark appearance, Dynamic Type, VoiceOver labels, and Reduce Motion.

## Verification

Build and run the native iOS app in the simulator; run the existing unit suite. Inspect first launch, introduction navigation, auth, and representative shared surfaces at normal and accessibility text sizes. Record local verification and any unverified account-dependent paths below.

## Status

Implemented locally. Existing unrelated local changes are preserved.

### Coverage

| Area | Changes |
| --- | --- |
| First launch | Three illustrated steps, skip/back/page navigation, persistent returning-visitor shortcut, direct sign in |
| Auth | Shared editorial headers, warm forms, consistent buttons and readable links; welcome follows system appearance |
| Discover / My Games | Illustrated game cards, quieter sport categories and section dividers, clear selected states |
| Game details | Shared court artwork, legible hero overlay, shared surfaces and bottom actions |
| Create / Edit | Shared fields, selected sport checkmarks, progress and button styles; native forms use the app background |
| Profiles / Settings | Flat identity marks, quieter grouped settings, shared stat cards and navigation |
| Chat / Maps / Moderation | Inherit shared typography, surfaces and accents; map clustering uses the new gold |
| Live Activity | Matching gold and dark surface in the separate widget target |

### Verified on October 21, 2026

- Native Debug simulator build and **204/204 tests passed**, including the existing chat history and account/game regression suite.
- New `DesignSystemTests` checks body/secondary/link text contrast against all three surfaces in both appearances, black-on-gold actions, and white-on-red soon badges (minimum 4.5:1).
- Native shared-component renders at 320pt and 402pt, light/dark, and Accessibility XXXL; horizontal scroll overflow assertions pass. Screenshot attachments are retained in the test results.
- Simulator interaction checks: Continue, Skip intro, page selection, Back, sign-up navigation, direct sign in, and empty sign-in field errors.
- Largest Dynamic Type welcome: decorative artwork is omitted, branding stays contained, full copy scrolls, and account actions remain visible. Visually checked scrolling to the end.
- `git diff --check` passed. The Xcode project received only the new test source registration on top of its pre-existing local changes; XcodeGen was not rerun.

Local preview captures are under ignored `docs/testflight-evidence/ui-refresh/`. The latest test result is `/tmp/pickup-logo-tests.xcresult` (204/204 passed after restoring the original logo).

Account-dependent screens use the new shared system but have not all been visited with a live signed-in account. This is simulator and synthetic-component validation; physical-device VoiceOver, complete signed-in navigation, and live backend flows remain unverified. No distribution or production actions were performed.
