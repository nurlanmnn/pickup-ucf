# Dedicated reviewer preflight — October 30, 2026

## Credential checkpoint

The owner confirmed replacing the dedicated demo credential after the earlier
capture. A reload of the public version form confirmed username/password/contact
fields populated, Save disabled and build9 selected. This checked presence only,
not values or authentication validity. No credential or account identifier is
recorded here. Reviewer Notes remains empty in App Store Connect; the
[current local proposal](2026-10-30-reviewer-notes-draft.md) is not saved there.

## Isolated local reviewer instance

- Simulator: **PickUp Reviewer Preflight 9**, iPhone16e/iOS26.3, UUID
  `84A3A61C-BEF7-463F-B75A-2364FD24BD0B`.
- Created a new device; existing production/manual and unit simulators were not
  reset, signed out, overwritten or used for these steps.
- Normal **Release** build of PickUpUCF succeeded, with zero build errors.
  Existing compiler warnings are not claimed resolved. No unit/UI suite rerun.
- iOS source has no diff from candidate `d2ef6f6`; dependency lock SHA256 remains
  `c49789ce6396caa4d3fe4c7b1595001c68ea69d5137745e9185a2671be15aacd`.
- Product plist verifies bundle`edu.ucf.pickup`, version1.0/build9 and
  iphonesimulator platform; executable contains the weather-credit text.
- Derived data: `/tmp/pickup-reviewer-9-derived`; build log:
  `/tmp/pickup-reviewer-9-build.log`.
- Installed and launched normally, observed Welcome then opened **Sign In**.
  Empty-form screenshot: `/tmp/pickup-reviewer9-signin-ready.png`.
- Owner was asked to enter the dedicated credentials directly in that window.
  The owner subsequently confirmed signing in. No credential was read from App Store Connect or
  transferred to the simulator by the agent.

This is source-matched local reviewer preparation, not the uploaded TestFlight
binary or physical-device acceptance. No game, chat message, account, moderation
action, provider setting or Calendar copy was created by these steps. Old
reviewer seed schedules remain historical; no new live reviewer fixture is
approved by this record.

## Read-only checks after owner sign-in

- **PASS, local normal Release9:** authenticated Discover is reachable without a
  sign-in/onboarding form. The owner entered the dedicated account directly.
  Selecting All sports and waiting for loading shows an empty feed, with no
  visible retry/error state. Nonprivate screenshot:
  `/tmp/pickup-reviewer9-empty-discover.png`.
- **PASS, local:** My Games shows no upcoming games; expanding history loads
  **five existing games**. This is a UI count, not a new backend inventory.
- **PASS, local historical read:** opened an old Basketball game whose notes
  contain a review marker and whose detail shows CANCELLED. Session Chat opens
  and shows **No messages**. No conversation content was copied or message sent.
- **PASS, local:** Profile and Settings load. A fresh full Settings tree contains
  community rules, blocked users, privacy, terms, support and account controls,
  with **no Review reports entry**. This verifies UI presentation only, not a new
  privileged backend-role/RLS test.
- **OPEN:** future/open reviewer game, joined game with synthetic chat history,
  separate report/block targets, and exact TestFlight reviewer sign-in. Existing
  historical records are not refreshed reviewer acceptance.

## Unpublished form/input check

Prepared a local Basketball/RWC Park/October31 09:00/90minute/capacity2/Any draft.
No Create session control was activated. Native AX setValue changed displayed
text before the draft's stepper/count reflected it. Ordinary capacity keyboard
entry committed2 to both steppers. Simulator paste then inserted prior clipboard
text rather than the supplied synthetic notes; that unpublished draft was
discarded through Close → Discard. No clipboard/account text belongs in evidence.

Using the debugging workflow, a second empty disposable draft isolated notes
entry. Five direct single-character key presses produced the expected synthetic
marker (case-insensitive) and a matching5/1000 counter. That diagnostic draft was
also discarded. Avoid paste/bulk typing for Simulator notes; use direct keys and
verify actual text plus character count before any publication. The exact
clipboard synchronization mechanism is not proven, and no product defect or
source fix is claimed. No unchanged test suite was rerun.

## Next bounded fixture proposal (not approved)

If run before October31 08:45 Eastern: one Basketball game at **RWC Park,
October31 09:00–10:30 Eastern, capacity2, Any, nonrecurring**, with a controlled-
test/do-not-join notice. Host: this reviewer simulator/source9. Recipient: the
existing controlled physical TestFlight9 account. Reconfirm phone readiness and
current Focus state, without changing it. Obtain explicit approval before
publication; the discarded form is not a published or approved fixture.

After approval, join only the controlled recipient, send one labeled synthetic
chat message, observe dispatch and actual notification arrival/tap separately,
and inspect weather attribution if an outdoor weather snapshot is present.
Cancel within15minutes of publication and verify cancellation, zero active
activity tokens and no pending fixture outbox before stopping. Do not start near
the80%-used allowance cutoff. If the schedule expires, prepare a new future
proposal rather than reusing it. Calendar copies, reporting/blocking and account
deletion are outside this proposal. Reviewer data for public review will need a
separately approved fixture lifetime; this short test is not that data set.

At the last allowance check71% of the five-hour window was used. No timed live
fixture was started with the80%-used stop approaching. Reset credits remain
untouched. Continue from the authenticated reviewer simulator; do not request
the password or repeat fresh sign-in unless that session expires.
