# BETA-10 push account-transition cleanup diagnostics

## Contract and scope

Answer one question at PushNotificationService.unregisterForAccountTransition:
did token cleanup return first try, return after its existing single retry, skip
because no token was captured, or fail leaving server recovery required?
Extend existing DeviceTokenDiagnostics with account_transition_cleanup and four
closed results: no_stored_token, returned_first_attempt, returned_after_retry,
recovery_required. Existing backend operations/results remain unchanged. One
record per completed invocation, after existing state changes and immediately
before returning/rethrowing. Duration starts at entry (includes local cleanup and
waiting for pending registration), fresh local UUID independent of token/account
and repository attempt IDs. Final failure uses existing coarse error categories;
all returned/skipped decisions use none. A cancelled thrown error can still mean
recovery_required; never infer caller intent or remote affected rows.

Preserve exact registration queue, token capture before awaits, local activity/
notification order, single bounded retry even for cancellation, second-error
precedence, retained token/recovery flag and registration guard. No extra awaits,
network calls, cleanup, retry, cancellation handling or registration-policy change.
No claim of whole-account cleanup, APNs delivery, physical state or provider health.
Other registration/quarantine/permission/missing-session decisions are outside this
slice. Use existing ten-field schema/metadata sanitizer/logger and injection in
existing service initializer. No token, user ID, errors/codes/URLs/payloads logged.

## Files and implementation

- Existing Repositories/DeviceTokenRepository.swift: additive operation/results,
  typed cleanup outcome emitter, existing failure classifier reused.
- Existing Core/PushNotificationService.swift: optional diagnostic injection,
  entry attempt and completion calls on original paths, no control-flow refactor.
- Existing PickUpUCFTests/DeviceTokenRepositoryTests.swift: synthetic service and
  actual SDK tests, exact state/order/error and privacy assertions.
- This plan, master BETA-10, todo and launch handoff: evidence and limits.

Use Swift/XCTest and existing style, e.g. `diagnostics.finishCleanup(.noStoredToken,
attempt: attempt)`. First wire sink with no emissions and meaningful red tests,
then minimal emissions. No SDK/dependency/API/database changes.

## Verification and boundaries

Fresh-context adversarial design and final review. Autonomous continuation:
cross-model skipped, no external CLI authorized. Existing session authorizes spec,
source changes/feature push and autonomous verification without new approval.
Red runtime proof; focused existing DeviceTokenRepository/Diagnostics and account
transition tests. Cover no token, first return, retry return, second failure with
original second error (including cancellation), finite exact schema/privacy,
fresh IDs, local/pending-registration order and default Logger actual output.
Full normally signed isolated unit lane, AX checked before/after restart;
unsigned Release build/analyzer. No unchanged UI/SQL/Edge runs.

Commands (from repository root):
```
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -only-testing:PickUpUCFTests/DeviceTokenDiagnosticsTests -only-testing:PickUpUCFTests/DeviceTokenRepositoryTests -only-testing:PickUpUCFTests/AccountTransitionCoordinatorTests -resultBundlePath /tmp/pickup-cleanup-red.xcresult test > /tmp/pickup-cleanup-red.log 2>&1
```
Use fresh focused/full artifact paths, omit only-testing for full unit suite.
Scheme preserves PICKUP_UNIT_TESTS=1, synthetic shared HTTP-denying client and
bootstrap skip. Release: same project/scheme, `-configuration Release -sdk
iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath
/tmp/pickup-ui-release-derived CODE_SIGNING_ALLOWED=NO build analyze`.
Check usage before costly suites and at boundaries; stop at any window >=85% used.
No deployment/upload/production/device/account/provider action.

## Review and focused evidence

Fresh-context design review found no required issue. Sink-only implementation
produced 14 missing-diagnostic assertions across four new runtime tests; existing
state/payload/order/error assertions passed. After minimal completion calls,
focused DeviceTokenDiagnostics/DeviceTokenRepository/AccountTransitionCoordinator
suite passed44/44. Actual focused Logger output:18 device-token records,10 cleanup
records spanning all four finite outcomes; exact ten keys, UUID/duration/privacy
checked separately from test sink assertions.

Final source review found no implementation/privacy violation but two actionable
coverage gaps: no held-wait timing/captured-token test and cancellation not tested
on the first attempt. Added a gated activity plus pending-registration test: no
record before either gate releases, local cleanup precedes queue wait, an APNs
callback during suspension cannot upload, original captured token is unregistered,
completion duration includes both measured holds and state is cleared before
emission. Added first-attempt CancellationError followed by success; preserves
existing retry policy and final returned_after_retry. Default Logger smoke now
covers all four outcomes. Follow-up fresh review found no remaining concrete issue.
Cross-model skipped in this autonomous continuation; no external CLI invoked.

## Final verification

Full normally signed isolated simulator suite passed **347/347** (seven new
runtime tests). Established iPhone16e/iOS26.3.1 AX1/1 read before/after restart
and after full suite. Unsigned Release simulator build and analyzer passed.
Final full actual Logger output:20 device-token records,12 cleanup records; all
four cleanup results present, exact ten-field schema, UUID, nonnegative duration,
finite failure values and privacy exclusions passed. Existing backend results
remain succeeded/failed/cancelled. No unchanged UI/SQL/Edge suites rerun.

Artifacts: /tmp/pickup-cleanup-red.{log,xcresult},
/tmp/pickup-cleanup-focused.{log,xcresult}, /tmp/pickup-cleanup-full.{log,xcresult},
/tmp/pickup-cleanup-release-analyze.log. DerivedData paths remain as above.
No production RPC, device/provider acceptance, deployment/upload/account action.
BETA-10/11 partial: other service decisions, remaining critical flows, reporting,
health metrics and alert ownership remain open. At final verification usage was
44% five-hour/22% weekly used, below owner stop boundary85% used.
