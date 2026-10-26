# BETA-11 local create-draft smoke

## Contract

Extend the existing credential-free Debug simulator XCUITest suite with one real
authenticated Create-sheet path. Verify isolation before actions. Select Other,
prove Next rejects an empty sport name, enter a synthetic name, choose In 2 hours,
and advance to location. Existing fixture venues are empty: assert the empty
venue hint and missing-pin validation, then Back preserves the sport name.
Close a dirty draft, cancel the confirmation preserves it, then Close/Discard returns to
Discover. Reopen Create and explicitly select Other to prove the discarded name
is absent. Never tap final Create session, select a map pin, or change transport.

This is navigation/local-validation/discard evidence, not successful creation,
details-step, map/provider, auth, physical-device or production acceptance.
No product defect is presumed; this adds regression coverage of existing behavior.

## Implementation and validation

Only `ios/PickUpUCFUITests/UnauthenticatedSmokeTests.swift` should change, using
existing bounded tap/launch/attachment helpers and actual accessibility labels.
Add stable IDs only if runtime proves existing labels ambiguous. No dependency,
configuration, fixture, backend allowance, submission or persistence change.

Run focused new test first, inspect actual failure if any; preserve assertions.
Then expanded UI gate with empty backend config and retained screenshots:

```sh
xcodebuild test -project ios/PickUpUCF.xcodeproj -scheme PickUpUCFUISmoke \
  -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' \
  -parallel-testing-enabled NO SUPABASE_URL= SUPABASE_ANON_KEY=
```

Inspect screenshot exports and built Info.plist URL/key. Test-only source leaves
prior 365/365 signed units and Release/analyzer evidence unchanged; don't rerun.
Check/restore simulator AX prerequisites before a later full unit lane.
Fresh-context adversarial design/final review, docs, commit and feature push.
Cross-model review remains skipped per renewed autonomous authorization.
Stop all work at any usage window >=85% used or required owner input.

## Runtime investigation and resumed verification

Initial unscoped Other query resolved the hidden Discover filter behind the sheet.
Recording/AX tree confirmed the visible Create Other control; scope now uses the
scroll view containing What are you playing. Initial artifacts:
`/tmp/pickup-create-draft-focused.{log,xcresult}` and `-tree.{log,xcresult}`.
Scoped run passed sport/missing-pin validation and Back name retention, then
failed looking for Keep editing: actual iOS26 popover hides the cancel-role button
and presents only Discard. Screenshot inspected. Test now taps the draft field
outside the popover and waits for Discard disappearance before retention checks.
This exercises cancelling the confirmation, not an absent Keep editing button.
Scoped artifacts: `/tmp/pickup-create-draft-scoped.{log,xcresult}`, exported PNGs
in `/tmp/pickup-create-draft-scoped-attachments/`. No product defect/fix claimed.

The first expanded gate failed on semantic field tapping: XCTest correctly treats
that field as blocked by the modal. The run was interrupted when usage reached86%
(previously84% at the last check). No commit/push occurred. On October26 the owner
renewed work after reset, retaining the15%-remaining stop threshold. The test now
uses the field's visible center as an outside-popover coordinate; it still requires
Discard disappearance and the exact draft name before proceeding. Fresh-context
review of this final change found no required issues.

Resumed focused test passes1/1 in53s on the established simulator. Four retained
screenshots exported to `/tmp/pickup-create-draft-resumed-focused-attachments/`
and inspected: expected sheet, location error, discard prompt and reset name.
The empty-sport error exists in AX but is below the captured viewport; this test
asserts validation existence, not visible error presentation. That observation is
tracked separately in the October26 validation-scroll plan before a product fix.
Map tiles render through platform MapKit; the Supabase HTTP deny/allowlist contract
is unchanged. This does not claim all device networking is intercepted.

Artifacts: `/tmp/pickup-create-draft-resumed-focused.{log,xcresult}`;
expanded gate `/tmp/pickup-create-draft-resumed-full.{log,xcresult}`.
Built Debug app Info.plist backend URL/key separately verified empty.
Previous product365/365 and Release/analyzer remain unchanged; no repeated suites.

Final expanded credential-free signed UI gate passes **8/8** (173s), including
prior accessibility5 and synthetic tab paths. Built URL/key rechecked empty after
run. Final independent review reports no required findings. No product source
changed; no unit/Release/SQL/Edge suite repeated. BETA-11 remains partial.
