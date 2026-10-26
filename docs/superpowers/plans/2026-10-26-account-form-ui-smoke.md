# BETA-11 account-form validation and password draft cleanup

## Contract

Add one credential-free Debug simulator XCUITest through synthetic Profile ->
Settings -> Change password and Edit username. Clear abandoned password drafts
when that screen disappears; no transport/authentication operation changes.
Verify the existing isolation marker before actions. Exercise blank password
feedback, then short new-password and mismatched confirmation while **current
password remains empty**. Assert current-required, minimum length and mismatch
feedback and no success. Return/reopen must start with empty fields.

For username, wait for the actual synthetic existing `ui_smoke` value before
editing. Clear it and assert empty before Save; require the local required error. Enter
`bad!name` and assert that exact invalid value before Save, then assert
the actual local validator error and no success/navigation away. Back/reopen
must refetch the unchanged `ui_smoke`. Never submit a valid username or password,
enter real credentials, sign out or open account deletion. No backend write,
provider, production or physical acceptance is claimed.

Existing Settings moderator/notice requests remain denied by the fixture and
fail closed; no read/write allowances are added. Backend URL/key remain empty.

## Plan and verification

Inspect existing validators/screens before test authoring (completed). Use the existing
launch/tap/attachment helpers in `UnauthenticatedSmokeTests.swift`; no coordinates
or new IDs unless real runtime requires them. Test existing behavior first; do
not assume a defect. Run new test focused, inspect failures without weakening
validators, then expanded documented PickUpUCFUISmoke gate on established16e.
Retain/inspect new screenshot attachments and recheck built empty config.
The reproduced password lifecycle fix also requires focused/final signed isolated
units and Release build/analyzer. No unchanged SQL/Edge suite rerun.
Fresh-context design/final review, update BETA-11/todo/handoff, commit and feature
push verified source. Cross-model review skipped under autonomous authorization.
Stop all work at any usage window >=85% used or required owner input.

## Reproduced password-draft retention; scope correction before product edits

The test-only assumption exposed a real lifecycle problem: after Back to Settings
and reopen, the new/confirmation fields retain the prior five/nine synthetic
characters. Recordings show a completed Settings transition. A bounded old-form
disappearance and five-second reset expectation still failed. A subsequent local
Update (current password explicitly empty) reproduced the previous mismatch error,
proving retained bound draft values rather than only stale SecureField rendering.
Artifacts: `/tmp/pickup-account-form-{focused,settled,binding-red}.{log,xcresult}`;
recording frames `/tmp/pickup-account-form-{return-settings,reopened}.png` inspected.
This establishes newly exposed behavior, not a previously documented guarantee.

Revised scope: add a small `clearPasswordDraft()` method that clears only the three
password strings, invoked when ChangePasswordView disappears. Preserve model
identity, isLoading, repository request, errors/success and completion behavior;
do not cancel/restart the two-stage authentication operation. No raw credentials
or entered values logged. Sensitive draft data should not remain in a cached
navigation destination after leaving it. This reduces retention; it is not secure
memory erasure or a background/app-switcher privacy guarantee.

First write a gated synthetic unit regression: after a valid fake request begins,
clear the draft while pending; assert strings empty, loading remains true, second
submit cannot call the repository, original captured credentials and completion
semantics unchanged. Separate idle local validation must stay denied after clear.
Observe missing-method red before adding product code. Then focused UI proves
reopen blank and local validator uses the cleared model, and continues username
coverage. Add final signed full unit/Release build/analyzer because product source
now changes. Existing HTTP restrictions remain unchanged. No real credential,
provider change, account mutation/deletion/signout or physical action.

## Implementation and focused evidence

`clearPasswordDraft()` clears only current/new/confirmation strings;
ChangePasswordView calls it on disappearance. It deliberately preserves model
identity, loading and original operation completion/results. It does not claim
secure erasure or clearing platform password-manager state. No credential logging.

New gated unit regression initially failed to compile because the method did not
exist (`/tmp/pickup-password-draft-unit-red.{log,xcresult}`). Independent review
caught a harness hang if every duplicate fake call blocked; corrected the gate to
suspend only the first invocation. Final focused FormValidationFeedbackTests9/9
pass, including idle stale-credential rejection and in-flight captured arguments,
loading guard, no overlapping request and original success completion after clear.
Artifact: `/tmp/pickup-password-draft-unit-focused.{log,xcresult}`.
Final fresh-context source/test review found no remaining required issues.
Focused real UI passes1/1 (54s), including cleared placeholders and no old mismatch
when validating the reopened password form; username blank/invalid errors and
unchanged synthetic username after reopen pass. Four screenshot attachments were
exported to `/tmp/pickup-account-form-green-attachments/` and inspected: readable
local errors, usable controls and refetched unchanged username. Secure-field
screenshots do not establish backing-state clearing; field AX values plus the
reopened local-validation assertions do. Artifacts:
`/tmp/pickup-account-form-green.{log,xcresult}`.
Unsigned Release simulator build/analyzer pass at
`/tmp/pickup-password-draft-release-analyze.log`.
Expanded credential-free signed UI gate passes **10/10** (248s):
`/tmp/pickup-account-form-ui-full.{log,xcresult}`. Built backend URL/key rechecked
empty after run. UI lane left AX0/0; restored1/1, restarted and verified1/1 before
final signed isolated full unit run. Final signed isolated full units pass **367/367**, no failures/skips (77s),
including both new gated/local guards and existing auth/Keychain/AX checks.
AX1/1 verified again after the suite. Artifact:
`/tmp/pickup-password-draft-unit-full.{log,xcresult}`.
No unchanged SQL/Edge suites repeated. BETA-11 remains partial: valid backend
updates, provider auth, physical/device/accessibility acceptance and other flows
remain open. No real password/username/account mutation occurred.
