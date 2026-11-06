# Intro paging — November 6, 2026

Owner requested swipe/scroll navigation alongside Continue and review of the
intro experience, then continued publishing preparation until15% five-hour
allowance remains. Start a continuation chat only if context fills. No reset
credits. Work starts from main `ff6a895`, on `codex/intro-paging`.

## Contract and decisions

- Keep three existing intro pages, copy, court artwork and design tokens.
- Allow native horizontal swipe navigation, in addition to Continue, Back,
  Skip intro and the accessible page buttons. All controls share page selection.
- Keep vertical scrolling within each page for small screens/larger text, with
  account actions reachable and no horizontal clipping.
- Keep completed-intro preference behavior: returning signed-out users land on
  the final page with direct Sign in. Replaying the whole tutorial on every
  sign-out adds friction; all pages remain reachable backwards by swipe/dots.
- Accessibility focus should follow the selected page for gesture and button
  changes. Respect Reduce Motion and retain semantic page labels/selection.
- Use the existing isolated UI transport; no live sign-in, account sign-out,
  fixture, chat, Calendar copy or production mutation is necessary for this slice.

Native paging reference:
[SwiftUI TabView](https://developer.apple.com/documentation/swiftui/tabview),
[page style](https://developer.apple.com/documentation/swiftui/tabviewstyle/page(indexdisplaymode:)).
Use the existing iOS17-compatible selection/tag API.

## Ordered verification

1. Prove the current app cannot swipe to page2 with an isolated XCUITest.
2. Add native paging with per-page vertical scrolling and matching focus.
3. Verify gestures/buttons/selection/account navigation and largest-text scrolling.
4. Inspect phone/compact/light/dark/largest-text layouts, run relevant rendered
   regressions and full signed isolated units; generic Release build/analyzer.
5. Review source/privacy, document evidence, commit/push the source branch.
6. Resume the remaining publishing plan. New binary distribution and live
   acceptance scopes remain separate from this UI source change.

Preserve manual simulator2680E61B-4AAF-4A52-9B42-5C5C36777DC1 and reviewer
simulator84A3A61C-BEF7-463F-B75A-2364FD24BD0B. UI lane is isolated
0966AA82-8FE2-4792-907C-1821CD81361E; signed unit lane is
AB719857-96EE-4391-97E3-D1C434F36635, visibly open with Accessibility enabled.
Use PICKUP_UNIT_TESTS=1 and normal signing for units; blank production client
configuration plus the exact UI isolation launch argument for UI tests.

## Evidence so far

- `testIntroSwipesAndButtonsKeepTheSamePageSelection` failed before the fix at
  page2 selection after Swipe left. `/tmp/pickup-intro-swipe-red.xcresult`.
- Native selection-bound TabView paging now wraps one vertical ScrollView per
  page. Focus is keyed to the page index, including gesture changes; artwork
  reads that page's own sport. Continue/Back/Skip/dots/auth paths are retained.
- Four focused UI scenarios passed on isolated iPhone16e/iOS26.3: new swipe/
  button/return navigation, existing deterministic intro/relaunch, existing
  largest-text account navigation and new largest-text scroll/swipe/action access.
  Results: `/tmp/pickup-intro-swipe-green.xcresult` (3/3) and
  `/tmp/pickup-intro-large-scroll.xcresult` (1/1).
- Inspected exported normal and Accessibility XXXL images. Vertical scroll brings
  the last description line above the page controls while account actions remain
  reachable. Attachments are in `/tmp/pickup-intro-{green,large}-renders/`.
- Full normal-signed isolated units passed **376/376**, with PICKUP_UNIT_TESTS=1,
  unit simulator visibly open and both Accessibility preferences verified1/1.
  `/tmp/pickup-intro-units.{log,xcresult}`. No manual/reviewer simulator was used.
- Generic Release build and analyzer passed in `/tmp/pickup-intro-release.log`.
  Existing unused diagnostic-result and AppIntents warnings remain.
- Independent source review found no substantive issue. The same four scenarios
  passed on compact iPhoneSE3/iOS26.3: `/tmp/pickup-intro-compact.xcresult`,4/4.
  Inspected normal and scrolled Accessibility XXXL images in
  `/tmp/pickup-intro-compact-renders/`: description scrolls, bottom actions remain
  reachable, no horizontal text clipping. An attempted `AppleInterfaceStyle`
  launch override did not produce dark images; that ineffective test option was
  removed. Dark-mode visual verification remains open, not claimed passed.

The compact isolated simulator is87E634A6-A6AF-4062-B1A3-67E6F5780CE1.
Test artifacts stay outside Git. Product source changes require a successor to
uploaded build9; no binary upload, public draft replacement or review is approved
by this source-only UI slice.
