# Chat repository local diagnostics — October 25

## Contract and diagnostic questions

BETA-10 needs to distinguish failure/latency of newest-page reads, older-page
reads, sends, and targeted message reconciliation. Add local `chat_operation`
records at the actual ChatRepository boundaries. `fetch_first` means no cursor,
including refresh; `fetch_older` means a cursor, including refresh catch-up.
`fetch_updates` covers both author resolution and retained-history reconciliation;
it does not claim the entire refresh or realtime subscription succeeded.

Each instrumented repository invocation emits exactly one completion record after
mapping/decoding, with a fresh random attempt UUID, monotonic duration and exactly
these fields: event, operation, result, failure, attempt_id, duration_ms, version,
build, configuration, environment. Use existing diagnostics conventions: typed
closed enums, numeric allowlisted bundle identifiers, Apple Logger subsystem
edu.ucf.pickup. No caller metadata, error text, SDK codes, body, author, identities,
entity IDs, timestamp/cursor, URL, credentials, tokens or precise location may
enter records. Coarse errors: cancelled, transport, backend (PostgrestError or
AuthError), decoding, unknown. Rethrow the original error unchanged.

Preserve all queries, select/filter/order/lookahead, page mapping, exact cursor
strings, insert normalization, returned rows and original validation errors.
Send validation stays before instrumentation; session lookup and insert share one
send boundary. Invalid local body and empty updates emit nothing and make no
backend request. Oversized updates preserve the existing precondition. No
ChatViewModel/protocol changes or cross-operation/global correlation.

## Implementation and verification

Source: Core/ChatOperationDiagnostics.swift and Repositories/ChatRepository.swift.
Tests: PickUpUCFTests/ChatOperationDiagnosticsTests.swift; retain pagination and
view-model regressions. Follow SessionMutationDiagnostics's typed record and
async rethrows wrapper; avoid a general diagnostics framework/refactor.

1. Fresh-context adversarial design review of contract/source boundary.
2. Synthetic SDK red tests, no real bootstrap/network/auth persistence/refresh.
3. Instrument repository; verify first/older mapping, payload and targeted query,
   normalization, empty/invalid no-op, original backend/auth/transport/decoding/
   cancellation errors, fresh retry IDs, exact JSON privacy schema.
4. Focused signed tests, full signed isolated suite after AX prerequisite check
   and simulator restart, unsigned Release build/analyzer. Spot-check actual
   default Logger output. Independent final review before commit/push.
5. Update readiness/todo/handoff and push authorized feature branch.

```sh
xcodebuild -project ios/PickUpUCF.xcodeproj -scheme PickUpUCF -destination 'platform=iOS Simulator,id=2680E61B-4AAF-4A52-9B42-5C5C36777DC1' -derivedDataPath /tmp/pickup-diagnostics-derived -parallel-testing-enabled NO test -only-testing:PickUpUCFTests/ChatOperationDiagnosticsTests -only-testing:PickUpUCFTests/ChatRepositoryTests
```

Full unit command omits only-testing and retains scheme PICKUP_UNIT_TESTS=1 and
normal signing. Release: same project/scheme, -configuration Release -destination
'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build analyze.

## Boundaries and operational use

Local Apple logs only; filter subsystem/category before inspection/sharing.
Retention is system-controlled; info logs may be memory-only. Each record answers
which boundary completed/failed, its coarse failure and elapsed duration/build.
It cannot prove provider availability, message delivery, subscription health or
user-visible reconciliation. BETA-10 remains partial: reporting approach,
remaining flows, central metrics, health/alert ownership remain open.
No new dependency, database/configuration/Edge change, external provider, deploy,
upload, phone installation or account mutation. Existing feature-branch commits
and pushes are authorized. October24 approved game fixture is now past and cannot
be published or rescheduled without owner approval; nothing was published.

## Sources

Official Supabase Swift select docs: https://supabase.com/docs/reference/swift/select
Pinned local SDK error definitions and existing session/auth diagnostics establish
actual typed classification; SDK API/query semantics remain unchanged.

## Review and focused evidence

Fresh-context design review found no required issues; wording clarified one event
per instrumented repository invocation rather than HTTP request. Independent final
source/project/test/privacy review and follow-up test review found no required
issues. The optional cross-model question was offered; no external CLI review ran.

Initial red failed on the missing ChatOperationDiagnostics type. File registration
initially duplicated PBX entries; corrected by adding exactly eight references
from the unchanged project baseline, retaining original IDs. plutil validates it.
First runnable focused lane passed13/14; the synthetic sign-in user fixture omitted
SDK-required updated_at. Added the field and a separate actual rejected-send SDK
regression; no product or validator assertions changed. Final focused passes
**15/15** (11 diagnostics + 4 existing pagination/query tests).

Observed simulator AX preferences were0/0 following the preceding UI gate.
Restored ApplicationAccessibilityEnabled1 and AccessibilityEnabledtrue, restarted
the established16e/iOS26.3.1 simulator and verified1/1 before signed unit testing.
No product/test weakening. Actual focused Apple Logger output:13 records checked
for exact ten-key schema and absence of synthetic secrets, backend code, URL and
cursor timestamp. Typed captured records also check entity IDs, result/failure,
UUIDs and nonnegative duration. Transport retries occur inside the SDK and still
produce one completion per repository invocation.

Artifacts: /tmp/pickup-chat-red.log; interrupted setup /tmp/pickup-chat-focused.log;
first runnable /tmp/pickup-chat-focused-fixed.{log,xcresult}; final focused
/tmp/pickup-chat-verified.{log,xcresult}. Local SDK query/return semantics were
checked against official select docs and pinned error definitions; changelog
scan found the upcoming TLS cipher removal, with no SDK/API change needed here.

## Final verification

Full signed isolated unit suite passes **300/300** on the established iPhone16e /
iOS26.3.1 lane, including prior rendered accessibility tests. No tests skipped or
assertions weakened. Full log contains13 actual chat_operation records;
all pass the same exact-schema/privacy check. Unsigned Release simulator build
and analyzer both pass. Artifacts /tmp/pickup-chat-full.{log,xcresult} and
/tmp/pickup-chat-release-analyze.log. No unchanged UI/SQL/Edge suites repeated.
Source remains absent from the installed TestFlight build5; no physical/provider/
production or release acceptance is implied.
