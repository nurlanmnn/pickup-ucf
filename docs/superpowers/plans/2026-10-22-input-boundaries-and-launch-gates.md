# BETA-03 and launch-critical audit — October 22, 2026

Preserve the BETA-08 work on `codex/realtime-chat-recovery`. The user authorized
committing and pushing the current source to main on October 22 after local review.
Production deployment, archive upload, and submission remain outside this authorization.

## Input contract

Use existing maxima: display name 80, notes 1000, custom sport 40, custom location
120, chat/report context 500 (supplied report context retains its 10-point minimum).
Required display name/chat and supplied custom labels
have a normalized minimum of one code point; optional notes/context/unused labels
normalize blank to null. Active custom sport/location requirements remain enforced
by session invariants. Normalize to NFC, collapse permitted Unicode whitespace to
one ASCII space and trim. Line breaks/tabs collapse too. Count Unicode code points
(Swift unicodeScalars, PostgreSQL char_length), not grapheme clusters or UTF-8 bytes.
Emoji sequences can use several code points; explain this beside counters. Reject
C0/C1 controls before normalization except TAB/LF/CR. Preserve ZWJ/variation selectors.
Existing UGC moderation remains authoritative and is not weakened.

## Ordered implementation and verification

1. Review the BETA-08 diff, tests and prior results; preserve device gaps.
2. Add failing client/server regressions for NFC, scalar boundaries, emoji, Unicode
   whitespace, optional control bypass, required blank/null, and crafted table writes.
3. Align UserContentPolicy and the existing assert_user_content trigger helper in an
   additive migration. Keep grants closed and return fixed, safe validation errors.
4. Add shared accessible counters/inline validation to signup, chat, create/edit
   sport/notes, and custom map selection. Do not silently truncate user input.
5. Run focused/full iOS tests, local SQL/RLS suite, Deno suite, unsigned Release
   build/analyzer, migration lint/advisors where supported, and diff review.
6. Audit remaining security/RPC, notifications, deletion and device gates. Implement
   reproducible launch-critical defects in focused slices with tests and record the
   exact production/device checks still required. Defer cosmetic changes.

## Dependencies and rollback

The new helper replaces the existing moderation helper without changing its API;
existing table triggers and atomic create_session call it. No historical content is
rewritten. Exercise both direct table writes and atomic creation. Production rollout
requires migration authorization and candidate/device verification. If normalization
causes a regression, restore the prior helper definition with a forward migration;
do not truncate stored content or weaken RLS. Local SQL verification uses rollback
transactions so existing local data and migration history are preserved.

## Security follow-up contract

The local privilege inventory reproduced direct anon/authenticated EXECUTE grants
on notification enqueue and lifecycle functions despite historical PUBLIC revokes.
Add an explicit function-signature inventory: no anonymous application RPC access;
authenticated callers receive only the client RPCs and RLS helpers. Internal
notification, recurrence, maintenance and trigger functions remain owner/service
operations. Preserve service-role and postgres cron execution. Pin the three
mutable search paths reported by local advisors. Add role-denial regressions and
rerun the entire SQL suite; simulate internal enqueue from a privileged role in
the moderation trigger test rather than giving ordinary users the helper.

Account deletion also has a hosted-profile RESTRICT dependency. Hosted-game
retention/removal was resolved by the owner below. Independently,
clear account-bound navigation/drafts/banners after successful deletion/sign-out;
retain them on failed deletion. Notification prompt moves out of bootstrap into
an explicit Settings action with status/Settings recovery; no new analytics SDK.

## Evidence

The final isolated signed iOS simulator suite passed **248/248** on iPhone 17 Pro /
iOS 26.3.1: `/tmp/pickup-launch-isolated-final.xcresult`. This includes BETA-08,
content boundaries, null-host decoding, chat deletion reconciliation, real-Keychain
relaunch/remote-logout tests and explicit shared-client HTTP denial. Unsigned generic-device Release build and static analysis passed on the final source
(`/tmp/pickup-launch-release-final-preserved.log`); the only warning was the unused AppIntents
metadata extraction notice. This is not a signed archive or device acceptance. The unchanged
Edge Function suite passed **36/36** (`/tmp/pickup-launch-deno.log`).

`python3 supabase/tests/run_candidate_suite.py` passes all SQL/RLS phases A–N,
including pending migrations, then rolls everything back. This uses the existing
local schema through 20261005150000 plus pending migrations in one transaction;
it is not a newly reset production database. Log: `/tmp/pickup-launch-sql-final.log`.
`python3 supabase/tests/join_leave_concurrency.py` passes duplicate leave, final-slot
joins, mixed join/leave and deletion exclusion; it restores original functions and
removes synthetic fixtures. Log: `/tmp/pickup-joinleave-green-final.log`.

Normal and Accessibility XXXL chat renders were inspected; the counter was shortened
to preserve conversation space while retaining VoiceOver guidance about emoji.
This is synthetic layout evidence, not device VoiceOver acceptance. Historical
BETA-08's 230-test evidence remains in its October 21 plan. Two-account/device,
App Store and production rollout checks remain open.

## Join/leave follow-up contract

The current join RPC locks the session before reading membership; leave reads the
membership first and can decrement/promote twice under concurrent retries. Update
leave to lock the same session row first, then inspect membership. Keep repeated
leave idempotent; never let a host leave without cancelling. Validate simultaneous
final-slot joins, duplicate leaves and mixed leave/join with committed synthetic
fixtures on an isolated local database. Revoke direct participant writes and direct
session/count/statistic mutations so crafted clients cannot bypass those functions.
Do not introduce a production reconciliation job to conceal drift.


## Rollout compatibility

The grants migration requires the atomic-RPC iOS candidate (source 0152a94 or later).
Legacy clients that insert sessions/participants directly will fail safely after
it is applied. Coordinate candidate distribution/retirement of legacy builds
before deployment. Do not restore broad notification/maintenance execution as a
rollback. If a client field is accidentally omitted, grant only that field after
review; keep server-owned counts, statistics and participant rows protected.

## Account deletion — owner decision received

Retain hosted games with an anonymized host. Add a nullable `sessions.host_id` with
ON DELETE SET NULL (same FK name so PostgREST embeds continue working). Cancel open/
full hosted games; preserve completed history and other players' chat. Lock all
hosted/joined session rows in UUID order, leave non-host memberships through the
serialized RPC to reconcile counts/promotions, remove queued authored chat previews,
then delete auth.users in one transaction. Missing-account retries return safely.
Retain private moderation evidence under the existing policy. End local activities
and remove notification/token state through existing account transition cleanup;
other players' activity tokens remain attached to cancelled games for silent end.

Make PickupSession.hostId optional; show Deleted host without a profile/block link.
Test null-host decoding and filtering, hosted/participant deletion, ordinary-user
isolation, rollback on backend failure, queued previews, tokens, retained chat,
counts, stale JWTs, and idempotent retry. Old clients require candidate rollout
before the nullable-host migration. Rollback must not reintroduce NOT NULL after
anonymized rows exist; preserve anonymized games in any forward repair.


## Deletion and roster integration details

- Retained game rows use null host IDs; the app renders Deleted host with no account
  link or block action. Other users' ordinary messages remain; the deleted account's
  messages and authored notification previews are removed. Private moderation evidence
  remains under the existing safety-retention policy. Local privacy-site copy was
  updated to describe this; publishing the site remains a separate action.
- Disable recurrence on retained games and use a null-safe host check for attendance;
  an anonymized game cannot grant host powers or create new recurring games.
- The roster RPC previously bypassed blocking and historical-session visibility.
  `20261022152456_secure_session_roster_reads.sql` shares one private access predicate
  with session RLS, filters blocked profile identities, and preserves true aggregate
  waitlist count/position. Local tests cover both denial and count correctness.
- Chat foreground/reconnect recovery now revalidates older loaded message IDs in
  batches of at most 50. Missing/deleted/hidden rows are removed only after successful
  reconciliation; failures preserve history and offer retry. Optimistic sends and
  late responses after closing the chat are guarded separately. This is refresh-time
  reconciliation, not a claim of immediate cross-device deletion delivery.
- Relaunch verifies the current auth user before restoring persisted credentials.
  Server-confirmed missing/expired accounts clear local Keychain auth; network failures
  preserve the cached session without treating offline as deletion. Server RLS checks
  current confirmed account data independently. Real-Keychain synthetic tests cover
  deleted-account and offline restore. Live provider/device behavior remains open.

## Direct host status boundary

Close the crafted-client path that reopens cancelled/moderated games or marks games
completed without attendance logic. A client-only UPDATE trigger permits cancellation
from open/full, keeps retries harmless, rejects changes to closed games, and derives
open/full from capacity and the server-owned count after a host capacity edit. Owner
RPC/cron/moderation operations bypass this client boundary through their existing
SECURITY DEFINER context. Keep the function non-executable by API roles and add SQL
regressions for reopen denial, closed-content denial, no-op cancellation and capacity.

## Account-deletion contention

Join and atomic creation must take a KEY SHARE lock on the current auth.users row
before any session lock/write. Deletion already locks that row FOR UPDATE first.
This prevents a second device creating/joining a game after deletion has enumerated
memberships. Keep the same account-before-session lock order, enforce a current
confirmed school account, and test a deletion transaction holding the auth row
while a simultaneous join attempts to create new membership. Restore temporary
local function definitions and remove all synthetic fixtures in the harness.


## Test isolation incident and correction

Earlier test-host startup ran normal bootstrap against production before isolation
was made explicit. Request-ID-paired logs confirm successful existing-profile upsert
and token registration refreshes; auth-session refreshes also occurred. Requests
involved one profile and one stored token, whose current owner matches that profile
by a read-only hash-based check. Previous values/ownership were not recorded, so no
speculative reversal was attempted. No migration, deletion or session-content mutation
was performed. Do not count this accidental traffic as integration/device evidence.

The XcodeGen Test action now sets PICKUP_UNIT_TESTS=1; both source project.yml and
checked-in scheme carry it. Startup skips live bootstrap, and the shared unit-test
client has a synthetic URL/key plus an HTTP-denying URLProtocol. A regression executes
a shared-client query and requires unsupportedURL. SDK raw payload logging is disabled;
owned earlier text diagnostics were redacted and their result bundles restricted to
the current user. Aggregate summaries contain only endpoint/status counts, not account
values. The final 248-test run uses this isolated configuration.

## Remaining publishing gates

| Gate | Required evidence/action | Current state |
| --- | --- | --- |
| Candidate provenance | Review/commit source, choose a unique build number, signed archive/validation and internal distribution | Source reviewed for the user-authorized main push; unique build/archive/upload remain open |
| Backend rollout | Backup/restore expectations; review and authorize missing Oct 5 migrations, seven Oct 22 migrations, and current send-push deployment | Open; explicit grants remain exposed in production |
| Compatibility | Distribute the nullable-host / atomic-RPC client before enabling retained null-host rows or revoking legacy direct inserts | Open; older builds can fail those paths |
| Notification parity | Verify schema/function versions, cron policy, APNs environment/invalid-token handling, auth email/reset hooks and monitoring | Oct 5 migrations absent; old 15-minute cron active in read-only audit |
| Device matrix | Two accounts/devices on iOS 17 and current iOS, exact build and backend recorded | Open |
| Safety and privacy | Production ordinary-user/moderator/blocked/deleted-user matrix, support coverage, publish matching privacy copy | Local tests/copy ready; live checks/publication open |
| Auth links/calendar | Resolve sensitive custom-scheme reset-link and calendar full-access gates (BETA-07/BETA-05) against actual distribution configuration | Open, separate focused workstreams |
| External release | Critical-path/accessibility acceptance, age rating/reviewer access/What to Test, Beta App Review and small cohort | Open; no submission/invitation performed |

## Exact-candidate device record

Record build/source, device models/iOS, backend migration/function versions, tester,
local timezone and pass/fail evidence. Use dedicated test accounts without copying
credentials, tokens or message bodies into this repository.

1. Create, lose connectivity during creation, retry the same request, and verify one
   game/host/count; edit/cancel and confirm another device sees the result.
2. Race final-slot joins and repeated leave; verify membership/count/waitlist recovery
   and host cancellation. Include a second device joining during account deletion.
3. Exchange chat with both accounts; background/disconnect long enough to miss more
   than one page, reconnect, verify authors/order/history/draft and retry behavior.
4. Exercise exact/over-limit Unicode input and large text; check inline errors,
   keyboard dismissal, touch targets and VoiceOver focus on authenticated screens.
5. Confirm notification prompt appears only from Settings; allow/deny, revisit and
   change permission in system Settings, then verify foreground registration recovery.
6. Test APNs alerts/taps and Live Activities while foreground/background/closed, with
   1-hour eligibility, reschedule/cancel/end, invalid-token cleanup and denied content.
7. Sign A out and sign B in on the same phone; ensure only B gets new alerts and no
   A drafts/navigation/history/local notifications reappear. Include cleanup failure.
8. Block/report between accounts; verify hidden chat/roster/profile identities and
   no actor-generated notification bypass; test ordinary-user moderator denial.
9. Delete a host with active/completed games and membership elsewhere: active hosted
   games cancel, retained rows show Deleted host, other-user chat stays, old authored
   messages disappear after refresh, counts/promotions and activity cleanup reconcile.
10. Repeat deletion offline, with a lost response and relaunch; verify safe retry,
    signed-out state after confirmed deletion and a new account on the same device.

Sources used for implementation checks: [PostgreSQL string normalization/counting](https://www.postgresql.org/docs/current/functions-string.html),
[XcodeGen Test action environment variables](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#scheme),
and the resolved Supabase Swift AuthClient/APIClient/Keychain source. No dependency update was introduced.


## Final review and provenance

Reviewed ordering, role grants, nullable-host authorization, count reconciliation,
rollback, account/session lock order, cached-message deletion and test isolation.
The existing app/widget build number **4** and version **1.0** are preserved; they
are now explicit in project.yml so XcodeGen cannot reset them to build 1. Unrelated
generated project-ID churn was removed after verifying identical Swift source
membership. The Test action's synthetic environment change remains checked in.
Build 4 is existing metadata, not an assertion of a new processed/uploaded candidate.
The next upload still requires a fresh unique build number and signed provenance.
At the end of implementation, no commit or push had been performed; the user
subsequently authorized the current source push to main. No schema/function
deployment, privacy-site publish, archive upload, external invitation or App Review
submission was performed. Production bootstrap
side effects are recorded separately above. Optional polish was deferred.
