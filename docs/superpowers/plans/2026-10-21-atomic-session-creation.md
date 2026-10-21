# BETA-02 — Atomic session creation

Scope: complete the next local source workstream from the TestFlight readiness checklist after the UX audit. Preserve the existing uncommitted UI, chat, venue, and operations work. Do not commit or distribute a build in this workstream.

## Contract and sequence

1. Add a transaction-backed `public.create_session(p_request_id uuid, p_input jsonb)` RPC returning the created session ID. A security-invoker public entry delegates to a narrowly granted private definer function. Derive the host from `auth.uid()`; require a confirmed UCF account, an existing profile, and no suspension. Validate sport, schedule (future and within seven days), duration (15–300 minutes), capacity (2–50), skill, location coordinates/name, custom sport, content bounds, and optional weekly recurrence.
2. Keep an inaccessible private idempotency ledger keyed by host and request UUID. Store only a SHA-256 fingerprint, not duplicated game text or coordinates. Serialize concurrent retries with a transaction advisory lock. A matching retry returns the original session even if the game has since changed; a changed payload is rejected. A deleted session leaves a tombstone rather than being recreated. Insert the session, joined host membership, and ledger together; failures roll everything back.
3. Retain one request UUID for the lifetime of each create form and send only that UUID plus creation fields. Replace the two client inserts with RPC + existing read. Never fall back to the old multi-write flow if the RPC is absent. Preserve the existing optional weather enrichment after a successful creation.
4. Add SQL regressions for identity, authorization/grants, validation boundaries, host/count invariants, identical and conflicting retries, forced participant-write failure, deletion tombstones, and concurrent duplicate requests. Run in a disposable local database transaction with synthetic data.
5. Add Swift HTTP contract tests and create-model retry tests. Update safe domain-error mapping. Run the full iOS/Edge/SQL suites, Release build/analyzer, local advisors, and diff checks. Record exact evidence; production application and candidate-device tests stay separate.

## Files

- CLI-generated migration under `supabase/migrations/`, SQL regression under `supabase/tests/`, and SQL runner registration.
- `ios/PickUpUCF/Repositories/SessionRepository.swift`, `Features/CreateSession/CreateSessionViewModel.swift`, `Core/AppErrorMapper.swift`, and focused tests.
- Master readiness checklist and this evidence record.

## Deployment and rollback

Deploy the migration before distributing the new client. Existing clients remain compatible; the RPC does not revoke existing table writes. The new client fails safely against an older backend and never retries creation using separate writes. For rollback, retain the ledger and RPC while rolling back the client; deleting the ledger would remove retry history. Production deployment, upload, and distribution require their own exact-candidate verification.

## Verification status

Completed in local source on October 21, 2026:

- **217/217 iOS tests passed** after the final recurring-payload stability change. The added HTTP tests verify the RPC-only contract, lost RPC/read responses, stable request/payload reuse, missing-RPC failure without fallback, and safe domain errors. Create-form tests retain the request ID across uncertain failures and edits.
- Complete local SQL/RLS suite passed with **25 phase success notices** inside explicit rollback. The new phase checks authoritative account status, grants, payload bounds/types, host/count invariants, matching/conflicting retries, later edits, forced host-insert rollback, retry after rollback, and deleted-session tombstones.
- A separate six-connection test returned one session ID and verified exactly one session, one joined host, and one receipt. Fixtures were committed only for concurrent access, then deleted by their synthetic UUID.
- `supabase db lint --local --schema public,pickup_private --level error`: no schema errors. Security-advisor output was identical before/after the new schema; existing baseline advisories remain.
- **36/36 Deno tests passed**. Unsigned generic-device Release build and Xcode static analysis passed. `git diff --check` passed.
- The local database was started without a reset. The new schema was temporarily installed without migration-history entries for concurrency/advisor checks, then removed after confirming zero receipts; the prior local schema and migration history were preserved. The pending venue migration was not applied. Production was untouched.

Latest iOS result: `/tmp/pickup-oct21-final-tests.xcresult`; Release/analyzer log: `/tmp/pickup-oct21-final-release.log`. SQL, concurrency, lint, and advisor evidence is under `/tmp/pickup-atomic-*` and `/tmp/pickup-advisors-*`. Screenshots are under ignored `docs/testflight-evidence/ux-audit/`.

Production deployment was subsequently approved and completed below. Exact-candidate authenticated/offline creation, app-restart draft reconciliation, and physical-device assistive-technology checks remain open. Retry IDs live for the lifetime of an open create form; this does not implement durable form restoration after the app is killed. Existing released clients keep their legacy write behavior until replaced.

## Sources

- Supabase [database functions](https://supabase.com/docs/guides/database/functions) and [Swift RPC](https://supabase.com/docs/reference/swift/rpc), checked October 21, 2026.
- Changelog index checked October 21, 2026. The Postgres 15.19/17.11 notice concerns extension indexes/legacy encryption, outside this function; no dependency update is included.

## Connected-backend compatibility check, 15:47 UTC

After the signed simulator fixed session storage, own-profile reads returned 200. Creation attempts at
15:47:12–15:47:19 UTC returned 404 for `/rest/v1/rpc/create_session`. Read-only production inspection
confirmed that both creation functions and the retry ledger are absent; the required suspension and
content-validation helper functions exist. This is the expected missing-migration failure, and these
404 calls did not execute any creation writes.

The interactive client was made available before its backend dependency, leaving creation unavailable.
The concrete remedy is to apply **only** `20261021155014_atomic_session_creation.sql` to project
`dkvonsrdxqenozdkufwe`, then verify signatures, privileges/RLS, API availability, and a user-authorized
creation/retry. Do not bulk-push other pending migrations. No production changes were made during
this compatibility check; deployment was pending the owner's approval because it had been deferred
in the earlier readiness work.

## Approved production deployment, 15:50 UTC

The owner approved applying this migration. Supabase applied `atomic_session_creation` successfully
and recorded version **20261021155014** in project `dkvonsrdxqenozdkufwe`. Renamed the local SQL file
from its initial CLI-generated version `20261021150523` to match production history. Its contents are
unchanged (SHA-256 `eca9c73746ac3623330e9fc9f4e3c2265cd3e5aa6e50f83a5b0e192c36801bd7`).
No other migrations were applied.

Post-deployment verification:

- Public invoker and private definer functions exist with fixed empty search paths. Authenticated
  callers can execute the public function; anonymous callers cannot. The private retry ledger has RLS
  enabled, with no direct authenticated insert grant.
- A synthetic authenticated SQL transaction created exactly one game, one joined host, and one receipt.
  Matching replay returned the same ID. Changed payload returned PT409; invalid capacity returned PT400;
  deleted-game replay returned PT410; an unauthenticated caller was rejected. The transaction rolled back,
  and separate checks confirmed zero remaining synthetic users/profiles. The first smoke-test fixture
  omitted the email JWT claim required by existing read policies; correcting the synthetic claim made
  the complete test pass without changing deployed code or policies.
- A real HTTPS call to `/rest/v1/rpc/create_session` reached the new function and returned the expected
  anonymous permission denial (`401`, code `42501`), replacing the prior missing-function `404`.
- Security advisors added no WARN/ERROR findings. The only new INFO finding is the deliberately closed
  private ledger's [RLS with no policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
  Existing advisor findings are unchanged and remain outside this deployment.

The current signed simulator client can retry its existing form without a rebuild. A real-account
creation through that UI remains a user check; no real campus game was created by this deployment test.
Rollback remains client-first: retain the RPC and ledger to preserve retry history.
