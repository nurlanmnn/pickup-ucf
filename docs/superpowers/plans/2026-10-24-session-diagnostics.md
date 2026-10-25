# BETA-10: local session mutation diagnostics

## Objective and assumptions

Implement the first focused BETA-10 slice under the owner's renewed autonomous
source/test/push authorization. No external reporting service, backend changes,
alert recipients, export UI, or new binary upload. This is local operational
logging, not centralized crash reporting or full BETA-10 completion.

Questions: Which session backend operation failed? Did create return its receipt
before the subsequent read failed? Was the failure transport, cancellation,
backend rejection, decoding, or unknown? How long did that boundary take?

## Contract

Use Apple's Logger (iOS 14+, app minimum 17) and fixed JSON fields. Record exactly
one terminal event per attempted create RPC, create follow-up read, update,
cancel, join and leave backend boundary. Generate a fresh UUID per repository invocation;
never reuse game, user or idempotency IDs. Create receipt/read share this ID. These IDs correlate only local events,
not backend traces. Retried operations get new IDs. Log success at info, failure
at error, cancellation at info. Measure elapsed monotonic time in milliseconds.
No started event, raw Error/description, URL, request/response, token, note,
message, coordinates, account/game identity or server-provided code is accepted
by the output schema. Classify errors into a closed enum. Preserve returned
values and original errors, cancellation, request payloads and retry behavior.
Client validation before backend invocation and optional weather enrichment are
outside this slice. A successful create RPC is not whole-workflow success.

Build version/number come only from the bundle, with a numeric-dot allowlist and
length bound. Configuration is debug/release; environment is unit_test/configured
(the latter does not claim production). No persistent session identifier.
The injected sink receives an immutable record; no global mutable test hooks.
Serialization cannot include arbitrary fields. Only that allowlisted JSON is public.

## Structure and implementation order

1. Add failing tests to existing SessionCreationTests using its synthetic SDK
   HTTP fixture: receipt/read failure distinction, safe JSON output and error
   preservation, join/leave/cancel/update terminal outcomes.
2. Add Core/SessionMutationDiagnostics.swift and inject into SessionRepository.
   Style: `try await diagnostics.record(.join) { ... }`; no protocol/dependency.
3. Generate the Xcode project, run focused then full signed isolated tests;
   unsigned Release build/analyzer, inspect actual simulator log output.
4. Review correctness/readability/architecture/security/performance; document
   evidence, commit and push the feature branch. Never run live test bootstrap.

## Commands

From ios/: `xcodegen generate` (preserve unrelated project IDs when reviewing).

```sh
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived test -only-testing:PickUpUCFTests/SessionCreationTests
```

Then omit `-only-testing` for the full suite. Scheme must retain
PICKUP_UNIT_TESTS=1 and the shared denying URLProtocol. Rendered-UI unit tests
require a simulator with application accessibility enabled; the established 16e
lane has it. Do not interpret absent accessibility objects as app navigation
acceptance/failure without checking this prerequisite.

```sh
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pickup-diagnostics-derived CODE_SIGNING_ALLOWED=NO build analyze
```

## Operational/privacy limits

Apple's local unified log has system-controlled retention. Info events may be
memory-only; errors may persist. Local access requires the device or simulator
and tools such as Console/log; there is no automatic tester upload, remote
retention promise, alert, crash-free rate or dashboard. Correlation IDs are not
account IDs and cannot identify a game or prove a server commit if its response
was lost. Do not ask testers for a whole device log: filter subsystem
edu.ucf.pickup, category session_mutation, then review the scoped output before
sharing. Use operation/failure and duration distributions to triage; rates from a
partial local capture are not fleet health metrics. Keep the other BETA-10 tasks
open, including ownership and centralized reporting selection.

Sources: [Apple Logger](https://developer.apple.com/documentation/os/logger),
[generating log messages](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code).
Read Apple's Markdown documentation through tutorials/data/documentation.
No SDK upgrade or Supabase API behavior change is proposed.

## Verification progress

- Initial new-test build failed because SessionMutationDiagnostics did not exist.
- First focused signed isolated simulator run passed 15/15. Actual Logger output
  in its xcodebuild capture contains 17 JSON records; every record matches the
  exact ten-field schema, unit_test environment and nonnegative duration. Observed
  real SDK fixture outcomes include backend/transport create failures, accepted
  receipts, failed/successful reads, update/cancel/join success. No raw errors or
  request identifiers appear in this category's output. This is simulator evidence.
- Direct `simctl log show` was unavailable when Xcode shut down its simulator;
  runtime output was verified from the already-captured test-process Logger
  output instead. No test was repeated solely to collect the same evidence.
- Full final signed isolated suite passes **270/270** on the established iPhone
  16e / iOS 26.3.1 lane. The first full run on the new iPhone17 simulator had four
  rendered-UI accessibility-tree lookup failures (ChatViewModelTests and three
  UXFlowTests), while every diagnostics test passed. Read-only preference comparison
  found ApplicationAccessibilityEnabled/AccessibilityEnabled on the established
  16e lane and absent on the new 17 lane. Running the unchanged final source/tests
  on the established lane passed all four and the whole suite. This is an observed
  environment dependency, not a product fix or proof that every simulator passes.
- Independent initial and final static five-axis reviews found no required findings.
- Unsigned Release simulator build and analyzer both pass. Only existing
  AppIntents metadata notices were emitted; no new source warnings remain.

Artifacts (local, outside Git): /tmp/pickup-diagnostics-red.log,
/tmp/pickup-diagnostics-focused.log, /tmp/pickup-diagnostics-full.log (new-lane
failure), /tmp/pickup-diagnostics-full-16e.log, and
/tmp/pickup-diagnostics-release-analyze.log. Existing Edge/SQL suites were unchanged
and not repeated. No new build is installed on the physical phone or uploaded.

Final full-run Logger capture also passes exact schema/environment/duration checks
for all 12 emitted records.
