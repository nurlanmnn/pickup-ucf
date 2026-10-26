# October 26 simulator and physical-phone check

Manual real-account test against the linked production backend. This is separate
from the credential-free, network-isolated automated UI suite. Owner explicitly
approved the fixture, bounded two-account actions, three synthetic messages
(within the six-message cap), notes edit, and cancellation. No credentials,
account identifiers, tokens, or message bodies are recorded here.

## Clients and scope

- A: normal local Release simulator build from source `7762fe4`, iPhone 16e,
  iOS 26.3 runtime. Build succeeded; displayed app version 1.0 (5). This is
  current local source, not the same binary/source as the installed phone build.
- B: physical iPhone 17, paired metadata iOS 27.0.1 (24A446), operated through
  iPhone Mirroring. Owner completed sign-in directly on the phone. Distinct
  authenticated profile and both participant names were observed. Last verified
  installed distribution was TestFlight 1.0 (5); exact installed metadata could
  not be refreshed through CoreDevice, so current candidate parity is unproven.
- No merge, deployment, upload, migration, provider configuration, password
  change, account deletion, moderation report, or Calendar export occurred.

## Controlled fixture and results

Fixture `75822fd7-cdde-4aaa-a6e4-b1908fad73e4`: Device Test, Other sport,
RWC Park, October 26 10:30 AM–12:00 PM Eastern, capacity 2, Any skill,
no recurrence, explicit test/do-not-join/cancellation warning notes.
The earlier 10:00 draft was never published; owner approved changing to 10:30
before the single successful publication.

| Check | Evidence and limit |
| --- | --- |
| Create/discover | A created 1/2 fixture; B initially had stale empty feed. Switching Profile → Discover visibly fetched again and displayed the fixture. No RLS/discovery defect established. |
| Join/full roster | B joined, then displayed 2/2 and both distinct profiles. A detail refreshed on returning from Chat and showed 2/2. Immediate host detail update without navigation was not established. |
| Two-way chat | A message rendered on B after opening Chat; B reply rendered on A while its Chat stayed open. Three total synthetic messages persisted. Bidirectional already-open chat was only established for B → A. |
| Leave/rejoin | B Leave completed to 1/2 with Join available; rejoin completed to 2/2 with Leave available. Server independently showed full, 2/2 afterward. |
| Notes edit | A saved only the warning notes edit. Host UI and read-only SQL confirmed edited notes. B rendering of the edited notes was not checked. |
| Live Activity start | Owner confirmed Device Test appeared on physical Lock Screen. One active server token was observed. This is owner-attested physical rendering, not a captured Lock Screen screenshot. |
| Background chat alert | PickUp was sent Home before A's third message. Owner reported **no notification arrived**. Keep delivery acceptance open. |
| Cancel/Live Activity end | Host confirmed cancellation through normal UI and returned to My Games with no upcoming games. Server status cancelled; active token initially 1, later **0**. Owner confirmed Live Activity disappeared. |
| Temporary block/unblock | Not executed; deferred to preserve cleanup/usage headroom. No block was left behind by this test. |

## Notification evidence and next investigation

Read-only metadata scoped to this fixture showed three chat outbox rows marked
sent: two for B, one for A. B had one registered ordinary alert token; simulator
A had none. Both cancellation rows were also marked sent. The current local
`send-push` implementation can consume a row even when the recipient has no
tokens, so `sent_at` is never treated as proof of delivery. No provider acceptance
log or deployed function parity was established in this run. After cancellation,
B's in-app Notifications screen displayed “Notifications are allowed” and Chat
messages enabled. No toggle or authorization setting was changed. This narrows
the investigation but does not establish per-alert OS presentation settings,
Focus/Scheduled Summary state, or provider delivery.

Next: inspect Focus/Scheduled Summary and OS app-specific alert settings
read-only, then correlate the exact controlled
recipient/event with provider diagnostics. Do not silently change settings or
provider configuration. Retest background delivery and notification navigation
under a newly approved fixture; current fixture is already cancelled.

## Cleanup and remaining release gates

Final production check: cancelled fixture, 0 active Live Activity tokens. B's
refreshed All-sports Discover feed displayed no games after cancellation. Stored
player_count remains 2 as retained cancelled-session history; it is not an active
published game. No new Calendar copy was made. A separately exported October 25
Calendar copy may still exist and is not claimed cleaned up here.

This hybrid run supplies useful real two-account and one physical-device evidence.
It does not close iOS 17 physical acceptance, two-physical-device coverage,
account-switch token isolation, offline/reconnect, accessibility, block/unblock,
notification delivery/navigation, or exact release-candidate parity. Pending
source/deployment and App Store submission gates remain separate. Existing
automated 10/10 UI, 367/367 unit, Release/analyzer evidence is retained; no source
changed and unchanged suites were not rerun.
