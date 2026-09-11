# TF-03 Task Checklist

## Preserved TF-02 Follow-up

- [x] Record the user-confirmed functionality-only processor use in the readiness checklist.
- [ ] Generate/review the final archive privacy report (user-owned after TF-03 through TF-05).
- [ ] Confirm/publish matching App Store Connect App Privacy answers (user-owned).

## Database Ownership Boundary

- [x] Add a SQL regression for duplicate ownership; the final suite passes against a clean local reset.
- [x] Normalize/deduplicate existing rows and make `apns_token` globally unique.
- [x] Add authenticated atomic registration/transfer and owner-scoped unregistration RPCs.
- [x] Revoke broad RPC/table rights and grant only required roles.
- [x] Test retries, validation, anonymous/direct-write denial, transfer, and delayed-unregister safety.
- [x] Run the full local SQL/RLS suite.

## iOS Token Lifecycle

- [x] Add Swift regression tests before implementation.
- [x] Store the last APNs token locally without logging it.
- [x] Register/transfer after callbacks and authenticated bootstrap.
- [x] Retain the token on failures so later retries repair state.
- [x] Unregister before sign-out and account deletion.
- [x] Clear local auth/UI state on sign-out despite cleanup/logout failures.
- [x] Preserve deletion failure semantics and clear state after confirmed deletion.
- [x] End local Live Activities and locally unregister remote notifications.
- [x] Cover user A → sign out → user B → same token.

## Sender and Verification

- [x] Preserve/test APNs 410 cleanup and current-owner delivery for chat previews at the unit boundary.
- [x] Run the full local SQL/RLS suite after a clean local database reset.
- [x] Run full Deno suite (24/24) and full SQL/RLS suite (all phase A-F assertions passed).
- [x] Run full iOS Debug tests (137/137), unsigned Release build, and Release analyzer.
- [x] Review correctness, security, concurrency, migration safety, secrets, and scope.
- [x] Update only evidence-supported TF-03 readiness boxes.

## User-Owned / Must Remain Open

- [ ] Authorize and deploy the production migration.
- [ ] Provide sanitized production preflight/post-deployment evidence.
- [ ] Complete the physical-device APNs/account-switch/deletion/Live Activity matrix.
- [ ] Confirm the TestFlight build and production migration version used.
