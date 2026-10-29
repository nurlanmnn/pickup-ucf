# Publishing verification — October 29, 2026

Continuation uses an **80%-used / 20%-remaining** five-hour cutoff, replacing
October 28's 92%-used limit. Never consume reset credits.

## Rendered unit-test environment

Unchanged source at `6d1411c` reproduced all four prior rendered accessibility
lookup failures on the isolated iOS 26.0 simulator while its Simulator window was
not open: `/tmp/pickup-oct29-rendered-red.xcresult` (0/4).
After opening that simulator through the native Simulator app, the identical
selected tests passed 4/4: `/tmp/pickup-oct29-rendered-visible.xcresult`.
The full signed isolated run then passed **374/374**:
`/tmp/pickup-oct29-units-visible.xcresult`, log of the same basename.

This supports a visible-Simulator/accessibility-materialization prerequisite;
the exact internal SwiftUI cause is an inference. No product source or unit
assertions were weakened, removed or skipped. Review independently confirmed that
both failing helpers inspect virtual accessibility children after fixed layout
waits; unrelated controls failed through that shared approach.

For these rendered unit tests, use an interactive unlocked desktop and visibly
open the selected Simulator before the run. Run tests serially, retain its UDID,
and preserve assertion failures if elements remain absent. Use normal simulator
signing and `PICKUP_UNIT_TESTS=1`; never launch a live-account bootstrap as a test
host. This run used `AB719857-96EE-4391-97E3-D1C434F36635`, a separate isolated
simulator. Do not claim this proves headless/CI reliability or physical VoiceOver.
A future headless lane should move actual accessibility interactions to Apple's
[XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation).

## System password prompt regression

The existing account-switch UI test reproduced its timeout waiting for the
system Save Password sheet to disappear after Not Now:
`/tmp/pickup-oct29-account-red.xcresult` (0/1). The earlier October 28 recording
also shows the sheet remaining visibly present. No app authentication submission
was made; all typed values are synthetic.

The test helper now retries only Not Now, at most three times with bounded waits,
then still fails with a screenshot if the sheet remains. It never taps Save or
changes simulator password/settings preferences. Independent code review found
no Required/Critical issue. The same test passed after the helper fix:
`/tmp/pickup-oct29-account-green.xcresult` (1/1).

UI evidence is **14 passing scenarios in the October 28 full run plus the corrected
account-switch scenario passing on October 29**. This is passing coverage for all
15 scenarios, not a claim of a new single 15/15 full run. All four new chat/link
scenarios already passed in that full run. Product source remains unchanged from
the reviewed routing fix. No unchanged passing suites were repeated for reassurance.

## Store and acceptance boundaries

October 29 read-only store inventory still shows build 6 as latest, Complete in
uploads and Ready to Submit in the iOS table, assigned to Internal Testers. No
newer/processing upload was visible. Build 7 can be prepared locally and must be
rechecked before upload. No fields were saved.

A new account banner says the Account Holder must review and accept an updated
Apple Developer Program License Agreement before updating apps/submitting apps.
Owner action was requested while local preparation continued; the agent did not
accept terms or claim this gate cleared.

TestFlight build 6 and the production backend remain unchanged. The routing fix
still needs a separately approved candidate upload/internal assignment and
physical notification retest. No new live fixture is approved; retain October 28's
cancelled fixture. No merge, public/external review, support-site deployment,
provider/account change or store declaration was performed.
