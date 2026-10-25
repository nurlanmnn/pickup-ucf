# Chat realtime subscription diagnostics — October 25

## Contract and scope

BETA-10 needs to answer whether a chat subscription returned, failed, was cancelled
or was superseded by closing/restarting the chat, and which finite channel states
were observed while that lifecycle remained current. Add local realtime_operation
JSON in ChatViewModel.swift, with exactly event, operation, result, failure,
attempt_id, duration_ms, version, build, configuration, environment. Operations
subscribe/channel_status. Subscribe results returned/failed/cancelled/superseded;
status results subscribing/subscribed/unsubscribing/unsubscribed. Terminal precedence:
stale lifecycle is superseded; current caller Task.isCancelled is cancelled;
otherwise throw is failed and return is returned. The SDK may itself throw
CancellationError on connection failure, so that error alone never implies caller
cancellation. Failure only
none/cancelled/unknown (the SDK's subscription error type is internal). Never infer
transport/backend cause from raw error text. All enum inputs are closed. Duration
is elapsed monotonic time from this start invocation, including status observations;
it is not time since last message or an aggregate health metric. Attempt UUID is
fresh per actual subscription and shared with that invocation's status observations.

Preserve every lifecycleVersion/cancellation/loaded guard, original stream setup
before subscribeWithError, subscribed refresh, syncError mapping, tasks and
unsubscribe/remove order. Record the terminal outcome even after supersession,
without applying stale UI state. Do not log intentional stop as a confirmed remote
unsubscribe. No messages, channel/session/user IDs, credentials, tokens, payloads,
URLs, raw error/status text or server codes enter records. A returned subscription
or subscribed status never proves message delivery or caught-up history. No new
provider, telemetry upload, metrics, alert owner or broad transport abstraction.

## Test strategy and implementation order

1. Review the isolated harness design and schema adversarially before changes.
2. Use Network.framework's websocket listener explicitly bound to IPv4 loopback
   with an ephemeral port in the existing ChatViewModelTests.swift. The real pinned
   Supabase SDK gets only that numeric loopback URL and synthetic key; discard auth
   storage, disable auto-refresh/app lifecycle, and deny all HTTP via URLProtocol.
   No configured backend URL/key, DNS, SDK-internal fake or vendor changes.
3. Verify actual Phoenix v2 join filter, subscribe response, finite status and
   subscribed refresh; reject join, withhold acknowledgement for bounded timeout,
   close/restart and task cancellation. Server/test waits bounded and cleanup
   cancels listeners/connections and disconnects client. No sleeps as correctness
   assertions; bounded predicate waits may yield briefly to async work.
4. Inject a record sink first, prove missing diagnostics red while original
   behavior assertions pass, then instrument the existing lifecycle unchanged.
5. Focused tests, full normally signed isolated unit suite on established 16e,
   unsigned Release build/analyzer, actual Logger JSON privacy inspection, final
   fresh-context review, docs, commit and authorized feature-branch push.

Files: existing ChatViewModel.swift, ChatViewModelTests.swift, this plan, handoff,
todo and master readiness doc. No new source registration/dependency/config needed.
Use Swift/XCTest and existing diagnostics conventions (closed Encodable record,
OSLog public only for allowlisted JSON; numeric bundle values). Keep BETA-10/11
partial and all production/device/release boundaries unchanged.

Commands (scheme supplies PICKUP_UNIT_TESTS=1 and bootstrap isolation):

```sh
xcodebuild test -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -parallel-testing-enabled NO -only-testing:PickUpUCFTests/ChatRealtimeDiagnosticsTests -resultBundlePath /tmp/pickup-realtime-focused.xcresult
xcodebuild test -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -parallel-testing-enabled NO -resultBundlePath /tmp/pickup-realtime-full.xcresult
xcodebuild build analyze -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pickup-ui-release-derived CODE_SIGNING_ALLOWED=NO
```

Official references: [Supabase subscription](https://supabase.com/docs/reference/swift/subscribe),
[Phoenix v2 protocol](https://supabase.com/docs/guides/realtime/protocol),
[Apple websocket protocol](https://developer.apple.com/documentation/network/nwprotocolwebsocket),
[required local endpoint](https://developer.apple.com/documentation/network/nwparameters/requiredlocalendpoint).
Pinned SDK Types/RealtimeChannelV2/ChannelStateManager inspected for actual behavior.

## Design review and red/focused evidence

Fresh-context adversarial review identified the SDK's ambiguous cancellation errors.
The contract now gives stale lifecycle precedence over caller cancellation and
keeps the error category separate. A server phx_close during subscribe reproduces
failed/cancelled without caller cancellation; it is not mislabeled cancelled.
Cross-model review skipped for this autonomous continuation; no external CLI used.
Changelog index and linked TLS deprecation were inspected; no dependency, TLS or
protocol changes are part of this increment.

Initial eight real-SDK tests ran with only the record sink/schema installed, no
instrumentation calls: six tests failed with 14 absent-record assertions; all
original filter, refresh, error, cancellation and cleanup behavior assertions
passed. The first command found a pre-existing result bundle from October21 and
preserved it; the next build caught incorrect Supabase options argument order,
corrected before the actual red run. Red evidence is
`/tmp/pickup-realtime-red-v3.{log,xcresult}`.

After instrumentation, focused34 contained one test-ordering failure: a later
channel_status record could follow subscribe, so selecting records.last observed
failure none instead of the subscription's cancelled category. Select the last
subscribe record explicitly; no product behavior/assertion weakened. Corrected
focused suite passes **34/34** (10 new plus 24 existing ChatViewModel tests).
Actual focused default Logger output: 12 records passed JSON parse, exact ten keys,
operation/result/failure allowlists, unit_test environment, UUID/nonnegative
monotonic elapsed and privacy checks. Includes successful and failed subscribe
and status observations; this is separate inspection, not an automated capture
claim from the smoke test.

Final fresh-context source/test/privacy review found no remaining required issues.
Its optional combined cancellation-plus-stop regression was added and reviewed:
superseded wins, stale UI error/refresh suppressed, channels removed. There are
now 11 new runtime tests. Existing rendered chat tests still use their synthetic
chat-tests.invalid client; those may perform failing DNS websocket attempts.
Only the new harness claims numeric loopback-only websocket routing. All fixtures
remain synthetic, and no test uses configured backend credentials.

## Final validation

Final full normally signed isolated unit suite passes **333/333**, including all
11 new real-SDK runtime tests, existing real Keychain and four rendered AX tests.
Established 16e/iOS26.3.1 AX values read1/1 before restart, after restart and after
the suite. Unsigned Release simulator build and analyzer pass. Full actual default
Logger output also has12 records; all pass the same exact-schema/privacy checks.
No unchanged UI/SQL/Edge suites repeated, no live backend/device/provider action,
no deployment/merge/upload. This is local synthetic lifecycle evidence; broader
health reporting, delivery, authenticated UI and provider/device acceptance remain
open. BETA-10/11 stay partial.

Artifacts: `/tmp/pickup-realtime-red-v3.{log,xcresult}`,
`/tmp/pickup-realtime-focused-v2.{log,xcresult}` (initial assertion-order failure),
`/tmp/pickup-realtime-verified.{log,xcresult}` (34/34),
`/tmp/pickup-realtime-full-v2.{log,xcresult}` (333/333),
`/tmp/pickup-realtime-release-analyze-v2.log`.
The full run contains the final combined precedence test; no redundant focused
rerun was needed after it. DerivedData remains `/tmp/pickup-diagnostics-derived`
and `/tmp/pickup-ui-release-derived`. No SDK/vendor/project registration changes.
