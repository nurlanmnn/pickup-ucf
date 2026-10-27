# BETA-11 isolated game-detail navigation

## Objective and boundaries

Extend the existing authenticated Debug-simulator UI lane from tabs/forms into
future and past game details, using only the two existing synthetic fixture IDs.
No real account, backend, Keychain, socket, ActivityKit or Calendar operation is
permitted. No create/join/leave/chat/report mutation is added in this increment.
Normal/unit/Release/device behavior and existing passing assertions stay intact.
The phone notification investigation can proceed independently when available.

## Design and ordered work

1. Before widening fixture HTTP, add immutable test-mode seams defaulting to
   AppTestMode.current at the realtime and Live Activity boundaries. UI mode must
   return before channel cleanup/creation/subscription, repository construction,
   Task dispatch, or manager access. Guard every coordinator entry, including
   scheduled cleanup and account-transition cleanup. Preserve normal task order.
2. Prove these boundaries with red/green tests. A loopback Network.framework
   websocket server must count accepted connections (not merely decoded frames);
   normal loaded detail is the positive connection control. Both UI modes must
   make no connection and create no SDK channel. Inject per-call effect spies for
   ActivityKit/repository work; call the actual coordinator methods, rather than
   testing a policy helper that could be bypassed. No mutable global test hook.
3. Only after isolation passes, allow exact singleton game GETs and exact
   get_session_roster RPC bodies for the two fixture IDs. Return object/array
   shapes matching actual SDK repository decoding. Unknown IDs, duplicate or
   conflicting selectors, malformed/bodyless/extra-key RPC bodies, auth and all
   mutations remain denied. Exercise via real SDK as well as adversarial requests.
4. Add actual UI navigation assertions for future hosted and past completed game
   details, visible location/time/roster and safe Back navigation. Do not tap
   Calendar, Maps, Share, Chat, host mutation or profile-report actions. Omit the
   map subview before construction in UI mode: missing coordinates still invoke
   geocoding/fallback MapKit. Skip local Calendar-receipt singleton construction
   as an isolation precaution; it eagerly constructs an EKEventStore.

## Files and verification

Use Core/SupabaseManager.swift, Features/SessionDetail/SessionDetailViewModel.swift,
LiveActivity/GameLiveActivityManager.swift, focused unit tests and existing
UnauthenticatedSmokeTests.swift. Preserve existing style and dependency defaults;
do not refactor unrelated manager/repository behavior. Review design and final
diff with fresh-context adversarial review before committing verified source.

Run focused isolation/fixture tests, expanded UI suite, signed isolated full unit
suite, unsigned Release build and analyzer for product changes. Use existing
PickUpUCF and PickUpUCFUISmoke schemes, iPhone16e simulator
2680E61B-4AAF-4A52-9B42-5C5C36777DC1, and /tmp derived data/results. All unit
commands must set PICKUP_UNIT_TESTS=1 and use normal simulator signing. Restore
simulator AX1/1 and restart before full units if UI lane left it at0/0. Inspect
retained UI screenshots and verify built UI backend URL/key empty. No unchanged
SQL/Edge suite needed. git diff --check and privacy review before commit/push.

Stop at five-hour usage >=85% or required owner input; save a focused continuation
when context fills. Merge/deploy/upload are separate from source verification.

## Review and reproduced boundaries

Design review required testing actual coordinator entries with immutable per-call
mode/effect seams (unit process current mode cannot select UI branches), socket
connection counts before cleanup, and each normal/unit effect separately. Normal
Task/actor boundaries and default manager calls are retained. Calendar receipt
lookup is local, but its singleton eagerly constructs EventKit; skipping that
construction in UI mode is a precaution, not a reproduced Calendar write bug.

Isolation red: `/tmp/pickup-detail-isolation-red-verified.log`, four focused tests,
eight failed assertions. Both UI modes opened a loopback connection and reached
forbidden coordinator effects; both positive normal/unit controls passed. Initial
inverted expectation overfulfilled and crashed; disabled its overfulfill assertion
before collecting this verified red result. Green isolation21/21 and expanded
focused34/34 passed before final parser/test strengthening.

Fixture red: singleton detail rejected by old fixture, and four foreign/conflicting
selectors returned synthetic data instead of denial. Duplicate-key red separately
reproduced two raw JSON bypasses. Foundation collapses keys, so roster now accepts
only one literal p_session_id key/literal UUID member before decoding. JSON ASCII
whitespace only, absolute anchors, exact ID allowlist and512-byte data/stream bound.
Escaped keys/values, extra/duplicate keys and appended JSON are intentionally denied.

Initial detail UI navigation passed, but was not sufficient isolation evidence:
coordinate-free custom locations still invoke geocoding and MapKit fallback.
New map-absence assertion failed in `/tmp/pickup-detail-map-red-verified.log`.
UI mode now omits SessionLocationMap before construction. Subsequent test failures
were incorrect test expectations: past dates use weekdays rather than Yesterday,
and the runner's Azerbaijani locale differed from the English-only app UI. The
expectation now uses explicit English weekday formatting; no product date logic
was changed. Final focused navigation passes1/1 with visible time/roster and map
absence assertions. A briefly overlapping simulator build was cancelled before
launch; all accepted simulator runs are sequential.

Bundle inspection caught inherited public backend values in intermediate UI
commands. The verified isolation marker still selected synthetic client/storage,
but final acceptance requires SUPABASE_URL= and SUPABASE_ANON_KEY= build overrides.
The full UI gate is run with these empty settings and the resulting Info.plist
must be independently checked. Release build/analyzer pass; pre-existing unused
diagnostic-result warnings and the standard AppIntents metadata warning remain.

The first empty-config full UI attempt encountered repeated60/120-second idle
waits in the unchanged account-route test and was interrupted after over eleven
minutes; it is not a pass. Simulator restart recovered the focused unchanged
test to40.2s,1/1 pass (`/tmp/pickup-detail-auth-after-restart.log`). The full gate
is rerun sequentially on that restarted simulator with the same assertions.

## Final verification

- Expanded credential-free UI11/11 passed in305s after restart. Built UI bundle
  SUPABASE_URL/SUPABASE_ANON_KEY independently verified empty. Four retained
  future/past time/roster screenshots exported and visually inspected; no map
  controls, complete names/notes, and appropriate host actions. No mutation/system
  buttons tapped. `/tmp/pickup-detail-ui-full-after-restart.{log,xcresult}` and
  `/tmp/pickup-detail-ui-final-attachments/`.
- Restored simulator ApplicationAccessibilityEnabled/AccessibilityEnabled from0/0
  to1/1, restarted and verified1/1 before signed isolated unit lane. Final full
  suite374/374 passed, including realSDK HTTP/bodyStream decoding, adversarial
  selectors/bodies, seven coordinator effects in both UI and normal/unit modes,
  and realSDK loopback websocket negative/positive controls.
  `/tmp/pickup-detail-unit-full.{log,xcresult}`.
- Unsigned generic-device Release build and analyzer passed. Existing unused
  diagnostic-result warnings in DeviceTokenRepository/ProfileRepository and the
  standard AppIntents metadata warning remain; no new compiler warning found.
  `/tmp/pickup-detail-release.log`.
- Fresh-context design/final review findings reconciled; final map/parser delta
  review found no remaining issue. git diff --check and privacy review pass.
  SQL/Edge suites retained because unchanged. BETA-11 remains partial; this is
  read-only synthetic detail navigation, not physical mutation/permission/CI or
  production/provider acceptance.

Commands executed from repository root (result paths identify this run):

```sh
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCFUISmoke -configuration Debug -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-ui-release-derived -resultBundlePath /tmp/pickup-detail-ui-full-after-restart.xcresult SUPABASE_URL= SUPABASE_ANON_KEY= test
PICKUP_UNIT_TESTS=1 xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Debug -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-unit-derived -resultBundlePath /tmp/pickup-detail-unit-full.xcresult test
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/pickup-unit-derived CODE_SIGNING_ALLOWED=NO build analyze
```
