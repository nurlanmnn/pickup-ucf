# Launch-critical continuation — October 23, 2026

The owner asked to keep working while away at the gym, defer optional polish,
post progress, and open a continuation chat when context becomes loaded. No second
device/account is available until later. Do useful independent work; do not keep
asking for input on work that can proceed locally. Do not promise mobile-client
visibility without evidence.

## Checkout and authorization

- `/Users/nurlanmammadli/pickup-ucf`, branch `codex/calendar-write-only`.
- Last implementation/test commit before this handoff: `cc5cbe5`; clean checkout.
- Local changes are committed. **No push/merge, new deployment, new build upload,
  external invitation or Beta App Review is authorized by this continuation.**
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

Focused evidence: October 23 host-edit, waitlist-retry and host-action-concurrency
plans under `docs/superpowers/plans/`, and
`docs/operations/2026-10-23-isolated-restore.md`. Commits: `a65e417` recovery,
`277ac46` host edits, `76f7f9e` waitlist retry, `cc5cbe5` concurrency.

## Next independent work

Continue BETA-13's remaining edit/read-minimization audit from the master index
`docs/superpowers/plans/2026-09-02-testflight-readiness.md` (relevant sections only).
Inspect repository/payload semantics before adding more database restrictions.
In particular, `SessionRepository.updateSession` computes normalized custom sport
name but `SessionRowPatch` has no customSportName field; synthesized optional
encoding also omits nil fields. Investigate whether editing an existing Other
sport retains the old DB name and whether clearing optional fields/location
switches retains stale values. This is a source observation, **not yet a tested
defect**. Reproduce with a focused synthetic/HTTP-denied repository test before
fixing. Avoid breaking build-5 patch compatibility with stricter representation
rules. No need to repeat already-passing unchanged SQL/concurrency suites unless
the new diff affects their behavior.

For iOS tests preserve `PICKUP_UNIT_TESTS=1`, bootstrap skip, synthetic shared
client and HTTP-denying URLProtocol. Never run a test host against live bootstrap.
Existing unchanged prior evidence: 261/261 isolated simulator tests, 39/39 Deno,
Release/analyzer; Swift changes justify appropriate focused/full verification.
Do not install a development build over TestFlight build 5 without owner intent.

Restricted recovery directories remain outside Git under
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-22`,
`2026-10-23-exercise`, `2026-10-23-forward-exercise`. Never print contents, private
rows, secrets, signed links or raw CLI db-dump dry-run output. Restore material
is not permission to expose old grants/auth routing or restore over production
or the existing local database. No recovery/test containers remain.
