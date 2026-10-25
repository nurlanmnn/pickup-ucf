# BETA-10 push registration service decisions

## Contract

Instrument the actual PushNotificationService stored-token and APNs callback
entry points so local logs distinguish callback suppression, no stored token,
registration return after recovery clearing, and failure after quarantine/local
unregister. One completion record per invocation after existing state changes.
Use existing DeviceTokenDiagnostics ten-field schema, metadata sanitizer and
coarse error classifier. Two finite operations: stored_token_registration and
apns_callback_registration. Results: no_stored_token, registration_suppressed,
registration_returned, registration_quarantined. Only quarantined carries a
coarse failure; cancellation still means quarantine, not caller intent.

Fresh non-entity attempt UUID and monotonic duration start at entry, including
queue wait and ignored previous-token unregister. No tokens, IDs, raw errors,
server codes, URLs or payloads. No registration-policy/permission/lifecycle change.
Preserve token persistence before callback guard, stored-token enabling before
nil guard, captured token, exact serial task chain, no guard recheck inside queued
work, ignored rotation cleanup errors, recovery clearing and quarantine ordering.
No extra awaits, RPCs, retries or fallback changes. Backend stage return and
service decisions do not prove APNs delivery or physical/provider acceptance.

## Implementation and verification

Existing Core/PushNotificationService.swift: entry attempt and completion calls.
Repositories/DeviceTokenRepository.swift: closed source/outcome types and emitter.
PickUpUCFTests/DeviceTokenRepositoryTests.swift: synthetic real-service/SDK red
tests, ordering/state/privacy, rotation errors, queue wait and guard behavior.
Swift style: `diagnostics.finishRegistration(.returned, source: .storedToken,
attempt: attempt)`. No dependency/API/database changes.

Fresh-context adversarial design/final review via doubt-driven skill. Cross-model
skipped per autonomous continuation; no external CLI. Existing human instructions
authorize spec, local source changes, tests and feature-branch push without another
approval. Focused red then green DeviceTokenDiagnostics/Repository/AccountTransition
tests; final normally signed full isolated units, AX prerequisites checked around
restart and suite; unsigned Release build/analyzer; actual default Logger JSON.
No unchanged UI/SQL/Edge suites. Update master/todo/handoff with exact limits.

Commands from root (fresh artifact paths per run):
```
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -only-testing:PickUpUCFTests/DeviceTokenDiagnosticsTests -only-testing:PickUpUCFTests/DeviceTokenRepositoryTests -only-testing:PickUpUCFTests/AccountTransitionCoordinatorTests -resultBundlePath /tmp/pickup-registration-red.xcresult test > /tmp/pickup-registration-red.log 2>&1
```
Omit only-testing for full units. Scheme keeps PICKUP_UNIT_TESTS=1, bootstrap skip
and synthetic shared HTTP denial; normal simulator signing required for Keychain.
Release uses same project/scheme, -configuration Release -sdk iphonesimulator
-destination 'generic/platform=iOS Simulator' -derivedDataPath
/tmp/pickup-ui-release-derived CODE_SIGNING_ALLOWED=NO build analyze.
Check usage before costly suites/continuation and at major boundaries; stop all
work if any window usedPercent >=85 or human input is required. No deployment,
merge, upload, production account/provider action, or Mirroring polling.

## Review and focused evidence

Design review found a severity coupling: new registration_quarantined must join
failed/recovery_required at logger.error. Implemented and verified actual unified
log messageType Error (four focused quarantine records). No other design finding.
Initial five tests failed 18 missing-record assertions; existing state/request/
order assertions passed. Minimal emitters plus two queue/default-Logger tests pass
focused53/53. Cleanup-specific sinks now filter account_transition_cleanup before
asserting cleanup state/order, since service also emits registration decisions.
No cleanup assertions removed. Focused actual Logger48 device-token records,
28 registration records cover all four results; exact schema/privacy checked.

Final review found one test timing flake: lower-bound clock originally preceded
callback Task scheduling. Moved it after observed callback persistence/queue entry,
before the held interval. Corrected before full-suite compilation. Gated test
proves no early emission, captured previous-token rotation cleanup remains ignored,
already-queued work proceeds after earlier quarantine, queued success clears
recovery but does not re-enable guard, later callback persists and is suppressed.
Cross-model remains skipped; no external CLI.

## Final verification

Follow-up fresh-context review found no remaining issue after the timing correction.
Final normally signed isolated full suite **358/358**, seven new runtime tests;
AX1/1 before/after simulator restart and after full suite. Unsigned Release build
and analyzer pass. Final actual Logger48 records,28 registration decisions, all
four outcomes present; exact ten keys, UUID, nonnegative duration, finite failures
and privacy exclusions pass. No unchanged UI/SQL/Edge rerun. Artifacts:
/tmp/pickup-registration-{red,focused,full}.{log,xcresult},
/tmp/pickup-registration-release-analyze.log, /tmp/pickup-registration-unified.ndjson.
BETA-10/11 remain partial; source push is not deployment, provider or device proof.
