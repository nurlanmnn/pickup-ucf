# Device-token backend diagnostics — October 25

## Contract

Instrument DeviceTokenRepository's actual register RPC, unregister RPC and
owner-filtered compatibility delete. Local device_token_operation records have
exactly the established ten fields: event, operation, result, failure, attempt_id,
duration_ms, version, build, configuration, environment. Operations register_rpc,
unregister_rpc, delete_owned_token; results succeeded/failed/cancelled; coarse
failure none/cancelled/transport/backend/decoding/local_policy/unknown. A new UUID
per register/unregister invocation; unregister RPC and optional delete share it.
Each duration covers only its stage. Numeric bundle allowlists and unit-test
indicator follow existing diagnostics. No token, payload, identity, raw Error,
server code, URL or input enters the record. No external telemetry/provider.

The question answered is which backend stage failed, whether compatibility cleanup
was attempted, and whether it returned without throwing. Succeeded means only
that stage returned; a delete may affect zero rows under RLS. Neither success nor
failure proves APNs delivery, whole account cleanup or notification consent.
Missing-RPC remains a failed RPC followed by a separately reported delete; no
whole-unregister success is emitted. Missing current user remains a failed local
policy guard with no DELETE. All original requests, payloads, exact filters,
PGRST202-only fallback, thrown errors and request order remain unchanged.
PushNotificationService and LiveActivityTokenRepository remain unchanged in this
slice. Rotation's ignored unregister failure becomes visible at the repository;
existing retries, serialization, quarantine and account-transition behavior remain.
The closure initializer's no-op registration is not evidence of backend coverage.

## Plan and verification

Fresh-context adversarial design review, then tests against the real pinned SDK
with synthetic URLProtocol and isolated auth storage. Red proof for absent
records while preserving behavior assertions. Cover register/unregister success,
RPC errors, compatibility success/failure, missing user, exact POST payload and
DELETE owner/token filters, transport/cancellation, fresh retry UUIDs/shared stage
UUIDs, exact schema/privacy, default Logger output. Exercise rotation and bounded
account-transition retry using the real repository and existing service; retain
existing service/account tests. Focused and full signed isolated simulator tests;
Release build/analyzer; final fresh-context source/privacy review; docs and
feature-branch commit/push. No unchanged UI/SQL/Edge runs. BETA-10/11 partial.

Official references inspected: https://supabase.com/docs/reference/swift/rpc and
https://supabase.com/docs/reference/swift/delete. Delete docs explicitly require
filters and note RLS may produce zero affected rows. Existing API usage stays.

## Review and focused evidence

Fresh-context adversarial design review found no required issues. Initial nine
real-SDK tests ran with the diagnostic sink wired but no log calls: eight tests
failed with 29 absent-record assertions; all original payload/filter/error/service
state assertions passed. Instrumented focused suite passed 33/33 (nine new tests,
17 repository/service and seven account-transition tests). Added final real-SDK
checks for quarantine after register failure and cleanup retry success. No product
assertion weakened. Default Logger test is explicitly a smoke test; actual output
is inspected separately, not claimed as an automatic log-capture assertion.

Fresh-context final code/privacy review found no required issues. Its optional
smoke-test naming suggestion was accepted; review of both final added tests found
no required or optional issues. Cross-model review skipped for this autonomous
continuation; no external CLI invoked. No Supabase changelog entry required a
change to the pinned RPC/DELETE usage; no dependency or database changes.

## Final validation

Full signed isolated suite passes **322/322**, including 11 new real-SDK
DeviceTokenDiagnosticsTests and all existing repository/service/account-transition,
Keychain and four rendered AX tests. Established iPhone16e/iOS26.3.1 settings
read AX1/1 before and after restart. Unsigned Release simulator build and analyzer
pass. Focused and full actual default Logger captures each contain six records;
every record passed JSON parsing, exact ten keys, closed operation/result/failure,
unit_test environment, valid UUID, nonnegative duration and privacy checks.

Artifacts: /tmp/pickup-device-red.log, /tmp/pickup-device-focused.{log,xcresult},
/tmp/pickup-device-full.{log,xcresult}, /tmp/pickup-device-release-analyze.log.
DerivedData: /tmp/pickup-diagnostics-derived and /tmp/pickup-ui-release-derived.
No unchanged UI/SQL/Edge suites repeated. No phone, provider, production, account,
deployment, merge or upload action. Broader reporting/metrics/alerts, service
cleanup decisions, realtime health and authenticated UI/permission/CI/device gates
remain open. Local backend stage diagnostics do not close BETA-10/11.
