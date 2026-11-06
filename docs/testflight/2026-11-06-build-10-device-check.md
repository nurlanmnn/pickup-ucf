# Build 10 physical read check — November 6, 2026

## Identity and scope

The owner confirmed updating the phone and readiness for Mirroring. TestFlight's
settled PickUp UCF detail showed **Version1.0,Build10,90days,Open** before launch.
The owner performed installation; the agent did not claim installing it.
Screenshot: `/tmp/pickup-build10-phone-testflight.png`.

Mirroring connected to the device advertised as iPhone17. Exact hardware and OS
were not independently read from Settings. The older store tester metadata is
not a fresh OS verification and this is not an iOS17 acceptance claim.

## Observed results (10:34–10:35 Eastern)

- Opening from TestFlight restored authenticated Discover without a sign-in or
  onboarding form. The initial My sports filter rendered its empty result.
- Switching to All loaded the live feed, including an available game. It was not
  joined, opened, edited, cancelled, copied to Calendar or otherwise touched.
  No venue/schedule/account data from that game is copied into this record.
- My Games settled to **No upcoming games**. Nonprivate screenshot:
  `/tmp/pickup-build10-phone-my-games.png`.
- Expanding Past games loaded **15 shown**. A Mirroring scroll visibly moved the
  list and collapsed the large navigation title; the first historical card became
  fully visible. This verifies one scroll, not the entire history or long-page
  accessibility acceptance. No historical game or chat was opened.
- App Switcher backgrounding and TestFlight → Open returned to the authenticated
  My Games screen with its loaded history and scroll position retained.

An attempted app-card dismissal through Mirroring scroll and drag did not
reliably remove the PickUp card. The agent stopped rather than treating it as a
successful force quit. The observed return is **foreground resume**, not a cold
launch or force-quit recovery result. No unrelated app was opened or dismissed.

No sign-out, account switch, new fixture/message, join/leave, notification,
Calendar export, report/block, account deletion or provider setting change
occurred. Existing cancelled fixtures were not reopened. No unchanged local
suite was rerun.

## Remaining boundaries

Physical signed-out intro gestures, VoiceOver, Dynamic Type, offline/retry,
force-quit recovery, account/token/chat isolation, Calendar/provider cases and
physical iOS17 remain open. Current signed-in browsing does not close those rows
or exact TestFlight reviewer authentication/fresh reviewer-data acceptance.

At73% of the five-hour allowance used, the owner was asked to approve one
separate bounded sign-out/intro-navigation check followed by owner-entered sign-in.
That approval is pending; no sign-out has been performed under this record.
