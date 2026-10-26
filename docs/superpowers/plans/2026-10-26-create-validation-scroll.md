# Create: reveal the invalid Other sport name

## Observed problem and contract

The create-draft screenshot from the established iPhone16e UI lane shows the
entire sport grid, Sport name field near the bottom, and no visible empty-name
error after Next. The AX error exists. `firstInvalidScrollAnchor` returns `.sport`,
but that ID belongs to the heading above all 15 sport choices.

Reproduce before editing product: a bounded expectation must require the actual
empty sport-name error to be hittable after Next, without test scrolling. Test
ordinary and largest Dynamic Type using the existing authenticated isolation flag.
Retain failure screenshots. If reproduced, move the existing `.sport` scroll ID
to the custom sport-name field so the existing scroll logic reveals the field and
feedback. No validation rules, text, state, network, layout spacing or flows change.

## Scope and acceptance

- `CreateSessionSportTimeStep.swift`: relocate one existing scroll target.
- `UnauthenticatedSmokeTests.swift`: actual UI visibility regression; add largest
  Dynamic Type variant checking the real accessibility5 marker before actions.
- The empty-name error must become visible after Next without manual scrolling;
  preserve exact error/name/retention/discard assertions.
- No final Create submission, backend fixture, provider or phone action.
- This is simulator viewport evidence, not exhaustive accessibility acceptance.

## Verification

Use the documented credential-free PickUpUCFUISmoke command in the create-draft
plan. Focused red then green on established simulator
2680E61B-4AAF-4A52-9B42-5C5C36777DC1; expanded UI gate, screenshots inspected.
Because product SwiftUI source changes, run relevant CreateSession unit tests,
final signed isolated full unit scheme after restoring AX prerequisites, and
unsigned Release simulator build/analyzer. No unchanged SQL/Edge runs.
Fresh-context adversarial design/final review; update BETA-11/todo/handoff and
commit/push only verified source. Stop at any usage window >=85% used.
Cross-model review skipped under existing autonomous authorization.

## Sources and focused evidence

Apple's [scrollTo(_:anchor:)](https://developer.apple.com/documentation/swiftui/scrollviewproxy/scrollto(_:anchor:))
uses the identified child as the scroll destination. Its
[isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)
check requires an already-visible hit point rather than scrolling to find one.
Official Markdown source retrieved October26; native SwiftUI/XCTest runtime is the
acceptance evidence.

Both actual UI regressions failed the five-second visibility expectation on
unchanged product while exact error existence passed. Normal18.7s/largest21.3s;
`/tmp/pickup-create-scroll-red.{log,xcresult}`. Red video frame at
`/tmp/pickup-create-scroll-red-largest.png` inspected: selected Other, no error
within viewport. No assertion weakening or product fix before red reproduction.

Product diff only relocates the existing sport ID from the heading to the styled
custom-name TextField; all validators/layout spacing and other anchors remain.
Fresh-context design/final source reviews found no required issues. Focused green
2/2 passes, including existing full draft flow and actual accessibility5 error.
Both retained error screenshots inspected: field/counter/complete red error visible
without overlap at normal and largest type. Artifacts:
`/tmp/pickup-create-scroll-focused.{log,xcresult}` and `-focused-attachments/`.
Unsigned Release simulator build/analyzer pass:
`/tmp/pickup-create-scroll-release-analyze.log`.

Expanded credential-free signed UI gate passes **9/9** (196s), including original
unauthenticated/account/tab paths and both create visibility regressions.
`/tmp/pickup-create-scroll-ui-full.{log,xcresult}`. Built URL/key rechecked empty.
UI lane left AX0/0; restored1/1, restarted and verified1/1 before signed full
unit run. Final signed isolated unit suite passes **365/365**, no failures/skips (77s).
All existing CreateSession validation tests pass within that full run; no separate
unchanged focused unit run was needed. AX1/1 verified again afterward. Artifact:
`/tmp/pickup-create-scroll-unit-full.{log,xcresult}`. No SQL/Edge suites repeated.
No production/provider/phone/deployment/upload action. BETA-11 remains partial.
