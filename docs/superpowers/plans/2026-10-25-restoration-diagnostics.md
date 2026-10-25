# Auth restoration diagnostics — October 25

## Contract

Instrument only AuthRepository.currentSession with one local auth_operation
completion, operation restore, after the original guards and cleanup finish.
Extend the existing closed ten-field AuthOperationDiagnostics schema; no new
metadata or generic telemetry framework. Fresh UUID per invocation and monotonic
duration include the session lookup, verification and suppressed local cleanup.

Restore-specific result values: session_missing (SDK sessionMissing),
unavailable (other SDK session lookup error),
rejected_cached (cached mapping fails or cached confirmation is absent), verified
(remote user maps, matches cached identity and passes confirmation plus current
account guard), rejected_remote (mapped remote identity/confirmation fails),
invalidated (existing known invalidation codes), superseded (existing current-user
guard fails, including SDK cache removal), cached_fallback (other verification/mapping error with matching
current account). Coarse failure uses existing enum classification; local guards
use local_policy, unavailable/SDK errors use coarse classes. Superseded may retain
coarse verification failure, never its raw error. SDK sessionMissing becomes
session_missing with failure none: the underlying cause is unavailable. This
does not establish the pre-invocation cache state or backend health. A cached
fallback is explicitly not verified. Never use succeeded for restore.

Preserve exact SDK session/user requests, mapping, guards/order, local signout
scope, nil returns, cached fallback and error suppression, including cancellation
fallback. Do not add auth policy. Logs do not claim local cleanup succeeded.
Suppressed cleanup errors do not change the primary rejection/invalidation
classification; those outcomes describe the restore decision, not cache removal.
No raw error, code, email, user ID, access/refresh token, URL, content or inputs.
Only Apple unified local logs; existing numeric bundle allowlists/environment.
No provider, alerting, configuration, production/device action or new upload.

## Verification plan

Fresh-context adversarial design review; real SDK synthetic HTTP/storage red and
green tests for verified/unavailable/cached and remote rejection, invalidation,
offline/backend/decoding/cancellation fallback, account transitions during remote
success/error, failed cleanup suppression, fresh retry IDs, exact JSON schema and
privacy. Retain existing real-Keychain persistence tests. Focused/full signed unit
suite with AX prerequisite check; unsigned Release build/analyzer; actual Logger
schema inspection; final independent review and authorized feature-branch push.
BETA-10/11 remain partial; authenticated UI and provider/device acceptance open.

## Diagnostic questions and sources

Did restore return a server-verified identity, keep the cached identity after
verification failed, or return nil? Which existing decision produced nil? What
coarse failure and duration/build accompany that decision? No outcome identifies
a user or attributes a decision to a specific account transition.

Official session/user docs:
https://supabase.com/docs/reference/swift/auth-getsession
https://supabase.com/docs/reference/swift/auth-getuser
Pinned SDK AuthClient/APIClient/SessionManager and AuthError establish actual
behavior: sessionMissing can also arise after SDK refresh invalidation, and some
verification errors remove SDK storage before the repository race guard runs.
Superseded means only that existing guard failed (including SDK cache removal),
not proof that the human switched accounts. Session absence cannot establish why
the SDK lacks a session. Cleanup failures retain original primary classification.

## Review and focused evidence

Fresh-context design review identified absence/failure wording and suppressed
cleanup ambiguity; both contracts clarified before implementation. Optional
cross-model review offered asynchronously; no CLI invoked without owner response.
The original source ran eight new real-SDK tests: seven failed on absent diagnostic
records, while auth behavior assertions passed (48 missing-record assertions).
First instrumented focused27 tests had two expectation failures: SDK automatic
cache removal caused superseded rather than invalidated. Explicit expectations
now distinguish SDK cleanup (no repository logout) from repository invalidation
cleanup. No product or auth-policy assertion weakened. Focused28/28 passed,
including 16 explicit-auth, nine restore and three real-Keychain persistence tests.
Added a final focused check for invalidation with a failing local logout request.
Artifacts /tmp/pickup-restore-{red,focused,verified}.log and focused/verified xcresults.

Final fresh-context review found an actionable naming issue: initial SDK
sessionMissing can mean empty cache or SDK-cleared expired/revoked refresh. Renamed
no_cached_session to session_missing; added a real-SDK expired/session_expired
refresh regression checking token request, cache removal and single outcome.
No extra cache reads, requests or policy were introduced. Superseded explicitly
includes SDK-cleared cache. Both are bounded observations, not inferred causes.

Local Apple logs use the existing auth_operation category/subsystem edu.ucf.pickup.
Restoration outcomes are informational decisions, not automatic alerts; elapsed
latency is repository-local. System retention applies and info logs may remain
memory-only. These records cannot prove SDK-cache removal, platform recovery,
provider availability or user-visible authentication success. No central metrics,
reporting provider or owner notification policy was introduced.

## Final verification

Full signed isolated suite passes **311/311** on established iPhone16e/iOS26.3.1,
including all 11 restoration diagnostics, 16 explicit-auth and three real-Keychain
persistence tests. Final restore additions/name changes were verified in this full
run after focused28/28; no redundant focused rerun. No skips/assertion weakening.
Before the full run, restarted simulator and read both documented AX preferences
as1/1. Unsigned Release simulator build and analyzer pass. Actual focused/full
Apple auth_operation logs: ten records each checked for exact ten-field schema,
UUID/nonnegative duration and synthetic-secret/code/URL absence; full includes
four restore records (fallback, invalidated, fallback, verified), none succeeded.
Typed capture tests cover the other outcomes and suppressed cleanup failures.
Final independent follow-up review found no unresolved required issues.

Artifacts: /tmp/pickup-restore-full.{log,xcresult},
/tmp/pickup-restore-release-analyze.log. No unchanged UI/SQL/Edge suites repeated.
No phone reconnect, production mutation, config/deployment, binary upload, external
provider/review or account action. Existing TestFlight1.0(5) lacks this source.
BETA-10 and BETA-11 remain partial; broader reporting/metrics/alerts, other critical
flows and authenticated UI/permissions/CI/device acceptance are still open.
