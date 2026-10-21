# Local beta readiness and newest-message chat

## Scope and boundaries

The release owner deferred deployment on October 14, 2026 and authorized remaining local work. Preserve the existing venue edits. Do not deploy, upload, submit, invite testers, commit, or push. TF-06's October 4 owner attestation remains valid; later notification changes need their own candidate-device checks.

EXT-01's source implementation already exists. Verify it locally and distinguish those results from its production/device/age-rating gates. Complete the next source workstream, BETA-01, without requiring a backend migration.

## Contract

- Open chat on the newest 50 visible messages, displayed chronologically.
- Fetch older pages using descending `(created_at, id)` keyset ordering; preserve the exact server timestamp in the cursor, including microseconds.
- Show a load-older control with loading/error/retry states. Prepending history preserves the visible message; it must not trigger the scroll-to-latest behavior.
- Merge page, realtime, and send results by message ID in deterministic chronological order. Keep block filtering, existing history, and retry cursors intact after errors.
- Use the existing RLS-protected messages endpoint; no new privileged RPC, dependency, or production data change.

## Tasks and acceptance

1. **Repository query** (`ChatRepository.swift`, repository tests): reproduce the oldest-50 defect, then add newest-first keyset queries and a page cursor. Verify 0/1/50/51/301 messages, timestamp ties, and microseconds through the real Supabase request/decoder boundary with synthetic responses.
2. **Chat state** (`ChatViewModel.swift`, view-model tests): load and prepend pages, retain retry state, prevent overlapping loads, and merge realtime/send results without duplicates. Verify blocked rows, failed pages, realtime inserts during a page request, and optimistic-send reconciliation.
3. **Chat view** (`ChatView.swift`): accessible load-older and retry controls; preserve the reading position when older rows arrive. Compile and verify in a simulator using synthetic data if available; keep device verification separate.
4. **Verification and handoff**: full iOS tests, unsigned Release build/analyzer, existing Deno and local SQL/RLS suites. Reconcile readiness, moderation operations, and reviewer known limitations. Record exact results and unresolved gates.

Dependencies: task 1 precedes 2; task 2 precedes 3; all precede final evidence updates. Existing tests and safeguards remain enabled.

## Task checklist

- [x] Repository regression demonstrated red, then green.
- [x] Pagination, errors, filtering, and concurrent insert/send state tests pass.
- [x] Load-older UI compiles and runtime scroll behavior is verified through the actual accessibility button on the iPhone 16e / iOS 26.3 simulator.
- [x] Complete iOS, Deno, SQL/RLS, Release build/analyzer, and diff checks recorded.
- [x] Readiness and external handoff documentation updated with evidence boundaries.

## Rollback and risks

Rollback is source-only: restore the chat changes without touching the pre-existing venue edits. No schema or data rollback is required. An exact timestamp cursor avoids dropping rows sharing a second/millisecond. Keyset pagination avoids offset drift when new messages arrive. Realtime remains best-effort; reopening reloads the latest page. Production APNs, accessibility on physical devices, and the final external candidate remain release gates.

## Sources

- Supabase Swift [ordering](https://supabase.com/docs/reference/swift/order) and [OR filters](https://supabase.com/docs/reference/swift/or), checked October 14, 2026; checked installed SDK query/URLSession APIs as well.
- Supabase changelog index checked October 14, 2026; no relevant query API breaking change identified. No SDK update is included.

## Verification notes — October 14, 2026

- The original query failed the 51-message regression by returning messages 1–50 instead of 2–51. The fixed query passes; the request/decoder tests cover 0/1/50/51/301 messages, equal timestamps, exact microseconds, and a new insert between pages. These use synthetic HTTP responses, not production chat.
- Eight state tests cover failure/retry cursor retention, blocked pages, blocking during a request, duplicate/out-of-order realtime rows, a realtime echo before the send response, and overlapping history loads.
- A rendered SwiftUI test reproduced a separate scroll defect. Calling `scrollTo` immediately after fetching used the old layout. The view now captures the anchor before fetching and restores it on a separate view-state update after receiving the older rows. The test activates the actual accessible button and verifies that the viewport offset increases by the inserted history height, within one normal row. Physical-device/VoiceOver operation remains separate.
- The existing local PostgreSQL database already contained the two October notification migrations, with head `20261005150000`. The full SQL/RLS suite passed with 24 phase success notices inside explicit `BEGIN`/`ROLLBACK`; this was not a clean database reset and did not apply the separate pending venue migration.
- The Deno suites passed 36/36 using `deno test --node-modules-dir=auto --allow-env --allow-net` with all three test files. Deno needed its automatic dependency resolution; no project dependency manifest or lockfile was changed.
- Final full iOS suite: **202/202 passed**, no failures or skipped tests, on iPhone 16e / iOS 26.3. Result: `ios/DerivedData/Logs/Test/Test-PickUpUCF-2026.10.14_21-26-33--0400.xcresult`. The 12 new chat tests include the rendered regression.
- Final unsigned generic-device Release **build and static analyzer passed**. The only emitted metadata warning says no AppIntents framework is used; no application compiler/analyzer warning was emitted. App/widget build numbers remain **4**; XcodeGen's unrelated build-number reset was restored immediately.
- Exported normal and Accessibility XXXL synthetic chat screenshots plus scroll metrics to ignored `docs/testflight-evidence/beta-01/`; visually reviewed both. Messages wrap and the composer remains visible. This is a short synthetic-text simulator check, not a full VoiceOver, device, or arbitrary-content accessibility sign-off. The normal-size scroll metric moved from -101 to 3913.67 points after adding 4008 points of content, preserving the original row within one normal row's height.
- Reviewed the final tests and implementation for correctness, readability, boundaries, security/privacy, and performance; `git diff --check` passed. No new database privileges, public service, production data, dependency version, commit, push, upload, or deployment was introduced. Existing venue files were preserved.

## Handoff

BETA-01 is complete in local source. The next source workstream in the master sequence is **BETA-02: atomic session creation**. BETA-08 reconnect/foreground catch-up remains separate from this pagination change.

Before external submission: deploy the pending notification migrations/function and any approved venue migration in dependency order, create the updated internal candidate, perform exact-candidate/two-device checks, finish production role/email/push/deletion/recovery evidence, assign operational coverage, complete age-rating/metadata, and pass EXT-06. The chat fix itself needs only the updated app build. No production or App Store Connect state was re-audited in this work.
