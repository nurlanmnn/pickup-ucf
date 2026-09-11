# Implementation Plan: TF-03 APNs Token Ownership and Account Cleanup

## Overview

Complete TF-03 without starting TF-04 or broadening into unrelated BETA-09 cleanup. Enforce one current owner per standard APNs token, move ownership changes behind authenticated atomic database functions, retain the last token locally for cleanup/reassignment, and verify database, iOS, and sender behavior. Production deployment and physical-device APNs testing remain user-owned.

## Preserved Prior Work

- TF-02 privacy-manifest work remains complete in commit `6934d39`; the user's processor-scope confirmation was committed separately as `649ab6c` while TF-03 was in progress.
- The readiness checklist preserves the user-confirmed functionality-only use of Supabase, Brevo, Open-Meteo, and APNs.
- TF-02 archive privacy-report review and App Store Connect privacy answers remain open and user-owned after TF-03 through TF-05.

## Verified Baseline

- Work began with the expected uncommitted TF-02 documentation updates. During TF-03, that user-owned state was externally committed as `649ab6c` and advanced both `main` and `origin/main`; TF-03 changes remain uncommitted on top.
- `device_tokens` uses primary key `(user_id, apns_token)`; the same token can therefore belong to multiple users.
- Authenticated users can mutate their own rows directly through `device_tokens_all`; no atomic transfer RPC exists.
- iOS directly upserts `(current user, token)`; its delete method is not called during sign-out or deletion.
- `PushNotificationService` discards the token and errors after registration, preventing reliable retry/cleanup.
- Authenticated bootstrap requests notification authorization and remote registration. No explicit stored-token retry exists.
- Supabase Swift removes its persisted session before the remote logout call, but the profile UI clears `AppState.session` only after a successful return.
- Account deletion relies on FK cascade only after `delete_own_account` succeeds and performs no pre-delete token cleanup.
- `send-push` queries tokens by outbox `user_id` and sends full alert bodies, including chat previews; it already deletes tokens on APNs 410.
- Live Activity tokens already have global uniqueness, authenticated validated registration, strict grants, and cascade cleanup. Their server push contains timing state only, but active local activities should end on account transitions.

## Threat Model and Invariants

- Protect private notification content and correct account/device association across APNs callbacks, authenticated RPC calls, service-role delivery, retries, and account transitions.
- A normalized standard APNs token has at most one row and one current owner.
- Registration derives ownership only from `auth.uid()` and atomically inserts or transfers the token.
- Unregistration deletes only when token and current owner match; delayed user-A cleanup cannot delete a token transferred to user B.
- Sign-out clears local auth/UI state even if cleanup/logout networking fails. The retained token allows a later authenticated registration to repair ownership.
- An offline sign-out cannot be reported instantly to the backend. Local APNs unregistration, local Live Activity teardown, retained retry state, and next-login atomic transfer are the safe fallback; physical-device behavior remains unverified.

## Architecture Decisions

- Add a migration after `20260909000000_live_activity_end_pushes.sql`.
- Normalize historical tokens, remove unusable rows, deterministically keep the most recently updated owner for duplicates, replace the composite primary key with `PRIMARY KEY (apns_token)`, and index `user_id`.
- Add validated `SECURITY DEFINER` RPCs `register_device_token(text)` and `unregister_device_token(text)` with a fixed search path, explicit revocations, and authenticated-only execution.
- Drop broad client table mutation access. The service role retains sender reads and APNs-410 deletion.
- Store the last standard token in app-only `UserDefaults` before registration and retain it across sign-out so the next authenticated account can immediately repair/transfer ownership; token rotation overwrites it. Never log it.
- Add idempotent stored-token registration and account-transition cleanup to the push service.
- Route sign-out/deletion through a testable coordinator that cleans up first and handles local state deterministically.
- Keep notification payload copy unchanged; tests/documentation will establish that chat previews are sensitive and safe only with correct ownership.

## Phase 1: Database Boundary

- [x] Add SQL tests for duplicate ownership, transfer, retry idempotency, validation, anonymous denial, direct-write denial, owner-scoped unregister, and delayed-unregister safety.
- [x] Add the migration with deterministic cleanup, global uniqueness, least-privilege grants, and authenticated RPCs.
- [x] Run focused and complete SQL/RLS suites against a local reset.

**Files:** `supabase/migrations/<timestamp>_secure_device_token_ownership.sql`, `supabase/tests/phase_f_device_token_ownership.sql`, `supabase/tests/run_all.sql`.

## Phase 2: iOS Lifecycle

- [x] Add failing Swift tests for persistence, retry/reassignment, cleanup success/failure, no-token cleanup, sign-out, deletion, and user-A/user-B switching.
- [x] Replace direct table writes with RPCs and add app-only token storage.
- [x] Persist before registration, retry after authenticated bootstrap, and retain failed cleanup state.
- [x] Unregister before sign-out/deletion; clear sign-out UI/auth state even on cleanup/logout failure.
- [x] Preserve deletion failure semantics and clear state after confirmed deletion.
- [x] End local Live Activities and unregister local remote notifications during account transitions.
- [x] Regenerate the project if files are added and run focused Swift tests.

**Files:** device-token repository/service, authenticated/account-transition coordinators, profile sign-out/deletion views, Live Activity manager, and focused tests.

## Phase 3: Sender and Full Verification

- [x] Preserve/test APNs 410 cleanup and current-user token selection for sensitive chat previews.
- [x] Run the full Deno Edge Function suite.
- [x] Run the full iOS Debug simulator suite, unsigned Release device build, and Release analyzer.
- [x] Review tests first, then the implementation for correctness, simplicity, authorization, race safety, migration safety, token redaction, and scope.
- [x] Update TF-03 checklist boxes only where concrete evidence supports completion.

## Verification Results

- Focused TF-03 Swift tests: passed after test-first failures, including the callback/sign-out race regression.
- Full iOS Debug simulator suite: 137 passed, 0 failed on iPhone 17 Pro / iOS 26.3.1 simulator.
- Full Deno Edge Function suite: 24 passed, 0 failed.
- Unsigned generic-device Release build: passed after correcting main-actor warnings; clean rerun passed.
- Release static analyzer: passed with no reported findings.
- SQL/RLS suite: passed on 2026-09-11 after a clean local `supabase db reset`; all phase A-F assertions completed and `phase_f_device_token_ownership: ownership lifecycle OK` was emitted.
- Git whitespace validation: `git diff --check` passed after the final documentation updates.

## Verification Commands

```sh
cd supabase
supabase db reset
psql "<local DATABASE_URL>" -f tests/run_all.sql

cd supabase/functions/send-push
deno test --allow-env --allow-net

cd ios
xcodegen generate
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=<installed-id>' -derivedDataPath DerivedData -disableAutomaticPackageResolution test
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO analyze
```

## Migration Safety and Rollback

- Capture production row, invalid-token, and duplicate-normalized-token counts without returning token values before deployment.
- The migration retains the latest `updated_at` owner; user-id ordering breaks ties. Invalid rows are deleted because APNs cannot deliver to them.
- Installing uniqueness takes a table lock. Capture production size and deploy in a quiet window.
- Do not deploy until a compatible app build is staged: older clients use direct table mutation, which the migration revokes.
- Prefer a forward fix while retaining global uniqueness. Emergency rollback can restore owner-scoped direct writes and the composite key, but that reopens the security leak and requires disabling notification delivery until corrected.

## User-Owned and Unverified

- [ ] Authorize/deploy the reviewed migration with the compatible build staged.
- [ ] Provide sanitized preflight/post-deployment counts and grant/constraint evidence.
- [ ] Complete the physical-device matrix for token rotation, account switching, offline cleanup, deletion, APNs 410, notification previews, and Live Activity teardown.
- [ ] Report build/commit, migration version, device/iOS versions, account labels, timestamps, recipient result, and redacted evidence.

## Risks

| Risk | Mitigation |
| --- | --- |
| Historical dedupe retains an older owner | Keep latest deterministically; compatible app immediately transfers on registration; require preflight and device switching test |
| Older app cannot write after grant revocation | Stage compatible build before migration; do not deploy in this task |
| Offline sign-out leaves server unaware | Retain retry state, unregister locally, end activities, and atomically transfer on next login |
| Delayed A cleanup races B registration | Delete only when `user_id = auth.uid()` and token matches |
| APNs token rotates | Persist/register every callback and retain Edge Function 410 cleanup |
| Migration encounters dirty data/lock pressure | Preflight counts, quiet-window deployment, and prepared forward-fix/rollback SQL |
