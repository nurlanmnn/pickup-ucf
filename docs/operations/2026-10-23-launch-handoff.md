# Launch-critical continuation — October 23, 2026

The owner asked to keep working while away at the gym, defer optional polish,
post progress, and open a continuation chat when context becomes loaded. No second
device/account is available until later. Do useful independent work; do not keep
asking for input on work that can proceed locally. Do not promise mobile-client
visibility without evidence.

## Checkout and authorization

- `/Users/nurlanmammadli/pickup-ucf`, branch `codex/calendar-write-only`.
- Latest implementation/test commit: `3ba71dc`; documentation updates follow it.
  Prior continuation started at clean `c4e4718`.
- Local changes are committed. On October 23 the owner subsequently authorized
  GitHub pushes during continued work. Push verified source to the feature branch.
  **Merge, new deployment, new build upload, external invitation and Beta App
  Review remain outside this authorization.**
- Preserve existing work; inspect Git status first. No optional P2 refactors.
- Never delete the reviewer account or change its password. Provider password
  entry/change and irreversible production deletion require owner handoff.

## Candidate and device evidence

Read `docs/testflight/2026-10-22-build-5.md` for candidate truth. Build 1.0 (5),
source `53ac5c7`, uploaded/assigned internally October 22 with prior explicit
approval; no new upload is needed merely to repeat unchanged evidence. Production
rollout baseline is `docs/operations/2026-10-22-production-rollout.md`.

October 23 CoreDevice confirmed iPhone 17, iOS 27.0.1 (24A446), installed 1.0 (5).
Owner confirmed TestFlight origin. Via Mirroring, launch/cold relaunch restored
the same reviewer session; Profile/Settings and expected hosted Privacy/Terms
links worked. Discover 48-hour view/My Games had no upcoming games; four past
history entries loaded. No new sign-in, provider recovery, offline, Calendar,
APNs, two-account, deletion or accessibility acceptance occurred. No app fixture,
message or account mutation was performed in these smoke checks.

Mirroring subsequently disconnected because the phone is in use. The owner is
away with the phone; do not repeatedly attempt connection or stall on it. Keep
single-device/provider/physical-iOS-17 acceptance separate from local tests.

## Work completed in this chat

1. Actual pre-rollout snapshot restored privately in a network-disabled disposable
   tmpfs database. All 38 table-count/44 FK checks passed. Six empty incompatible
   auth blocks were excluded; every populated block was restored.
2. A second isolated restore replayed all ten deployed migrations unchanged.
   pg_cron API only: launch_active_jobs=off, workers=0, no cron worker/jobs ran.
   Synthetic create/retry/join/chat/anonymized-delete/stale-JWT/cleanup passed
   inside rollback. Read-only live production comparison matched 46 application
   functions and 148 table/policy/constraint/index/trigger catalog entries.
   Both restore containers were removed. Full managed-auth/platform recovery and
   ownership/retention/RPO/RTO decisions remain open.
3. Local migration `20261023215028_enforce_host_edit_boundaries.sql`: reproduced
   host capacity=1 bypass, then guarded changed capacity, schedule/duration and
   location-pin groups. Preserves legacy cancellation/notes and build-5 named
   venues retaining valid old custom fields. Production has the older guard.
4. Local migration `20261023215505_preserve_waitlist_retry_priority.sql`:
   reproduced retry resetting joined_at; conflict update now skips an already
   waitlisted row. Explicit leave/rejoin creates a fresh queue entry.
5. Full candidate SQL/RLS suite passes with 32 phase-success notices, including
   phases O/P, all rolled back. Baseline local migration head remains
   `20261005150000` (do not assume its public schema already has pending RPCs).
6. New `supabase/tests/host_action_concurrency.py` clones schema/history only
   into a fresh isolated synthetic database: four ordered host-action races,
   twelve cancellation/join races and six concurrent waitlist retries pass.
   Disposable test container removed; existing local DB was not edited.

7. Session edit payload regressions reproduced through synthetic SDK HTTP tests:
   Other-name edits, clearing name/notes and both location switches retained old
   stored values. Fixed in `96b1278` with custom_sport_name and explicit nil JSON
   encoding. Cancellation remains status-only. Focused tests pass 13/13; full
   signed isolated simulator suite passes 267/267; unsigned Release build and
   analyzer pass. Initial unsigned full test run failed existing real-Keychain
   tests; normal simulator signing resolved that test setup error. Never disable
   simulator signing for the full suite. No development build touched the phone.
8. Direct participant reads reproduced historical membership and waitlist
   identity disclosure. Local migration `20261023221000` restricts other users to
   joined rows in visible games with block filtering; preserves self lookup,
   retained participant rosters, host attendance and exact roster aggregates.
   Commit `09020cb`.
9. Public helper RPCs reproduced unrelated-user block/suspension disclosure.
   Migration `20261023222000` moves raw implementations to pickup_private,
   preserving OIDs/ACLs/policy dependencies; public invoker wrappers scope
   authenticated caller arguments and preserve nested trusted definer checks.
   Commit `b27c87b`. **Before deployment verify pickup_private is not exposed by
   production REST/GraphQL configuration.** Local config exposes public and
   graphql_public only; production API configuration was not verified here.
10. Latest full candidate SQL/RLS suite passes 34 phase-success notices inside
    rollback. After the helper change, isolated host concurrency again passes
    four ordered host races, twelve cancellation/join races and six waitlist
    retries. Disposable test container removed. Existing local DB remains at
    20261005150000 without the atomic create RPC. Independent reviews found no
    actionable issue in each of the three new increments.

11. Follow-up table-policy audit inventoried 18 application/private tables with
    RLS enabled and found four additional concrete defects. Fixed locally:
    `20261023223500` rejects deleted/unconfirmed/non-school moderation-report
    callers (`e88c3f1`); `20261023224500` requires positive chat session visibility
    (`0ad51b4`); `20261023225500` reserves message ID/time for server defaults
    (`07ab9c9`); `20261023230500` scopes attendance ledger reads to own profile
    history (`3ba71dc`). Each had a red synthetic reproduction and independent
    review. Review caught a proposed history compatibility break before commit;
    final attendance policy preserves build-5 own-history reads and host RPCs.
12. Latest candidate SQL/RLS passes **38 phase notices** inside rollback. No new
    Swift/Edge diff, so unchanged simulator/build/analyzer/Edge suites were not
    repeated. Table/API threat model and intentional exceptions are recorded in
    `docs/superpowers/plans/2026-10-23-table-policy-audit.md`. Owner authorized
    GitHub pushes; the verified feature branch was pushed, with follow-up fixes
    being pushed after review. No merge/deployment/new upload is authorized.

Focused evidence: October 23 host-edit, waitlist-retry and host-action-concurrency
plans under `docs/superpowers/plans/`, and
`docs/operations/2026-10-23-isolated-restore.md`. Commits: `a65e417` recovery,
`277ac46` host edits, `76f7f9e` waitlist retry, `cc5cbe5` concurrency.

## Next independent investigation

The owner again asked to keep working and open a new chat when context is loaded.
GitHub feature-branch pushes remain authorized; no merge/deployment/upload.
Current implementation/documentation head before this handoff update is 405a0a9.

Next concrete source observation: submit_moderation_report counts the caller's
last-hour/day reports, rejects at 5/20, then inserts without an evident reporter
lock. Concurrent requests for distinct targets may bypass the rate limit. This
is **not yet a reproduced defect**. Investigate with synthetic requests in a fresh
network-disabled schema-only disposable database, using the isolation pattern in
supabase/tests/host_action_concurrency.py; do not mutate the existing local DB or
use production. A test-only insert barrier/delay may expose the overlap. First
prove a real over-limit acceptance; fix minimally only if reproduced, preserving
valid reporting/duplicate errors, caller auth, independent users and retained
moderation audit records. Evaluate transaction ordering/deadlocks if serializing
per reporter. Run changed-relevant SQL/concurrency checks and independent review,
then commit/push verified source. Do not repeat unchanged iOS/Edge suites.

## Remaining work and gates

The focused independent BETA-13 client edit/read audit is complete for the
reviewed surfaces. See October 23 `session-edit-payload`,
`participant-read-minimization` and `policy-helper-reads` plans for exact scope,
red/green evidence and limitations. Optional profile timestamp/strict column
minimization is deferred; do not turn that into cosmetic refactoring.

There are now eight undeployed October 23 migrations, in order:
20261023215028, 20261023215505, 20261023221000, 20261023222000,
20261023223500, 20261023224500, 20261023225500, 20261023230500. The new iOS edit fix
also needs a future compatible binary before exact-candidate edit acceptance.
GitHub source pushes were subsequently authorized by the owner. Deployment,
upload and merge remain outside the current authorization. Verify
production private-schema exposure before considering the helper migration.
Do not label all of BETA-13 or launch readiness complete: exact production table/role/API
matrix verification, provider/Calendar/APNs/offline/accessibility/two-account and
physical iOS-17 acceptance, platform recovery ownership/RPO/RTO decisions and
external Beta App Review remain open. Those need owner availability, explicit
release authorization or production/device evidence. Do not poll the unavailable
phone or invent second-account/provider credentials.

Latest source evidence is already validated; do not repeat unchanged passing
suites for reassurance. If new source changes are justified, reproduce a concrete
launch-critical defect first and keep compatibility/legacy cancellation intact.

For iOS tests preserve `PICKUP_UNIT_TESTS=1`, bootstrap skip, synthetic shared
client and HTTP-denying URLProtocol. Never run a test host against live bootstrap.
Latest evidence: 267/267 signed isolated simulator tests and unsigned Release
build/analyzer; unchanged prior Edge Function evidence is 39/39 Deno. New Swift
changes justify appropriate focused/full verification.
Do not install a development build over TestFlight build 5 without owner intent.

Restricted recovery directories remain outside Git under
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-22`,
`2026-10-23-exercise`, `2026-10-23-forward-exercise`. Never print contents, private
rows, secrets, signed links or raw CLI db-dump dry-run output. Restore material
is not permission to expose old grants/auth routing or restore over production
or the existing local database. No recovery/test containers remain.
