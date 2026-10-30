# Build 8 physical read check — October 29–30, 2026

## Installed candidate

After the owner restored Mac/phone readiness, Mirroring connected to iPhone17.
TestFlight's Apps screen showed **1.0 (8), Update**. Selected that update, then
independently observed **1.0 (8), Open** and launched it. Saved authentication
restored and Discover rendered. This was the normal latest-build Update path;
no older-build warning or automatic-updates preference change occurred.

Source/archive/processing identity and376/376 signed isolated units are recorded
in [the build8 candidate](2026-10-29-build-8.md). The phone's Settings OS version
was not independently re-read; prior App Store tester metadata reported27.0.1.
No physical iOS17 or two-physical-device claim is made.

## Read-only retained Chat

Opened My Games, expanded the15-item history, and opened the retained controlled
October28 Basketball/RWC Park/10:30 fixture
`ff86908c-64ca-4fe7-994b-65e9aca0fc0e`. Its detail visibly showed CANCELLED,2/2,
old test-only notes and the two controlled profiles. No Join/Leave, edit, Calendar,
report/block, new message, provider/account change or live fixture was performed.

Tapped Session Chat at **2026-10-30T03:58:43.058Z** (October29,23:58:43 Eastern).
The first captured Chat frame, **4.264seconds after the tap**, already showed all
three retained synthetic messages, empty composer and disabled Send. This is a
sampled upper observation bound, not an exact fetch duration or performance SLA.

Back returned to Session detail. Mirroring scroll/tap input was initially not
reliable in that retained view, so the check returned to history and opened the
same cancelled game again. Explicitly raising the Mirroring window restored
reliable input; no product scrolling defect is established by those attempts.
Tapped Chat again at **2026-10-30T04:08:28.914Z** (October30,00:08:28 Eastern).
At the next captured frame **5.415seconds later**, the same three messages were
visible again, with empty composer/disabled Send. The re-entry route was
Chat→Back→detail→Back→history→same game→Chat. Do not relabel it as an immediate
in-place detail-to-Chat re-entry or a forced device cancellation-race reproduction.

No long-lived Loading messages state was observed in these two samples.
The deterministic task-cancellation race remains covered by the local regression;
this bounded normal-device read/re-entry does not prove the cause of build7's
unmeasured temporary delay or every possible network/cancellation ordering.

## Independent fixture state

A production read during this check confirmed:

| Retained fixture | Status | Messages | Active activity tokens | Pending outbox |
| --- | --- | --- | --- | --- |
| October28 `ff86908c-64ca-4fe7-994b-65e9aca0fc0e` | cancelled |3|0|0|
| October29 `5246793e-aeae-4ab7-b825-14672e0d002e` | cancelled |1|0|0|

Both fixtures remained cancelled; no new message/notification was sent. The phone
was left in the old retained Chat with no composer draft. Build7's actual APNs
chat-notification tap passed in its separate record; no new build8 APNs tap was
manufactured here. Broader exact-candidate offline/Calendar/provider/account-
transition/accessibility/iOS17/external/public-release gates remain open.
