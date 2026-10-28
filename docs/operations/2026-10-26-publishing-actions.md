# Reviewable publishing actions — October 26

Status: preparation only. No merge, production deployment, upload, invitation,
review submission, new game, provider setting or account change is authorized by
this packet. Feature-branch documentation/source pushes remain authorized.

## Evidence to carry forward

- Validated application source: `24dc95c` on `codex/calendar-write-only`.
  Credential-free UI 11/11, signed isolated units 374/374, unsigned Release
  build/analyzer and independent reviews passed. Existing compiler warnings are
  recorded in the detail plan; this is not a warning-free build claim.
- Last documented internal TestFlight binary: 1.0 (5), source `53ac5c7`.
  It does not contain the later source changes. The manual simulator artifact
  from `7762fe4` is also different from the current validated source.
- Source app/widget versions in `ios/project.yml` remain 1.0 (5), minimum iOS 17.
  Do not reuse build 5 for another upload or infer the next available number.
- Production history was rechecked in the preceding October 26 checkpoint:
  head `20261022170532`, none of the ten October 23 migrations applied;
  deployed send-push v18 differs from the pending worker fix. This packet does
  not perform another production check.
- The October 26 game is cancelled, with zero active Live Activity tokens.
  Never reopen or republish it. Physical activity appearance/end were confirmed.
  Background chat alert/navigation remains inconclusive: the no-alert report
  preceded worker dispatch. A sent marker alone does not prove APNs delivery.

## Ordered actions and decision boundaries

| Step | Concrete work | Evidence required before advancing | Authorization |
| --- | --- | --- | --- |
| 1. Store inventory | Read Apps/TestFlight and release metadata without saving changes | Latest uploaded/processing builds, internal/external assignments, review state, declarations and selected release build | Read-only audit allowed; October 27 check completed for builds/basic listing |
| 2. Freeze candidate | Select exact reviewed source; choose an unused build number after step 1; update app/widget together; record source/dependency/signing provenance | Clean reviewed candidate diff, normal linked-backend Release configuration, expected app/extension identifiers and entitlements | Local preparation/source push allowed; merge remains separate |
| 3. Prepare backend window | Recheck migration history, deployed worker source/configuration, role/API surface and recent cron health; capture protected recovery material and define forward repair | Exact pending set, unchanged reviewed SQL/worker diff, compatibility with build 5 and new candidate, named operator/backup and recovery decisions | Read-only/preparation allowed; obtain specific rollout approval before mutation |
| 4. Roll out backend | Apply only the ten ordered migrations below and reviewed send-push fix in the approved window | Migration parity; intended grants/RLS/private-schema exposure; ordinary/moderator/blocked/deleted-role API matrix; cron/outbox health without test pushes | Explicit production approval required |
| 5. Package and distribute internally | Archive/export exact candidate, verify signatures/entitlements, app/widget version parity and dSYM UUIDs; record IPA hash; upload then select intended internal group | Processing complete, candidate identity verified on installation; declarations answered accurately by owner | Upload and internal distribution each need specific authorization |
| 6. Exact-candidate acceptance | Execute remaining bounded device/provider matrix below on compatible backend | Device/build/OS/time evidence for each row; clean fixture teardown | Approve each new live fixture and any provider/account mutations separately |
| 7. External beta | Refresh reviewer packet/data, confirm operations coverage, enter final metadata, choose cohort | All external beta gates pass; reviewer can sign in and navigate fresh synthetic data; no stale schedules | Invitations and Beta App Review submission need separate approval |
| 8. Public release | Complete production listing/screenshots, privacy/age/export declarations and final App Review packet | Public-release go/no-go on exact selected candidate; external beta approval is not public App Review acceptance | App Review submission and release require explicit approval |

Step 2 local packaging may proceed alongside step 3 preparation. Candidate device
acceptance requires the compatible backend and exact installed candidate. A failed
gate holds the next step; source test success never substitutes for device proof.

## Backend change set to approve

The migration order is:

1. `20261023215028_enforce_host_edit_boundaries.sql`
2. `20261023215505_preserve_waitlist_retry_priority.sql`
3. `20261023221000_restrict_participant_reads.sql`
4. `20261023222000_scope_public_policy_helpers.sql`
5. `20261023223500_authorize_current_report_callers.sql`
6. `20261023224500_require_chat_session_visibility.sql`
7. `20261023225500_restrict_message_insert_columns.sql`
8. `20261023230500_scope_attendance_ledger_reads.sql`
9. `20261023231500_serialize_report_submissions.sql`
10. `20261023232500_serialize_live_activity_registration.sql`

Worker scope: the existing reviewed per-row send-push recovery from `11c61f7`
keeps a failed outbox row pending and continues later rows. No secret rotation,
provider change, unsolicited test dispatch or unrelated function deployment is
included. Recheck the actual diff before requesting approval.

Retain approved pre-change function/config snapshots privately. Do not claim a
database downgrade is safe: preserve anonymized hosts, atomic ownership and
restricted grants; use reviewed forward repair. Logical isolated restore evidence
does not establish hosted Auth/platform recovery or an agreed recovery time.
Stop rollout on authorization leakage, membership corruption, scheduler failure
or new sustained dispatch failures; record the baseline before the window.

## Remaining device and reviewer gates

Required rows remain open for physical iOS 17 and current iOS with exact candidate
identity: offline/relaunch/retry, account-transition token/badge/chat isolation,
Calendar denial/recovery and independent copies, HTTPS auth/share/provider flows,
VoiceOver/Dynamic Type, block/unblock, recipient notes updates, and notification
presentation/navigation. Reporting and irreversible account deletion require
separate controlled-account authorization. Preserve the passing hybrid core
evidence without relabeling it as two-physical-device or exact-candidate acceptance.

Next notification run must be prepared as an unpublished draft containing an
exact future schedule, public venue, capacity, synthetic warning and cleanup
deadline. Do not invent a schedule now that may expire before owner availability.
Obtain fixture approval, confirm phone readiness and candidate identity, verify
recipient eligibility/permissions and the active Focus state without changing it,
then background the recipient. Send one labeled synthetic message; record send,
dispatch and observation times separately. Allow the minute worker cycle and a
full 90-second observation window after confirmed dispatch. Inspect safe provider
outcome metadata if available; distinguish a processed row from accepted APNs
delivery and a displayed alert. Tap only after arrival to verify authorized chat
routing. Cancel the exact fixture and verify zero active tokens before stopping.
Do not start a fixture near the 85%-used five-hour limit.

Reviewer seed descriptions from October 4 are historical. Refresh only after
specific approval, then verify fresh sign-in, available future games, chat history
and separate report/block targets. Never commit credentials, reviewer identifiers
or private contact details. Do not delete the shared reviewer account.

## Current access and owner inputs

October 26 continuation audit: Chrome reached App Store Connect's login page
with `authResult=FAILED`; no authenticated build inventory was available. No
credentials were entered and no store fields changed. Native UI inventory reported
the Mac locked; no phone checks were attempted. Owner sign-in is needed to finish
the current store audit before numbering a candidate.

October 26 ownership confirmation is now recorded in external-beta-operations:
Nurlan owns urgent safety escalation, Supabase operations, push delivery and
release decisions; no backup is assigned. Backup coverage, a private escalation
path and recovery retention/RPO/RTO decisions remain open.

## October 27 candidate preparation

After owner sign-in, current store inventory again showed build 5 as the latest
upload, Complete and internally assigned; no processing/newer upload or external
group was listed. The public version remains Prepare for Submission with no build
selected. Basic listing/category/age-rating gaps are recorded in the
[local listing draft](../testflight/2026-10-27-store-listing-draft.md).

Source candidate `2d4310d`, version 1.0 (6), is archived and exported locally with
signature/entitlement/version/symbol/configuration checks passed. See
[candidate provenance](../testflight/2026-10-27-build-6.md). No upload/internal
assignment, installation or deployment occurred. The read-only backend baseline
remains migration head20261022170532/send-push v18; all ten migrations are pending.
Current candidate preparation supersedes the historical build-5 source version
and login blocker above without changing the release authorization boundaries.

Later October 27: owner specifically approved uploading build 6 for processing.
Xcode upload succeeded at18:59:09 Eastern; store independently showed1.0(6)
Processing, created6:59PM. Internal assignment, compliance declarations,
installation, backend rollout and review submission remain separate. See the
candidate record for the processing result and exact authorization scope.

Processing then finished with Missing Compliance, build ID
1ab7ca50-f3d3-4918-a1b1-306b0da23ca8. No group is assigned. The encryption question
was opened read-only with no choice selected; owner declaration confirmation
and internal-distribution approval are the next gates.

Owner subsequently approved that exact declaration/internal-assignment request.
The next read already showed compliance cleared and non-exempt encryption No;
the agent did not re-save it. The agent assigned only the existing internal group.
Build6 is now Testing with1 tester. Installation and exact-candidate acceptance,
backend rollout, external distribution and review remain open; see candidate record.

The [October27 backend preflight](2026-10-27-backend-rollout-preflight.md) now
contains the exact proposed production set, private logical-capture scope,
migration dry-run parity, API exposure checks and execution/recovery steps.
It is preparation only; backend deployment approval remains outstanding.

Subsequent owner approval authorized exactly that backend set. All ten migrations
are now applied at head20261023232500; send-push v19 is active with source and
bounded server health verified. See the [production rollout record](2026-10-27-production-rollout.md).
This supersedes historical pending-backend statements above. Build6 device
installation/acceptance and external-review/recovery gates remain open.

References: [checkpoint](2026-10-26-release-checkpoint.md),
[launch handoff](2026-10-23-launch-handoff.md),
[hybrid evidence](../testflight/2026-10-26-hybrid-device-check.md),
[build 5 provenance](../testflight/2026-10-22-build-5.md),
[review packet](../testflight/external-beta-review-packet.md),
[operations](external-beta-operations.md).

## October 28 physical continuation

TestFlight on the mirrored phone showed 1.0 (6) installed. Saved-session restore,
history, Settings, custom-sport validation and retained cancelled-game reads passed
bounded checks; see [device evidence](../testflight/2026-10-28-build-6-device-check.md).
Broader acceptance remains open. A new timed fixture/second-account request is
pending; no fixture was created. A dedicated support page is prepared locally,
with browser/layout/link/contrast checks; deployment remains a separate action.
The owner's current five-hour stop threshold is 35% remaining (65% used), replacing
the older 85%-used threshold for this continuation.

Subsequent owner approval and requested simulator second client enabled the
[October 28 hybrid check](../testflight/2026-10-28-hybrid-build-6-check.md).
Create/discover/join/leave/rejoin and two-way foreground chat passed bounded checks.
Owner confirmed background alert arrival but tapping the actual chat notification
opened session detail rather than Chat: routing remains a release blocker, with
no verified fix. Fixture is cancelled; zero active Live Activity tokens and zero
pending outbox rows verified. No new fixture is approved. Store access was restored;
the listing draft records the screenshot/pricing/availability/accessibility gaps.


October 28 continuation: a local retained-detail regression reproduced and fixed
chat alert routing, including a separately reproduced cross-tab consumer race.
See [routing fix and verification limits](../testflight/2026-10-28-chat-routing-fix.md).
TestFlight build 6 is unchanged. New route/link UI tests pass; broader test failures
remain open. Owner replaced prior cutoffs with 92% used / 8% remaining; never use
reset credits. Build 7 packaging/upload and physical notification retest remain open.
