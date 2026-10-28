# Build 6 hybrid check — October 28, 2026

Owner approved one October 28 10:30 AM Eastern Basketball / RWC Park / capacity 2 /
Any / nonrecurring fixture, warning notes and cancellation by 11:00 AM. Owner then
clarified no second physical device was available and explicitly requested the
Xcode simulator as the second client. This is hybrid evidence, not two physical
devices or physical iOS 17 acceptance.

## Clients and fixture

- Host: iPhone 16e simulator, iOS 26.3, normal Release 1.0 (6). Build succeeded
  using the locked dependencies; `git diff 2d4310d --exit-code -- ios` passed.
  Dependency-lock SHA-256 matches candidate provenance. Production configuration
  verified without printing credentials. Existing distinct controlled account
  restored; no sign-in or credential entry needed. No simulator session was copied
  to the phone. Build log: `/tmp/pickup-build6-hybrid-build.log`.
- Participant: physical phone through Mirroring, previously verified TestFlight
  1.0 (6). Existing separate controlled account retained. Source-matched simulator
  build is not the distributed TestFlight binary.
- Backend: approved October 27 migration head `20261023232500`, send-push v19.
  No deployment, provider or account changes in this run.
- Fixture: `ff86908c-64ca-4fe7-994b-65e9aca0fc0e`, Basketball, RWC Park,
  October 28 10:30 AM–12:00 PM Eastern, capacity 2, Any. Repeat weekly was
  explicitly observed off before publication. Original warning notes preserved.

## Observations

| Check | Evidence | Limit |
| --- | --- | --- |
| Create | Simulator normal UI submitted once; detail showed correct sport/venue/time/level, warning notes and 1/2 | No recurring/custom-location check |
| Discover and join | Phone Discover rendered new fixture at 1/2; Join completed to 2/2 and Leave; phone detail showed both profiles | Server independently confirmed full/2/2 |
| Foreground host → participant chat | Phone Chat was opened before host sent; labeled message appeared without a phone refresh | One synthetic message |
| Foreground participant → host chat | Phone reply appeared in the simulator's already-open Chat | Native typing introduced a harmless typo in synthetic reply; no account/content effect |
| Live Activity registration | Fixture had one active token after phone join | Not proof of Lock Screen appearance |
| Leave/rejoin | Physical Leave completed to 1/2 with Join available; rejoin restored full/2/2 independently in SQL | No waitlist test |
| Retained chat | Host reopened Chat and both earlier messages remained | No offline check |
| Live Activity display | Physical Home screen visibly showed the Basketball icon/countdown in Dynamic Island after rejoin | Lock Screen layout not independently captured |

Two synthetic messages exist. Their outbox creation times were 10:00:34.443 and
10:00:51.603 Eastern, with sent markers at 10:01:01.411 and 10:01:01.570.
The host-join row was created 09:59:26.406 and marked sent 10:01:01.084. These
timestamps establish queue processing only, not APNs acceptance or alert display.

Focus crescent initially remained visible. Owner subsequently confirmed Focus off,
phone locked and idle before dispatch of the background test.
Mirroring disconnected twice for actual phone use and resumed after owner locked
the phone. Connection interruptions are not app failures.

## Background delivery and routing defect

One additional synthetic host message was sent with the phone visibly at Home.
Its outbox row was created **10:04:34.697 Eastern** and marked sent at
**10:05:01.324**. Recipient had one ordinary alert token and one active activity
token, and the stored payload had `open_chat = true`. Bounded 10:04:30–10:06:15
function log aggregates returned zero APNs-rejection or retry events. This does
not independently prove provider acceptance.

After the full observation window ended at 10:06:31, the owner checked the alert
and reported: **“alert arrived, but opening only took me to session page, not
session chat.”** Delivery is owner-confirmed; correct chat navigation failed.
Do not close the notification gate or submit this candidate as fully accepted.

Source inspection found that SessionDetailView consumes chat intent only within
its initial session/user-keyed task. A notification targeting an already-existing
detail may not rerun that task. This is a hypothesis requiring a local regression,
not an established root cause or a verified fix. There is no product-source change
at this checkpoint. Preserve initial-load authorization and account-transition
guards when designing the regression and fix.

Owner clarified they tapped the **chat notification itself**, not the Live Activity.
The routing result remains an open release blocker. Local `simctl push` attempts
used the retained cancelled fixture and a synthetic payload with `open_chat: true`;
the banner appeared, but automation did not establish a successful tap/open path.
No local failing regression or fixed result is claimed. Payload retained at
`/tmp/pickup-build6-route.apns`. No additional server messages or live games were
created by these local notification injections.

Next: reproduce initial-load and already-loaded-detail chat notification routing
with a persistent, controllable local notification/UI path. Check AppDelegate's
payload handoff, AppState's one-shot intent, Discover navigation reuse and the
SessionDetailView task/destination timing. Keep actual chat authorization intact;
do not merely force Chat for every session URL. Add a meaningful failing regression
before changing product source, then verify isolated tests/UI and a later approved
exact-candidate device retest. Current TestFlight build 6 is unchanged.

## Cleanup completed

Host cancelled the fixture through the normal simulator UI around 10:09 Eastern,
well before the approved 11:00 deadline. The first read showed cancelled with two
pending cancellation rows/two active tokens. After the scheduled worker cycle,
an independent read confirmed **cancelled, zero active Live Activity tokens and
zero pending outbox rows**. Retained player_count 2 is history, not an active game.
No Calendar copy, report, block, deletion or provider change was made. Three total
synthetic messages remain as retained test history. No further live fixture is
approved by this record.

At the closing checkpoint five-hour usage was 64% used / 36% remaining, approaching
the owner's mandatory 65%-used stop. Do not start another live fixture or continue
work past 35% remaining. No reset credit was used.
