# Build 9 physical read check — October 30, 2026

TestFlight on the mirrored iPhone showed **PickUp UCF1.0(9),90days,Open** before
any update action. Its detail page independently showed Version1.0/Build9/Open.
The candidate was already installed; this agent did not perform its installation.
Nonprivate screenshot: `/tmp/pickup-build9-phone-testflight.png`.

Opened from TestFlight. Authentication restored and Discover rendered the empty
feed. My Games loaded its15-item past history. Opened the existing controlled
Basketball/RWC Park/October30/09:00–10:30 game, previously recorded as fixture
`5246793e-aeae-4ab7-b825-14672e0d002e`. Detail visibly showed CANCELLED and2/2,
with the original test-only notes. No fixture was reopened or changed.

Tapped Session Chat at **2026-10-30T20:46:26.691Z** (16:46:26 Eastern).
The first screenshot at20:46:27.308Z showed Loading messages during navigation.
The next sample at20:46:34.876Z showed the one retained synthetic routing-test
message, empty composer and inactive Send. This establishes visibility within
the8.185-second sampled interval, not an exact fetch duration or performance SLA.
No new chat message, Calendar export, join/leave, report/block or provider setting
change occurred. Returning Back showed the cancelled detail again. Subsequent
Mirroring scroll attempts did not reliably move the view, so a second Chat entry
is not claimed; no product scrolling defect is established by these attempts.

The App Store Connect internal tester row separately reported Installed1.0(9),
iPhone17/iOS27.0.1 on October30. Device Settings OS was not independently re-read.
No physical iOS17, offline/retry, account-transition, provider, Calendar,
VoiceOver/Dynamic Type or new APNs acceptance is claimed. Build7's actual
notification tap and build8's retained-chat re-entry remain separate evidence.
No unchanged local test suites were rerun for this read-only check.
