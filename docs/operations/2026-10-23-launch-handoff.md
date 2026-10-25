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

## Report concurrency investigation completed

The owner again asked to keep working and open a new chat when context is loaded.
GitHub feature-branch pushes remain authorized; no merge/deployment/upload.
This continuation started at clean/pushed `47134dd`. Six simultaneous distinct
report targets reproduced **six committed reports** against the 5/hour limit.
New migration `20261023231500` serializes on the reporter's auth.users row FOR NO
KEY UPDATE, preserving deletion lock order and KEY SHARE joins. The count uses a
fresh READ COMMITTED statement snapshot; stronger transaction-wide snapshots fail
closed with SQLSTATE 40001 rather than bypassing the limit.

`PYTHONDONTWRITEBYTECODE=1 python3 supabase/tests/report_concurrency.py` passed:
38 candidate SQL/RLS phase notices inside rollback, hourly 6-to-5 and daily
19-plus-6-to-20, audit-preserving window recovery, independent reporters with a
500ms lock timeout, duplicate retry, reciprocal reporters, both actual account
deletion lock orders with retained audit snapshot, and stronger-isolation guards.
Independent design/final-source review found no required findings. See
[report concurrency evidence](../superpowers/plans/2026-10-23-report-concurrency.md).
Only schema/history were read from the existing local DB. All fixture/schema
writes stayed in a fresh network-disabled disposable container, removed after
testing. Existing DB head is still 20261005150000 without atomic creation RPCs.
No new Swift/Edge changes warranted repeating their passing suites.

## Next independent investigation: Live Activity registration race

The owner explicitly renewed authorization to keep working and create
continuation chats when context fills, stopping only for owner action or usage
limits. Continue concrete launch-critical work; keep verified source pushed.

After report fix `20b8789`, read-only production dashboard inspection confirmed
pickup_private is not Data API exposed; extra search path is public/extensions.
GraphQL is disabled (catalog plus stub resolver response). See
[API exposure evidence](2026-10-23-api-schema-exposure.md). No configuration changed.
Recheck at actual authorized deployment, especially if GraphQL becomes enabled.

The reproduced Live Activity race is now fixed locally by
`20261023232500_serialize_live_activity_registration.sql`: caller account KEY SHARE
then session SHARE, followed by the separate fresh eligibility query. Stronger
transaction snapshots reject with SQLSTATE 40001. The original regression failed
with one future active token after cancellation; the fix passes.

`PYTHONDONTWRITEBYTECODE=1 python3 supabase/tests/live_activity_concurrency.py`
passes 38 candidate SQL/RLS notices inside rollback; both registration/cancel,
leave, schedule and outside-window orders; concurrent independent device tokens;
duplicate delivery-state preservation, ownership/normalization, no terminal token
resurrection; both player/host deletion orders, stale caller and host-own deletion;
and repeatable-read/serializable guards. Ordered races observe actual database lock
waits. Fresh schema-only network-disabled disposable container removed afterward;
existing DB/production untouched. See [activity concurrency evidence](../superpowers/plans/2026-10-23-live-activity-concurrency.md).
Independent design and final source/test reviews found no required changes
(final review completed October 24 after the usage-limit interruption). No Swift/Edge changes warranted rerunning their unchanged suites.

## October 24 push worker follow-up

Live Activity fix/test/docs were committed and pushed as `09e9473`. Final source
review completed after the usage-limit interruption with no required findings.

A subsequent synthetic regression reproduced ordinary outbox transport failure
aborting later recipients; another proved an acknowledgement DB error inflated the
sent count. The handler now isolates send/ack errors per outbox row, keeps failures
pending, checks acknowledgement errors and continues later rows. Both regressions
failed before the patch. Relevant Edge suite passes 31/31 with type checking:
`deno test --allow-env supabase/functions/send-push supabase/functions/send-auth-email`.
See [push outbox recovery](../superpowers/plans/2026-10-24-push-outbox-recovery.md).
Independent final source/test review found no required changes. This Edge fix is
**undeployed**, alongside
the ten pending SQL migrations; no provider/device acceptance is implied.

Next independent work: investigate only a concrete launch-critical invariant,
using synthetic/local evidence before changing code. Preserve owner-only gates,
defer optional P2 polish, and keep verified source pushed. Do not poll the phone.

## October 24 renewed owner authorization and device progress

Owner renewed: continue according to the plan, open continuation chats when
context fills, do iPhone Mirroring checks (phone now available), and stop only for
required owner input or actual usage limit. Source commits/pushes remain authorized;
merge/deployment/new upload are still separate boundaries.

Mirroring reconnected. CoreDevice confirms installed 1.0 (5), iOS 27.0.1 (24A446).
Physical form validation passed: empty Other name rejected; 41/40 (and81/40)
blocked; exact40 advanced; nonfuture schedule showed error; min capacity2 reached.
Bulk Unicode typing/paste was unreliable in Mirroring, so no Unicode physical pass
is claimed; discrete key input works. See the October24 section in build5 evidence.

**Human approval received October 24:** the owner answered exactly
`Yes, publish and cancel it after testing` to the source chat's temporary-game
question (chat `01a16af8-c354-7c23-ae39-cb6c89fae4c0`). The continuation read this
human turn directly before attempting device work. Authorized fixture remains:
basketball, RWC Park, Oct24 11:30PM America/New_York, capacity2, Any, no recurrence,
notes `test only do not join device check will cancel`, for creation/Calendar/
Live Activity/cancellation checks. No deployment/account deletion is authorized.

Mirroring showed iPhone in Use; one Connect attempt then failed with Connection
Interrupted. No phone form interaction or submission occurred in the continuation.
The owner was asked asynchronously to unlock once, lock, keep phone nearby and
report readiness. **No game has been published; nothing needs cancellation yet.**
Do not repeatedly poll the unavailable phone. After owner readiness, reconnect and
inspect the actual form, current date/time and schedule before any submission.
Do not publish a stale/past fixture. Preserve password/reviewer-account boundaries.

The first independent BETA-10 local session-diagnostics slice is now verified
below. Broader diagnostics and BETA-11 deterministic UI smoke remain open P1s;
UI tests require a fail-closed synthetic backend/bootstrap strategy. Never launch
tests against live Supabase.
Optional P2 polish remains deferred. Preserve all release evidence boundaries.

## October 24 client diagnostics slice

BETA-10 now has a focused local session-backend diagnostic implementation. See
[contract and evidence](../superpowers/plans/2026-10-24-session-diagnostics.md).
Closed JSON fields log create receipt/read separately, update/cancel/join/leave,
coarse failures, duration, build/configuration and fresh non-entity attempt IDs.
Create receipt/read share an ID; retries generate a new one. No raw Error, server
code, URL, payload, content, token, user/game identity or precise location is logged
by this category. No external provider, telemetry upload or alert owner was added.

First focused signed isolated tests passed15/15. Full final source/tests pass
270/270 on established iPhone16e/iOS26.3.1. The first full run on a new iPhone17
simulator had four accessibility lookup failures in existing rendered-UI tests,
while diagnostics passed. Read-only preference comparison found the established
lane has ApplicationAccessibilityEnabled/AccessibilityEnabled; the new lane lacks
those. Unchanged final source passed all four and the complete suite on16e. Keep
this environment dependency visible; do not weaken tests or claim all lanes pass.
Independent initial/final static reviews found no required changes. Unsigned
Release simulator build and analyzer both pass. No SQL/Edge code changed or suites repeated.

After verified diagnostics source is committed/pushed, next independent P1 is
BETA-11: start an actual XCUITest smoke lane with a fail-closed isolated app launch,
synthetic SDK/no real restoration, then cover unauthenticated launch/account
navigation/local validation and largest Dynamic Type first. Spec before code;
prove the launch flag automatically denies backend access/skips bootstrap rather
than relying on the runner remembering multiple independent opt-outs. Keep this
first slice separate from future authenticated synthetic fixtures and from device
acceptance. Never start a UI test app against the configured live backend.

Phone work requires owner readiness reply in chat
`01a170f3-0159-7ad2-bc51-28fc4e37c08c`. The game itself is already explicitly approved
in the source chat, but remains unpublished after connection failure. Recheck the
actual form and clock; approved schedule Oct24 11:30PM may become stale.

## October 24 isolated UI smoke slice

BETA-11 first slice is complete locally: 4/4 signed XCUITests with empty backend
URL/key in the built app. Welcome intro/relaunch, account route replacement/email
carry, blank sign-in validation and actual accessibility5 navigation pass. See
[contract, command, reviews, screenshots and lane setup](../superpowers/plans/2026-10-24-ui-smoke.md).
A single explicit Debug simulator-only flag selects the synthetic HTTP-denying
client, discards auth storage, resets only welcomeIntroCompleted before Welcome
construction, and skips restore/foreground/deep-link/push side effects. Root AX
marker is required before test actions; unsupported runners skip before app launch.
Normal/Release behavior remains unchanged. Original project IDs/order are preserved.

The first post-UI full unit run reproduced four existing AX lookup failures; the
established simulator now had ApplicationAccessibilityEnabled0/AccessibilityEnabled
false. Restore 1/true and restart before the unit lane, as documented. Unchanged
final source then passed **273/273**, including all four. No source/test weakening.
Final UI run4/4 and unsigned Release simulator build/analyzer pass; final independent
review found no required findings. Initial UI test query/transition failures are
recorded in the plan. No SQL/Edge suites repeated or external/physical action taken.

BETA-11 remains partial: authenticated flows/fixtures, permission paths, CI and
physical acceptance are still open. Next useful independent P1: a focused remaining
BETA-10 critical-auth diagnostic increment, with the same privacy/external-provider
boundaries, or remaining deterministic BETA-11 paths. Spec, reproduce/test, review,
commit and feature-branch push; execute concrete work, not only planning.

Phone readiness still requires the human reply in chat
`01a170f3-0159-7ad2-bc51-28fc4e37c08c`. No Mirroring reconnect or game publication
occurred in this UI-smoke continuation. The approved Oct24 11:30PM fixture may
become stale; inspect clock/form before submission and do not shift its time
without owner approval. Continue independent work while readiness is absent.

## October 24 explicit-auth diagnostics slice

BETA-10 now also covers explicit auth operations with local auth_operation JSON:
sign-up/in/out, resend/OTP, recovery request/update, staged change-password and
accepted callback exchange. Original SDK requests, mapping, confirmation checks,
cleanup and original errors remain; currentSession restoration is untouched.
Change-password stages share a fresh attempt UUID, retries get new IDs. Closed
fields exclude credentials, inputs, identities, URLs, raw errors and server codes.
See [contract and evidence](../superpowers/plans/2026-10-24-auth-diagnostics.md).

Focused16/16 and full signed isolated289/289 pass on established iPhone16e/iOS26.3.1;
AX settings read1/1 and simulator restart preceded full unit suite. Unsigned Release
simulator build/analyzer pass. Fresh-context design and final source/test/privacy
reviews found no required issues. Default Logger output schema/privacy checked in
focused/full captures. Initial fixture errors (discard-only storage/API header/SDK
retry assertion) are documented; no product policy/assertion was weakened.
Artifacts `/tmp/pickup-auth-{red,focused,focused2,verified,full,release-analyze}.log`
and verified/full xcresults. No unchanged UI/SQL/Edge suites repeated.

BETA-10 remains partial: session restoration/other flows, reporting approach,
central health signals and alert ownership remain open. No external provider,
production/device action, account mutation, merge, deployment or upload occurred.
Phone-readiness chat was re-read and has no new human reply; no reconnect or game
publication. Approved Oct24 11:30PM fixture must still be future at submission;
do not shift the time or publish it stale. Continue independent P1 local work.

## October 24 UI validation follow-up

Full isolated UI gate now passes6/6: adds actual blank sign-up and recovery-form
blank/non-school-email rejection plus return to unchanged original sign-in. No
product source changes. Final built backend URL/key empty; eight screenshots
retained, three new ones visually inspected. Initial test setup queried the final
intro-page signup button on step0; corrected to existing sign-in/account-switch
route. Existing assertions remain. Independent final review has no required issues.
See [UI contract/evidence](../superpowers/plans/2026-10-24-ui-smoke.md).
Results `/tmp/pickup-ui-auth-validation-final.xcresult`, matching `.log`, exported
attachments `/tmp/pickup-ui-auth-validation-final-attachments`. Prior289/289 signed
unit and Release build/analyzer evidence was not repeated for test-only changes.
**Before later full unit runs, check/restore AX1/true and restart after this UI
lane** as documented. No physical device, backend or production action occurred.
Phone readiness remains absent; temporary game remains unpublished.

Next independent P1: remaining BETA-10 critical chat diagnostics at actual
repository boundaries (first/older-page fetch, send and targeted reconciliation),
or remaining isolated BETA-11 paths if architecture supports a useful focused
slice. Inspect actual source, spec and meaningful synthetic regressions before
code; keep original payload/order/errors/cursors and private content untouched.
No raw SDK Error, server codes, messages, usernames, IDs, cursor timestamps, URLs,
credentials or tokens in logs; no external provider or alert-owner invention.
Broader BETA-10/11 gates remain open. Continue concrete work and push verified
source within existing authorization; do not merge/deploy/upload.

## Remaining work and gates

The focused independent BETA-13 client edit/read audit is complete for the
reviewed surfaces. See October 23 `session-edit-payload`,
`participant-read-minimization` and `policy-helper-reads` plans for exact scope,
red/green evidence and limitations. Optional profile timestamp/strict column
minimization is deferred; do not turn that into cosmetic refactoring.

There are now ten undeployed October 23 migrations, in order:
20261023215028, 20261023215505, 20261023221000, 20261023222000,
20261023223500, 20261023224500, 20261023225500, 20261023230500,
20261023231500, 20261023232500. The new iOS edit fix
also needs a future compatible binary before exact-candidate edit acceptance.
GitHub source pushes were subsequently authorized by the owner. Deployment,
upload and merge remain outside the current authorization. Production private
schema exposure was verified read-only October 23; recheck at helper deployment.
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
Latest iOS evidence: 289/289 signed isolated simulator tests plus 4/4 credential-free XCUITests on the established
iPhone16e lane and unsigned Release simulator build/analyzer (October24). October 24 relevant Edge evidence is 31/31 typechecked push/auth
tests; the unchanged weather tests retain prior evidence. New Swift
changes justify appropriate focused/full verification.
Do not install a development build over TestFlight build 5 without owner intent.

Restricted recovery directories remain outside Git under
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-22`,
`2026-10-23-exercise`, `2026-10-23-forward-exercise`. Never print contents, private
rows, secrets, signed links or raw CLI db-dump dry-run output. Restore material
is not permission to expose old grants/auth routing or restore over production
or the existing local database. No recovery/test containers remain.
