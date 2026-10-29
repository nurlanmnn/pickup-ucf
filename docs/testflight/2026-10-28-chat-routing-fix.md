# Chat notification routing — October 28, 2026

Local source verification only. TestFlight 1.0 (6) still contains the defect.
No production mutation, new fixture, notification dispatch, upload, distribution,
merge, support-site deployment or review submission occurred in this work.

## Reproduction and change

The owner-confirmed background alert opened session detail rather than Chat.
An isolated UI regression reproduced that failure after loading the same detail
on Discover; initial navigation from the Discover list passed. The failure was
at the first assertion waiting for the Chat navigation bar. Evidence:
`/tmp/pickup-route-red.xcresult`, `/tmp/pickup-route-red.log` (1/2 passed).
This establishes the retained-detail failure locally, not the exact device timing.

SessionDetailView now observes pending chat intent as well as checking after its
initial load. It waits for a completed load for the current authenticated account,
checks task cancellation/account identity after awaiting, consumes once, and keeps
the existing canAccessChat authorization gate. Account changes reset presentation
readiness and Chat. AppState exposes a read-only intent ID for observation; queue,
replacement, deferred authentication and account cleanup retain their semantics.

Independent review found a cross-tab consumer race in the first fix. A new UI
regression reproduced it: My Games detail consumed the intent, Discover was
selected, but Chat did not open. Evidence:
`/tmp/pickup-route-crosstab-red2.xcresult` (0/1 passed). Discover now explicitly
owns chat deep links; other SessionDetailView instances cannot consume them.
The reviewer found no remaining Required/Critical issue after this adjustment.

The first fresh/reused-detail green run passed 2/2, including Back without replay
and a second alert for the same session: `/tmp/pickup-route-green.xcresult`.
Final broad verification is recorded below when complete.

## Test isolation and limits

Debug simulator-only controls queue the same AppState intent used by the push
handoff. They are absent from Release and physical-device builds. They do not
simulate APNs or exercise AppDelegate notification parsing. UI smoke Chat skips
loading and realtime; its destination/title is under test, not message delivery.
Existing synthetic HTTP, in-memory authentication, deny-network and system-effect
guards remain in place. No normal live-account simulator was used as a test host.

UI simulator: `0966AA82-8FE2-4792-907C-1821CD81361E`, iOS 26.3 runtime.
Unit simulator: `64AEF375-F64B-4C6B-AD31-C3471D8DF1F7`, same runtime, normal signing,
`PICKUP_UNIT_TESTS=1`. Test logs/result bundles are under `/tmp/pickup-route-*`.
An intermediate broad UI run was intentionally interrupted for the cross-tab
regression. Its immediate successor failed before runner bootstrap with a
termination signal; neither is a behavioral result. The next cross-tab run
started normally and reproduced the expected assertion failure.

## Candidate and remaining gates

Read-only App Store Connect check around 11:19 Eastern: build 6 remains latest,
Complete in uploads and Ready to Submit in the iOS build list, assigned to
Internal Testers. No newer/processing upload was visible. Build 7 is available
for local candidate preparation, subject to an immediate pre-upload recheck.
No store fields were saved.

A future candidate containing this change needs separately approved upload and
internal distribution, installation identity checks and a new bounded physical
notification retest. The cancelled October 28 fixture remains closed; a new live
fixture requires a fresh exact draft approval. Existing broader acceptance,
operations/recovery decisions and public listing gates remain open.

The owner explicitly replaced earlier continuation cutoffs with **92% used / 8%
remaining** in the five-hour window. No reset credits may be consumed.

## Final verification checkpoint

- Full iOS 26.3 UI run: **14/15 passed**, including all four new routing/link tests.
  Existing account-switch test timed out dismissing the system password prompt.
  Result: `/tmp/pickup-route-ui-final.xcresult`.
- Full signed isolated units: **370/374 passed** on iOS 26.0 after correcting a
  stale test expectation that hard-coded build 5 instead of reading CFBundleVersion.
  Four rendered accessibility lookup tests remain failing: ChatViewModelTests
  `testRenderedHistoryPrependKeepsTheReadingPosition` and UXFlowTests
  `testAccountSwitchActionsCarryTheEmail`,
  `testAccountSwitchesReplaceTheScreenInsteadOfStackingForms`, and
  `testCardOpenAndParticipationAreIndependentAccessibleActions`.
  The same four failed on iOS 26.3; runtime drift alone does not explain them.
  Result: `/tmp/pickup-route-units-final.xcresult`. These failures remain untriaged;
  no clean full-suite or release-ready claim is made.
- Targeted account-form recheck encountered long simulator idle/animation waits;
  inspect `/tmp/pickup-route-account-recheck.log` before treating it as evidence.
- No build 7 version bump/archive/export was prepared. Next: resolve broader test
  failures, freeze/package a reviewed build 7 locally, then request specific upload
  and internal-distribution approval. Physical alert routing remains unverified.


October 29 follow-up resolved the local verification blockers without changing
product behavior: visible-Simulator units passed 374/374, and the corrected bounded
system-password-prompt UI helper passed its previously failing scenario. See
[verification evidence and limits](2026-10-29-verification.md). Historical failed
runs above remain retained evidence; the current cutoff is 80% used / 20% remaining.
