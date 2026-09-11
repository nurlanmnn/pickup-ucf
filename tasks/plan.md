# Implementation Plan: TF-04 User-Facing Error Mapping

## Overview

Complete TF-04 without starting TF-05 or expanding into server-input-boundary work. Make `AppErrorMapper` the safe boundary between repository/Supabase errors and user-facing banners, alerts, load states, and inline feedback. Known failures should remain actionable; unknown or server-controlled details must collapse to safe copy.

## Preserved Prior Work

- TF-02 privacy-manifest implementation remains complete. Archive placement, Xcode privacy-report review, and App Store Connect privacy answers remain open and user-owned.
- TF-03 implementation and agent-owned verification are complete at commit `ab9e67b`: 137/137 iOS tests, 24/24 Deno tests, the complete local SQL/RLS suite, unsigned Release build, and Release analyzer passed.
- TF-03 production migration deployment and physical-device notification/account-switch verification remain open and must not be marked complete.

## Verified Baseline

- Work begins from a clean `main` at `ab9e67b`, matching `origin/main`.
- `AppErrorMapper` currently returns any non-empty `LocalizedError.errorDescription` before inspecting known failures.
- Supabase `AuthError` and `PostgrestError` both conform to `LocalizedError`; their server-provided messages can therefore reach users and bypass existing recovery guidance.
- Existing mapper tests cover a few string-described RPC codes and a generic fallback, but do not reproduce the `LocalizedError` ordering bug, use real Supabase errors, cover wrapped errors, or assert sensitive-detail redaction.
- Repository/service failures displayed by views and view models generally already pass through `AppErrorMapper`. Deliberate form-validation messages remain local and are appropriate.
- Existing domain errors with app-authored copy include auth, session, chat, report, profile, and calendar errors. Generic third-party or arbitrary `LocalizedError` copy is not inherently safe.

## Threat Model and Invariants

- Treat all backend error messages, details, hints, SQL fragments, identifiers, URLs, tokens, credentials, and arbitrary `LocalizedError` descriptions as untrusted.
- Match structured Supabase codes and concrete app-domain error types before any text-based compatibility mapping.
- Text matching may classify known errors for compatibility, but matched raw text is never returned.
- Unknown failures always produce stable generic copy.
- Wrapped errors are inspected through standard underlying-error chains with bounded traversal and cycle protection.
- Cancellation has harmless, non-technical copy and remains suppressed where view models intentionally ignore cancelled work.
- No new logging of raw errors or sensitive values is introduced.

## Phase 1: Characterization and Regression Tests

- [x] Add real `AuthError` tests for invalid credentials, duplicate account, unconfirmed email, expired/invalid verification or reset links, rate limits, session conflicts/expiry, authorization failure, weak password, and unknown server text.
- [x] Add real `PostgrestError` tests for known RPC/domain codes, database conflicts, authorization failures, capacity/waitlist behavior, and unknown SQL/server details.
- [x] Add accurate `LocalizedError` regression coverage proving generic descriptions cannot swallow known mappings or leak unknown text.
- [x] Add nested/wrapped error, networking, timeout, cancellation, validation/domain, and generic fallback tests.
- [x] Run the focused mapper tests and confirm new regressions fail for the expected reason before implementation.

## Phase 2: Centralized Mapping Fix

- [x] Reorder/redesign `AppErrorMapper` around structured types, trusted app-domain errors, bounded unwrapping, safe compatibility classification, and a generic fallback.
- [x] Preserve actionable copy for invalid credentials, duplicate accounts, unconfirmed email, expired/invalid links or codes, connectivity loss/timeouts, session conflicts, full/waitlist states, permission failures, validation, and known domain errors.
- [x] Remove developer/admin remediation from user-facing production copy.
- [x] Keep diagnostics privacy-safe by adding no raw-error logging in TF-04.
- [x] Run focused mapper tests after each meaningful implementation slice.

## Phase 3: Presentation-Path Audit and Full Verification

- [x] Audit every view/view model/repository-error presentation path and centralize any unsafe bypass; retain deliberate field-level validation copy.
- [x] Run all focused error/view-model tests.
- [x] Run the complete iOS Debug simulator test suite.
- [x] Run an unsigned generic-device Release build.
- [x] Run the Release static analyzer.
- [x] Run `git diff --check` and review the final diff for security, correctness, scope, and accidental sensitive logging.
- [x] Update TF-04 readiness boxes and evidence only when supported by completed verification.

## Verification Commands

```sh
cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=<installed-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution -only-testing:PickUpUCFTests/AppErrorMapperTests test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=<installed-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze

cd ..
git diff --check
```

## Verification Results

- Focused tests were red before implementation: real Supabase errors and arbitrary `LocalizedError` values returned raw injected server, SQL, token, and stack-trace-like text; nested networking and cancellation were not classified.
- Focused `AppErrorMapperTests` and `FormValidationFeedbackTests` pass after implementation.
- Complete iOS Debug simulator suite: 149 passed, 0 failed, 0 skipped on iPhone 17 Pro / iOS 26.3.1.
- Unsigned generic-device Release build: passed.
- Release static analyzer: passed with no reported findings.
- `xcodegen generate` completed; its nondeterministic temporary group UUID was restored to avoid unrelated project-file noise.
- `git diff --check` passed, and the final audit found no raw error presentation or sensitive error logging in the iOS target.

## Rollback and Scope

- TF-04 changes are iOS-only and require no database or Edge Function deployment.
- Rollback is the mapper/tests/presentation-path diff only; no persisted data or schema changes are involved.
- Do not change accessibility behavior (TF-05), introduce broad observability (BETA-10), or alter server validation/RPC contracts (BETA-03/BETA-13).

## User-Owned and Unverified

- [ ] TF-02 archive privacy report and App Store Connect privacy answers.
- [ ] TF-03 production migration deployment and sanitized deployment evidence.
- [ ] TF-03 physical-device APNs/account-switch/deletion/Live Activity matrix.
- [ ] Authenticated runtime UI verification if no safe test credentials are available.

## Risks

| Risk | Mitigation |
| --- | --- |
| Useful domain copy is lost by rejecting generic `LocalizedError` | Trust only concrete app-authored domain error types and test each one |
| Supabase server wording changes | Prefer structured `AuthError.errorCode` and `PostgrestError.code`; keep narrow compatibility matching with safe fixed output |
| Wrapped errors bypass classification | Traverse standard underlying-error chains with a depth bound and cycle protection |
| Text classification over-matches sensitive input | Return only fixed allowlisted copy and cover unknown SQL/token/identifier strings with non-leak assertions |
| Cancellation becomes a noisy banner | Preserve existing view-model cancellation suppression and map uncaught cancellation to benign copy |
