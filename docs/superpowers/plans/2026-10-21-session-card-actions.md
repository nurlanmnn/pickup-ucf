# BETA-04 — Separate game navigation from participation actions

This is the remaining UX hazard found during the October 21 audit: Discover and My Games wrap SessionCard in a NavigationLink while the card contains another button.

1. Make the card's artwork/details one explicit Open action, with a separate Join/Waitlist/Leave action below it. Never nest one control inside the other. Share the same layout and accessible labels in both feeds.
2. Update Discover and My Games to pass navigation callbacks; preserve their join/leave state, refresh behavior, and destination routing.
3. Add native rendered-control tests proving Open cannot join and Join/Leave cannot open. Inspect normal and largest-text renders, check touch-target frames, and run the full regression suite.
4. Update BETA-04's source/local evidence; keep device keyboard, Switch Control, Voice Control, and complete VoiceOver validation open.

Files: `DesignSystem/Components/SessionCard.swift`, DiscoverView, MyGamesView, UXFlowTests, and the readiness checklist. Revert only these action-layout changes to roll back; backend behavior and game state are unchanged.

## Local verification

The actual accessible participation control changed only the participation counter; Open changed only the navigation counter. Both control frames were at least 44pt high. The final full 217-test suite, unsigned Release build, and static analyzer passed. Visually inspected the two retained screenshots under ignored `docs/testflight-evidence/ux-audit/game-actions*.png`. Complete physical-device assistive-technology coverage remains open.
