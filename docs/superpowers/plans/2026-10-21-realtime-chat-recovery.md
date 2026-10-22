# BETA-08 — Realtime author identity and recovery

Continue the session/chat workstream after pagination and atomic creation. No backend migration is
needed: use existing RLS-protected message reads with the same minimal author projection.

- [x] Reproduce incoming messages losing an already-known sender identity.
- [x] Add a bounded, short-lived, per-chat author cache seeded only from authorized message reads.
  Resolve unknown senders in batches of message IDs, not one profile request per event. Missing or
  hidden authors use Player; blocked authors remain hidden. Refresh names on foreground/reconnect.
- [x] Catch up after subscription and foreground/reconnect, paging down from newest until the prior
  conversation overlaps. Preserve loaded older history, deterministic ordering, and retry cursors.
  Show a recoverable synchronization error and avoid overlapping refreshes.
- [x] Cancel lookup/subscription tasks and reject stale lookup/catch-up responses when the chat closes. Cover concurrent senders,
  duplicate events, missing authors, rename, blocking during fetch, cancellation, failures/retry,
  and gaps larger than one page.
- [x] Run relevant and full signed simulator tests, Release build/analyzer, and update readiness
  evidence. Physical-device/two-account realtime operation remains a separate release check.

Sources checked October 21: Supabase Swift subscribe and IN-filter documentation, plus the resolved
SDK's statusChange/subscribeWithError implementation. Register change/status streams before subscribing.

## Contract and behavior

- Cache up to 100 sender summaries in this chat model for 60 seconds. The cache is neither global nor
  persisted. Authorized history/send reads seed it; a cache hit labels the next event immediately.
- Coalesce misses for 75ms, one representative message per sender, with at most 50 message IDs in each
  read. Query `messages` constrained to this session and IDs, with the existing minimal profile join
  (`id, display_name, username`). No service key, new RPC, profile enumeration, or broader grants.
- Missing/deleted/hidden profile metadata uses Player. Negative cache entries also expire after
  60 seconds. Blocking removes the sender's rows/cache/queued lookup; in-flight results cannot restore it.
  Already-loaded names update on the next successful resolution or foreground/reconnect refresh,
  not through a global profile subscription. Account-wide deletion cleanup remains BETA-09.
- On a successful subscription (including rejoin), and when the app becomes active, catch up from the
  newest REST page toward the last verified history page. An unverified realtime insert cannot stop
  catch-up early. Keep older loaded history and its cursor. An initially empty conversation loads a
  newest page and offers older pagination rather than downloading unbounded history at once.
- Fetching/retrying preserves current messages and the draft. Recovery errors offer Retry; sender
  lookup errors and message catch-up errors are separate. Lifecycle/revision guards reject late
  results and prevent an older lookup undoing a newer name/visibility refresh.

## Evidence

The first regression failed with Player instead of the already-authorized @knight. Tests additionally
cover 120 simultaneous unknown senders in three requests, repeated/missing senders, cache expiry and
eviction, blocking during a request, lookup retry, stale lookup after rename, close during lookup/catch-up,
a 120-message reconnect gap with a newer realtime event already present, and catch-up failure/retry.

The existing history-render test now checks the actual anchored message's accessibility frame as well
as substantial scroll movement. Its old proxy (estimated content-height delta) became inaccurate when
the connection banner changed the LazyVStack viewport; the actual message position stayed within one
row. Normal and Accessibility XXXL test renders are inspected separately from network/device evidence.

This work changes only the app and its tests. No production migration or dependency update is required.
Live two-account WebSocket reconnect/foreground operation and physical-device VoiceOver remain release
checks; synthetic HTTP/state tests do not establish those outcomes.

Sources: [Swift subscription](https://supabase.com/docs/reference/swift/subscribe),
[Swift IN filters](https://supabase.com/docs/reference/swift/in), and the resolved SDK source.

Final validation: **230/230 signed simulator tests passed**, including 24 focused chat tests and the
real-Keychain session regression. Result: `/tmp/pickup-realtime-final2.xcresult`. Unsigned generic-device
Release build and static analysis passed (`/tmp/pickup-realtime-release-final.log`); the only metadata
warning reports that no AppIntents framework is used. Diff hygiene passed. Both normal and Accessibility
XXXL renders were inspected; the retry action now fits without truncation, and the status text leaves
room to read the conversation. This is synthetic simulator layout evidence, not a full device
accessibility sign-off. Attachments: `/tmp/pickup-realtime-attachments-final/`.

Reviewed the final implementation for ordering, pagination continuity, bounded reads/cache, permissions,
blocking, lifecycle cancellation, and stale metadata responses. This source work is local on
`codex/realtime-chat-recovery`; the prior pushed main snapshot remains separate. Next source workstream
in the readiness backlog: BETA-03's aligned client/server content limits; release/device gates remain open.
