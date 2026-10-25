# Critical-auth local diagnostics — October 24

## Objective and contract

BETA-10 needs evidence distinguishing explicit authentication failures from
password-write failures without collecting credentials or identities. Add a
closed local Apple Logger category `auth_operation`, following the existing
session diagnostic contract. Normal SDK requests, ordering, returned values,
original thrown errors and cleanup must remain identical.

Explicit operations: sign-up, sign-in, sign-out, resend verification, verify OTP,
password reset request, password update, change-password reauthentication and
change-password update, and accepted deep-link exchange. A change-password call
shares a fresh attempt ID across its two steps; failed reauthentication emits no
update event. Each retry gets a new ID. Resend's alias emits only one record.
Sign-up's local display-name validation remains before backend instrumentation;
invalid callback routes remain rejected before exchange instrumentation. Current
session restoration and its offline fallback are deferred.

Every event has exactly event/operation/result/failure/attempt_id/duration_ms/
version/build/configuration/environment. Only closed enum values, ephemeral fresh
UUIDs, monotonic duration and validated numeric bundle strings are serialized.
No email, password, OTP, token, user ID, URL, input, raw Error, server error code,
localized description or SDK payload may enter a record. Coarse failures are
cancelled, transport, backend (AuthError), decoding, local policy, or unknown.
Success records appear only after original mapping/guards/cleanup finish.

## Diagnostic questions and threat model

1. Which explicit auth operation failed, and was the coarse cause transport,
   SDK/backend, local policy, decoding or cancellation? Operation/failure answer it.
2. Did change-password fail while reauthenticating or after the password write
   started? Shared attempt IDs and separate stage records answer it.
3. How long did an observed operation take, and which build/configuration ran it?
   Duration and build fields answer this for captured local events only.

The trust boundary is untrusted input/SDK errors entering local unified logs.
Sensitive assets are credentials, callback codes, tokens and identities. Abuse
case: server errors embed credential/URL text; typed classification must discard
all that text. The diagnostic type accepts no metadata dictionary/string input.
Fresh correlation UUIDs cannot be caller-chosen account/request IDs. Existing
normalization, confirmation checks, cleanup, callback allowlist and SDK request
ordering stay intact. No new trust/authorization policy is introduced.

## Implementation and validation

1. Add failing XCTest coverage with synthetic SDK HTTP fixtures and injected
   capture sink; no live bootstrap, persistent auth storage or refresh timer (locked in-memory
   storage permits SDK multi-step sessions without Keychain).
2. Add AuthOperationDiagnostics and wrap explicit repository boundaries; avoid
   refactoring the session diagnostic category or altering auth policy.
3. Verify mapped sign-in and OTP results; original SDK/local errors; request
   normalization; recovery redirect; two-step change-password ordering and IDs;
   alias single emission; privacy schema and all coarse failure classes.
4. Run focused signed tests, then signed full suite on the established 16e lane
   with accessibility prerequisites. Inspect actual Logger output. Review final
   source/test diff independently, then unsigned Release build/analyzer.
5. Update readiness/handoff, commit and push the authorized feature branch.

Source: ios/PickUpUCF/Core/AuthOperationDiagnostics.swift and
Repositories/AuthRepository.swift. XCTest: AuthOperationDiagnosticsTests.swift.
Use the same Swift conventions as SessionMutationDiagnostics (typed record and
`async rethrows` wrapper). No dependencies, provider, alerts or remote upload.

```sh
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -parallel-testing-enabled NO test -only-testing:PickUpUCFTests/AuthOperationDiagnosticsTests
```

Full suite omits only-testing; retain PICKUP_UNIT_TESTS=1 and normal signing.
Release: same project/scheme, -configuration Release -destination
'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build analyze.

## Boundaries and operational use

Continue only source/local synthetic work and authorized branch push. No merge,
deploy, configuration, upload, credential changes or live account mutations.
Local logs have system-controlled retention; info may be memory-only. Filter
subsystem edu.ucf.pickup/category auth_operation before reviewing/sharing. A
successful password-reset request does not prove email delivery; a callback
exchange success does not prove physical universal-link acceptance. This slice
cannot supply centralized auth failure rates, crash reporting or alert ownership.
BETA-10 stays open; provider/device/release acceptance remains separate.

## Evidence

- Initial red: the new test target failed to compile because the diagnostic type
  and injectable repository parameter did not exist (`/tmp/pickup-auth-red.log`).
- The first implemented run exposed fixture errors: discard-only storage removed
  SDK sessions needed by multi-step calls; absent API-version header mapped
  server codes to unknown; SDK transport retry made an exact HTTP-count assertion
  invalid. Tests now use locked in-memory storage and the supported API header,
  and assert no write request after failed reauthentication regardless of SDK retry.
  Product assertions/policy were preserved.
- First corrected focused suite passes 12/12. Four additional cleanup/callback/
  OTP-policy edge tests then pass in the final focused **16/16** signed isolated
  simulator run. `/tmp/pickup-auth-verified.xcresult` and matching `.log` retain it.
- Runtime default Logger failure output in the focused run contains one auth JSON
  record; exact ten-field schema, unit_test environment, nonnegative duration and
  exclusion of supplied secret/error strings were checked. Injected sinks cover
  all operation labels and coarse outcomes without relying only on log parsing.
- Fresh-context independent design and final source/test/privacy review found no
  required issues. No cross-model review was run; optional owner offer is pending.
- Before full unit run, read-only established simulator checks returned 1/1 for
  ApplicationAccessibilityEnabled/AccessibilityEnabled; simulator restarted.
- Full signed isolated unit suite passes **289/289** on established iPhone16e /
  iOS26.3.1, including the existing real-Keychain auth persistence/cleanup and
  rendered-UI tests. `/tmp/pickup-auth-full.xcresult` and matching `.log` retain it.
  All 6 full-run auth Logger records pass exact schema/environment/duration
  and credential/raw-error exclusion checks.
- Unsigned Release simulator build and analyzer both pass. Only the existing
  AppIntents metadata extraction notice appeared. Log:
  `/tmp/pickup-auth-release-analyze.log`; derived data `/tmp/pickup-ui-release-derived`.
- A separate fresh-context final reviewer also found no required issues. Project
  plist and git whitespace validation pass. Unchanged UI/SQL/Edge suites were not
  repeated for this Swift-only diagnostic change.
- Source-only evidence. No live requests, phone changes, SQL/Edge changes,
  deployment, upload, external provider or account mutation occurred.
