# Build 7 hybrid notification check — October 29, 2026

Owner instructed continuation after reviewing the revised October30/09:00 draft
and relative cleanup window, and confirmed Focus Off immediately beforehand.
The later instruction to continue until finishing superseded the earlier80%-used
stop for completing this test and its teardown; the agent did not consume a reset credit.

## Controlled fixture and clients

- Fixture `5246793e-aeae-4ab7-b825-14672e0d002e`, created October29
  **20:34:32.175 Eastern**, Basketball/RWC Park, October30 **09:00–10:30 Eastern**,
  capacity2, Any, nonrecurring. Explicit controlled-test/do-not-join notes and
  cancellation within15minutes of publication; deadline **20:49:32 Eastern**.
- Host: source-matched normal Release simulator1.0(7), iPhone16e/iOS26.3,
  UUID2680E61B-4AAF-4A52-9B42-5C5C36777DC1; retained separate controlled account.
- Recipient: physical iPhone17, TestFlight1.0(7), verified installed/opened earlier
  in this continuation. This is hybrid evidence, not two physical devices or
  simulator/TestFlight binary parity.
- Phone Discover found the fixture at1/2. Join completed; phone detail visibly
  showed FULL/2/2 and Leave. Independent SQL confirmed full, player_count2 and
  two distinct joined accounts. Recipient had one alert token and chat preference
  enabled. The phone retained that loaded detail, then Home was visually verified
  before the host message was sent. No phone settings were changed for this run.

## Notification observation

Sent exactly one labeled synthetic host chat message through the normal UI:
CONTROLLED BUILD 7 ROUTING TEST - please open this chat notification.

Outbox creation: **20:35:59.997 Eastern**. Sent marker: **20:36:01.851**.
Stored payload open_chat=true. A full90-second window completed at20:37:31.851;
clock recheck20:37:46 confirmed it had elapsed before the owner tap request.
Host-join row was created20:35:07.139 and marked sent20:37:00.478.
These markers prove processing only, not APNs acceptance or alert display.

After the window the owner was asked to tap the actual physical chat notification
and report Chat versus Session detail, then relock the phone for Mirroring.
The owner confirmed **alert arrived and tapping the actual chat notification opened
Chat**, then reported Loading messages. On reconnect around20:43 Eastern, Mirroring
showed Chat with the exact synthetic message. The owner subsequently confirmed
that it **loaded on its own**, without leaving/reopening Chat or restarting. The
initial loading duration was not measured, and its cause is not established.
This is a passing physical retained-detail route plus eventual content visibility,
not proof of immediate loading, every route case or complete release acceptance.

Host cancellation was confirmed through normal simulator UI before the deadline.
Independent SQL at **20:43:06.945 Eastern** confirmed **cancelled, zero active
Live Activity tokens and zero pending fixture outbox rows**. The synthetic message
remains retained test history; the fixture must not be reopened.

No second fixture/message, Calendar copy, report, block, provider/deletion action,
external invitation or public review submission occurred.


## Separately reproduced cancellation defect

Inspection found an initial-load cancellation path that could leave messages in
Loading and cause the next load call to return early. A deterministic local test
cancelled the task during the synthetic fetch, verified no late rows were applied,
and attempted another load. Before the fix it failed the non-loading/retry
assertions: `/tmp/pickup-chat-load-red.xcresult`. A lifecycle-invalidated control
case already passed because stopRealtime resets its own state.

The fix adds deferred cleanup only while the captured lifecycle still owns the
unfinished Loading state. It preserves successful/failed results and protects a
new lifecycle's active load from cleanup by an old task. Both targeted tests pass:
`/tmp/pickup-chat-load-green.xcresult`. The complete signed isolated visible-Simulator
suite passes **376/376**: `/tmp/pickup-chat-load-units.xcresult`. Independent review
found no Required/Critical issue. No tests were skipped or assertions weakened.

This local defect is proven; it is **not established as the cause of the phone's
temporary delay**. The change is not present in distributed build7 and needs a
new candidate for exact-binary acceptance. No further live fixture/message is
approved by this record. A fresh allowance was observed on resumption; the agent
performed no reset-credit action.
