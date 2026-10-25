# BETA-11 bounded authenticated UI smoke

## Contract and scope

Extend the existing Debug simulator-only isolation policy with one exact alternative
launch argument, `--pickup-ui-smoke-authenticated`. It alone selects all isolation
guards before repositories initialize. Unsupported builds ignore it; the original
unauthenticated flag and unit-test behavior remain. No configuration, credentials,
provider authentication, persistent auth storage or bootstrap coordinator is used.

Seed a fresh in-memory SDK Session with synthetic identity/key/token and a future
expiry through explicit AuthLocalStorage and storageKey (pinned SDK SessionStorage
uses JSONEncoder/JSONDecoder). Disable automatic refresh. Seed AppState directly
from nil before RootView. This is synthetic navigation, not sign-in acceptance.

Use the existing real repositories/views. A private URLProtocol supplies bounded
JSON for profiles, venues, sessions, own participant reads and list_blocked_users
at exactly the synthetic HTTPS origin. Everything else, including writes/auth/
unknown origins, fails with unsupportedURL. HTTP interception does not establish
websocket isolation; this slice never opens chat or a realtime subscription.
Fixture definitions/transport/storage compile only for Debug simulator. Release
builds contain no fixture records or active UI launch mode. Suppress the My Games
Live Activity refresh in UI mode before any ActivityKit work is scheduled.

One future basketball game and one completed game exercise real decoding and the
My Games history read; profile shows a visibly synthetic name and nonzero stats.
Dates are relative to process launch. Reset only existing Welcome preference;
preferred sport contains basketball so both persisted All/My Sports show the game.
No create/join/chat/settings/permissions/account workflow is claimed.

## Acceptance and verification

- Red regression proves the new exact argument currently fails to select isolation.
- Policy tests cover exact/unsupported flags and absent configuration.
- Actual SDK/repository tests prove seeded auth identity, profile/feed/My Games/
  past/participants/venue/block-list reads and deny writes/auth/foreign origins.
- XCUITest verifies isolation marker before actions, actual Discover game, My Games
  upcoming/history, Profile name/stats and deterministic authenticated relaunch.
- Existing six unauthenticated tests remain green with built URL/key both empty.
- Focused/full signed isolated units and unsigned Release build/analyzer, retained
  screenshots inspected. Restore/check unit AX prerequisites after UI run.
- Fresh-context adversarial design/final review, then docs and feature-branch push.
  Cross-model review skipped in this autonomous context; no external CLI.

Sources: pinned supabase-swift Sources/Auth/Internal/SessionStorage.swift,
Sources/Auth/Types.swift and Sources/Supabase/Types.swift; official session docs
https://supabase.com/docs/reference/swift/auth-getsession (pinned source determines
actual error names). Changelog retrieved October25: current relevant breaking
change is November10 TLS cipher retirement; no dependency upgrade or remote TLS
transport is introduced here.

## Review and local evidence

The initial policy regression ran against unchanged source and failed two assertions:
the new argument selected normal mode and Service Unavailable. Artifact:
`/tmp/pickup-auth-ui-red.{log,xcresult}`. Design fresh-context review found no
required issues. Implementation lives in existing registered source files.

Initial focused AppConfig run passed the real SDK/repository happy path and new
policy checks. The denial/storage test exposed a test assumption: pinned SDK
`signOut(scope: .local)` clears local session **and still calls HTTP logout**.
The transport correctly rejected it. The test now expects this denial, verifies
session removal, independence of another fixture client's memory, and that the
original unauthenticated client has no session. No backend logout allowance added.
Artifact: `/tmp/pickup-auth-ui-focused.{log,xcresult}` (initial failing test retained).

Final source review found fixture-specific tests needed the fixture's exact
Debug/simulator compilation guard. Applied and re-reviewed; no remaining required
issues. Cross-model skipped in this autonomous context; no external CLI invoked.

Credential-free signed UI gate passed **7/7** on established iPhone16e/iOS26.3.1:
new synthetic Discover, My Games upcoming/history, Profile name and games count,
authenticated relaunch, then original unauthenticated relaunch; prior six UI tests
also pass, including actual accessibility5 path. Both built Info.plist backend
values verified empty. `/tmp/pickup-auth-ui-smoke.{log,xcresult}`; eleven retained
screenshots exported to `/tmp/pickup-auth-ui-attachments/`. All three new synthetic
screenshots inspected: expected game/history/profile controls render. Past-game
metadata continues below the initial My Games viewport; no full-history layout
or exhaustive accessibility acceptance is claimed.

Unsigned Release simulator build/analyzer pass:
`/tmp/pickup-auth-ui-release.log`. Release binary contains none of the checked
fixture name/location/access-token literals. Compiled real AppTestMode.current
with optimized non-Debug and Debug non-simulator host builds: authenticated flag
resolves to normal in both, independent of the policy helper's test parameter.

UI lane left simulator AX values at0/0. Restored both to1, restarted established
simulator, verified1/1 before full signed unit run and again afterward. Final
full signed isolated **336/336** passes, including11/11 AppConfig tests, existing
Keychain and all four rendered AX tests. Artifact:
`/tmp/pickup-auth-ui-full.{log,xcresult}`. No unchanged SQL/Edge suites repeated.
No physical device, production API, deployment, upload or account mutation.
