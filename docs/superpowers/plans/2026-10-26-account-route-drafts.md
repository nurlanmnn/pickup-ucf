# BETA-11 Sign In drafts across account route replacement

## Contract

Extend the existing unauthenticated account-switch UI test. It already proves
email carry and route replacement. Type only synthetic Sign In password drafts, never
submit either account form. Switching Sign In -> Sign Up -> Sign In must carry
the email but start the destination's password/confirmation empty; the original
Sign In password must remain discarded after the round trip. After Back to
Welcome and reopening Sign In, the password must again be empty. Do not assume a
product defect before running this against existing source.

Preserve the existing email, navigation and original-form-disappearance checks.
Use bounded disappearance/value expectations so old transitioning forms cannot
satisfy destination checks. Verify the existing isolation marker before actions;
built backend URL/key remain empty, auth/network allowlists unchanged. No valid
auth operation, account/provider update, real credential or phone action.

## Implementation and verification

Only `UnauthenticatedSmokeTests.swift` should change if existing behavior passes.
Use current launch/tap helpers, existing form labels and route IDs. Run focused
test first, then expanded UI gate and retained screenshots inspected. No unchanged
unit/Release/SQL/Edge rerun for a test-only increment. If a real defect reproduces,
write a focused revised scope before product edits and verify the affected code.
Fresh-context adversarial design/final review; update BETA-11/todo/handoff and
commit/push verified source. Cross-model review skipped under autonomous scope.
Stop at any usage window >=85% used or required owner input.

## Initial runtime and review corrections

First focused test proved Sign In -> Sign Up carries email and leaves both
password fields empty, then blocked on a native Save Password? prompt. Retained
screenshot inspected: modal prevents hitting the next field. No account form was
submitted. Artifact: `/tmp/pickup-account-route-focused.{log,xcresult}` and
`-focused-attachments/`.

Use a test-scoped XCTest interruption handler that matches Save Password? plus
Not Now and selects only Not Now; never save credentials or change AutoFill
configuration. Handler is removed on test exit. Apple's
[interruption API](https://developer.apple.com/documentation/xctest/xctestcase/adduiinterruptionmonitor(withdescription:handler:))
is for unrelated asynchronous UI blocking the intended app interaction. Runtime
must prove the handler handles the actual modal before claiming this path passed.

Independent review caught a coverage gap: the returned Sign In password was empty
before Back, so the Welcome reopen assertion could not detect retention. The test
now enters a separate synthetic password before Back to Welcome. Added bounded
old Sign In disappearance before checking Sign Up, alongside the existing bounded
Sign Up disappearance and returned Sign In empty-value expectation.

The interruption handler did not run. AX inspection in the next diagnostic run
identified the native prompt as `Sheet` named Save Password?, containing exact
Not Now and Save buttons. Replaced the ineffective handler with explicit bounded
`app.sheets["Save Password?"]` detection and only Not Now, followed by a bounded
sheet disappearance check. The test checks each possible prompt point (both
account switches and Back to Welcome), and never taps Save. Diagnostic tree
removed from final test source. See Apple's
[direct-workflow distinction](https://developer.apple.com/documentation/xctest/handling-ui-interruptions).
Artifacts: `/tmp/pickup-account-route-{prompt,tree}.{log,xcresult}`.

The first explicit-sheet run repeatedly missed XCTest's app-animation completion
notification (60s waits around keyboard Done/navigation) before reaching prompt
handling. Interrupted and preserved `/tmp/pickup-account-route-sheet.{log,xcresult}`;
runner termination required SIGTERM after TEST INTERRUPTED. Established simulator
restarted, then unchanged focused test retried at
`/tmp/pickup-account-route-restarted.{log,xcresult}`. Do not classify the interrupted
run as a product defect or claim prompt handling passed without runtime evidence.

## Final bounded scope

Native Strong Password cover intercepted Sign Up password entry after the initial
save sheet was successfully declined. Manual confirmation typing failed without
keyboard focus; skipping that entry still could not establish a test-authored
Sign Up password. Review rejected treating a non-placeholder value as proof.
Retained frame `/tmp/pickup-account-route-signup-focus.png` inspected; artifacts
`/tmp/pickup-account-route-{restarted,draft}.{log,xcresult}`.

Final test covers test-authored Sign In drafts only: assert the entered secure
value length matches each synthetic draft before switching or Back. Verify empty
Sign Up password+confirmation, empty returned Sign In password (original draft
still discarded), then type another Sign In draft before Back to Welcome and
verify reopen empty. All original email-carry and route-replacement assertions
remain, with bounded transitions. This adds no claim about manually entering or
discarding a Sign Up password under Strong Password/AutoFill. No platform
configuration or product source changed, and no test-authored Save/Update or auth submission action.

A later retained screenshot showed the native Update Password? variant for the
same synthetic email, rather than Save Password?. Final handler matches only
those two exact sheet titles and taps only Not Now. No AutoFill/keychain settings
are changed or audited; do not infer absence of simulator credential cache from
the test's lack of explicit Save/Update actions. No real provider authentication
or account request is performed; all SDK auth HTTP remains denied.

## Verified focused result

Final bounded Sign In draft test passes1/1 (39s). Actual log records two Not Now
actions; entered secure-value lengths match both synthetic drafts before leaving.
Email carry, empty Sign Up fields, empty returned Sign In, Back-to-Welcome route
replacement and empty reopened Sign In all pass. Two retained screenshots exported
to `/tmp/pickup-account-route-verified-attachments/` and inspected: email preserved,
empty destination password fields and usable account controls. Final independent
review against the narrowed contract found no required findings.
Artifact: `/tmp/pickup-account-route-verified.{log,xcresult}`.
Product source unchanged from6c358b1. Prior367/367 signed
units and Release build/analyzer remain valid and are not repeated.

Final expanded credential-free signed UI gate passes **10/10** (269s), including
the revised route check, authenticated forms/draft/tabs and actual accessibility5
paths. Built backend URL/key rechecked empty. No xcodebuild remains running.
Artifact: `/tmp/pickup-account-route-ui-full.{log,xcresult}`. No repeated
unit/Release/SQL/Edge suites for this test-only change. BETA-11 remains partial;
no real auth/provider/account or physical acceptance is implied. Restore/check
simulator AX prerequisites before any later signed full unit run after this UI gate.
