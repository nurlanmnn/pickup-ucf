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
  **Fresh login is pending.** No credential was read from App Store Connect or
  transferred to the simulator by the agent.

This is source-matched local reviewer preparation, not the uploaded TestFlight
binary or physical-device acceptance. No game, chat message, account, moderation
action, provider setting or Calendar copy was created by these steps. Old
reviewer seed schedules remain historical; no new live reviewer fixture is
approved by this record.

## Read-only checks after owner sign-in

Verify Discover, My Games and past history, available synthetic game/chat detail,
Profile and Settings. Confirm the ordinary reviewer has no Review reports entry;
do not grant a role. Record only pass/fail and counts of approved synthetic data.
Do not inspect or capture private profile fields, account identifiers or real
user conversations. Do not create missing fixtures or send a message without the
separate concrete fixture authorization. A saved authentication session alone
does not prove reviewer-ready data or notification/Calendar/provider acceptance.
