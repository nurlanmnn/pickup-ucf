# BETA-10 account deletion RPC diagnostics

## Contract

Instrument only ProfileRepository.deleteAccount's existing parameterless
`client.rpc("delete_own_account").execute()` boundary with existing
AuthOperationDiagnostics operation `delete_own_account_rpc`. It is an account/auth
operation; do not create another schema. One fresh UUID and monotonic duration
per invocation. Same ten fields, succeeded/failed/cancelled and coarse failures.
Succeeded means only the RPC returned, not account disappearance, local sign-out,
retained/anonymized data verification or physical acceptance. Cancellation means
observed thrown category, not an inference of caller intent.

Preserve exact RPC/method/empty body, Void and original SDK errors; no guard,
retry, session lookup, fallback, recovery, auth cleanup or coordinator/view change.
No account ID, request/response payload, raw Error, codes, URLs or user content
logged. Existing metadata privacy remains. Injection defaults in ProfileRepository
initializer; other profile operations get no records or altered requests.
AuthOperationDiagnostics.failure classifies PostgrestError as backend alongside
AuthError, retaining every existing category/precedence. Existing auth operations
use Auth SDK errors; add direct classification/error-identity coverage as needed.
No dependency/API/SQL/production action or live deletion query.

## Implementation and verification

Existing files: Repositories/ProfileRepository.swift, Core/AuthOperationDiagnostics.swift,
PickUpUCFTests/AuthOperationDiagnosticsTests.swift. Use existing Swift/XCTest,
real pinned SDK, ephemeral synthetic URLProtocol and in-memory auth storage.
First injectable sink/operation without emission; red missing-record assertions
must preserve exact RPC/no extra request behavior. Cover repeated success/fresh
UUIDs, backend policy and missing-RPC errors with no fallback, transport and
cancellation, default Logger succeeded/failed and exact ten-key privacy assertions.
Reuse existing auth/privacy helper without widening production test transport.
Existing account-transition tests retain ordering/restoration behavior.

Fresh-context adversarial design/final reviews. Cross-model skipped for autonomous
continuation; no external CLI. Focused AuthOperationDiagnosticsTests,
AuthRestorationDiagnosticsTests, AccountTransitionCoordinatorTests; full normally
signed isolated unit suite on established iPhone16e with AX1/1 before/after restart,
unsigned Release build/analyzer. Actual Logger JSON parsed separately. No unchanged
UI/SQL/Edge suites. Update master BETA-10/todo/handoff and feature commit/push.
Stop at any applicable usage window >=85% used; never consume reset/credits.

Commands from repo root, fresh paths for red/focused/full:
```
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -only-testing:PickUpUCFTests/AuthOperationDiagnosticsTests -only-testing:PickUpUCFTests/AuthRestorationDiagnosticsTests -only-testing:PickUpUCFTests/AccountTransitionCoordinatorTests -resultBundlePath /tmp/pickup-deletion-red.xcresult test > /tmp/pickup-deletion-red.log 2>&1
```
Omit only-testing for full. Release same project/scheme with `-configuration Release
-sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath
/tmp/pickup-ui-release-derived CODE_SIGNING_ALLOWED=NO build analyze`.
Scheme retains PICKUP_UNIT_TESTS=1, synthetic shared HTTP denial/bootstrap skip.

Official RPC docs and pinned supabase-swift2.46.0 PostgrestClient.rpc inspected:
https://supabase.com/docs/reference/swift/rpc . Changelog index refreshed; October12
TLS CBC deprecation and September25 database minor-release notices inspected; no
RPC API migration required for this additive local instrumentation. No production
compatibility or TLS/database deployment acceptance claim.

## Focused evidence and review

Fresh-context design review found no concrete issue. Initial red run revealed two
incorrect test assumptions: pinned SDK NoParams intentionally sends no body and
its PostgrestError leaves the wire's plural details field unmapped. SDK source and
runtime observations confirmed both; assertions corrected without product changes.
Corrected red:10 missing-record assertions, no unexpected failures; payload/error/
no-fallback behavior passed. Artifacts /tmp/pickup-deletion-red-corrected.{log,xcresult}
retain isolated red evidence; /tmp/pickup-deletion-red.{log,xcresult} is the initial
fixture-assumption run, not clean missing-record-only evidence.

Minimal wrapper plus PostgrestError backend classification yielded focused38/38
(AuthOperationDiagnostics20, restoration11, account-transition7). Final review
found one actionable test issue: an arbitrary numeric-code substring search in
complete JSON can match a valid random UUID. Removed that redundant search; exact
schema keys/typed enums and sensitive-content assertions remain. Applied same
one-line correction to the cleanup helper newly added in f4d8ca3. Follow-up review
found no remaining issue or privacy assertion weakening. Full signed suite includes
these test corrections. No external CLI/cross-model review invoked.

## Final verification

Final normally signed isolated full simulator suite **351/351**, no skipped tests
or failures (xcresult summary independently read). Established16e AX1/1 verified
before/after restart and after suite. Unsigned Release simulator build/analyzer
passed. Actual focused Logger4 auth records/full12 auth records each include2
account-deletion records: succeeded/none and failed/backend. Exact ten keys,
UUID/nonnegative duration/unit_test environment and sensitive-content checks pass.
No unchanged UI/SQL/Edge suite rerun. No live RPC/account/device/provider action.

Artifacts /tmp/pickup-deletion-focused.{log,xcresult},
/tmp/pickup-deletion-full.{log,xcresult}, /tmp/pickup-deletion-release-analyze.log;
red artifacts above. DerivedData /tmp/pickup-diagnostics-derived and
/tmp/pickup-ui-release-derived. Broader BETA-10/11 reporting/metrics/alerts and
production/physical lifecycle acceptance remain open.
