# BETA-10 Live Activity token backend diagnostics

## Contract

Instrument the existing LiveActivityTokenRepository.register SDK RPC boundary.
Extend the existing closed DeviceTokenDiagnostics operation enum with
`register_live_activity_rpc`; retain event/category `device_token_operation` and
its exact established ten fields. This is an additive operation for an APNs token
backend stage, not a new logging framework. No changes to existing operations,
classification, logger/privacy behavior or fallback logic.

Use a fresh attempt UUID per invocation and monotonic elapsed duration. Record
succeeded only when the actual SDK stage returns; failed/cancelled use the current
coarse thrown-error categorization. Cancellation describes the observed thrown
category, not inferred caller intent. Preserve exact RPC name, original session/
token values, parameter keys, returned Void and original errors. Do not add
validation, retries, fallbacks, auth lookups or cleanup. Keep ActivityKit caller's
existing try? unchanged. No claim of delivery, ActivityKit state, affected rows,
terminal cleanup, or production migration acceptance.

No token/session/user ID, content, raw errors, server code, URL or payload may be
logged. Existing metadata sanitization remains. Source lives in existing
Repositories/DeviceTokenRepository.swift and existing test registration.

## Verification

- Add injectable existing diagnostic sink with no emitted records first.
- Meaningful red runtime tests through real pinned Supabase SDK and synthetic
  URLProtocol verify missing records while exact payload/error behavior passes.
- Cover success/repeated invocations, RPC rejection including missing-RPC (no
  device-token compatibility fallback), transport/cancellation and default Logger.
- Every captured record: exact ten keys, event/operation/result/failure enums,
  fresh non-entity UUID, nonnegative monotonic duration, privacy exclusions.
- Focused DeviceTokenDiagnostics/DeviceTokenRepository tests, full signed isolated
  unit lane with established AX1/1, unsigned Release simulator build/analyzer.
- Parse actual default Logger output separately. No unchanged UI/SQL/Edge reruns.
- Fresh-context adversarial design/final review. Autonomous cross-model skip;
  feature commit/push only, no production/provider/device action.

Sources: existing DeviceTokenDiagnostics contract and
2026-10-25-device-token-diagnostics.md; pinned supabase-swift PostgREST SDK source.
Supabase changelog/docs were refreshed during the preceding UI slice in this chat;
no SDK/dependency/API upgrade is introduced.

## Owner-requested pause — October25

Owner explicitly paused work because usage limit is near. Do not resume, open a
continuation chat or schedule work until the owner asks. No active xcodebuild
remained when pause was checked.

Completed prior UI slice is clean/pushed commit93a4c18: UI7/7 with empty backend
URL/key, full signed isolated336/336, Release build/analyzer, screenshots and
fresh-context review pass; details in authenticated-ui-smoke plan/handoff.

This Live Activity slice is UNCOMMITTED WIP in DeviceTokenRepository.swift,
DeviceTokenRepositoryTests.swift and this plan. Design review found no required
issue. Sink-only initializer/enum plus runtime tests initially failed11 missing-log
assertions (red artifact /tmp/pickup-activity-token-red.{log,xcresult}). Minimal
record wrapper then added. Focused actual SDK DeviceTokenDiagnosticsTests plus
DeviceTokenRepositoryTests completed **32/32** at11:51:45 before pause check:
/tmp/pickup-activity-token-focused.{log,xcresult}. Four new tests cover payload/
fresh attempts, backend rejection/no fallback, transport/cancellation and default
Logger. No final review/full unit/Release run/actual Logger JSON parsing or commit
has occurred for this WIP. Next on authorized resume: inspect Git first, validate
actual Logger records, fresh-context final review, then appropriate full signed
unit and Release build/analyzer checks and docs/commit/push. Do not repeat the
unchanged7/7 UI/SQL/Edge lanes for reassurance. Established simulator AX was1/1
before/after last full336 suite; recheck before later full units. No production,
phone, credentials, deployment or upload action performed.

## Authorized resume and final verification — October25 evening

Owner resumed work in the parent launch-diagnostics chat, authorized Mirroring
again and requested a stop at15 percent remaining usage. The earlier pause is
superseded. Existing focused32/32 was inspected rather than repeated. Actual
focused and final-full default Logger output each contain8 records, including2
register_live_activity_rpc records (succeeded/backend-failed); exact ten keys,
UUID/nonnegative duration and absence of synthetic sensitive inputs/codes checked.
Fresh-context final source/test review found no required issues.

Established16e AX1/1 read before restart and after restart. Final signed isolated
unit suite passes **340/340**; unsigned Release simulator build/analyzer pass.
Artifacts /tmp/pickup-activity-token-full.{log,xcresult} and
/tmp/pickup-activity-token-release-analyze.log. No unchanged UI/SQL/Edge reruns.
No production RPC test or APNs/ActivityKit/provider success is implied by these
local synthetic backend-stage tests.
