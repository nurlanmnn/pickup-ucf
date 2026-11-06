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
The owner approved that exact scope. The results below supersede the earlier
read-only scope for this one sign-out only.


## Approved signed-out intro check (10:40–10:41 Eastern)

The owner approved one sign-out, intro navigation and return to owner-entered
Sign in. Through Settings → Sign out → Sign out confirmation, the agent signed
out once. The settled app returned directly to **page3**, with Sign in reachable
and no visible server-cleanup warning. Screenshot:
`/tmp/pickup-build10-phone-signed-out-page3.png`. This is UI evidence; no independent
per-token server deletion or account-switch isolation claim is made.

Back moved3→2→1, Continue moved1→2, and the third page button moved2→3. Each
selected indicator, page heading and sport artwork matched the destination.
Normal-text dark layout showed the full page copy and reachable bottom actions.
Sign in then opened the empty credentials form. No credential was read or entered
by the agent, and no second sign-out or account switch was performed.

Mirroring horizontal scroll inputs in both directions did not move the page.
This does not establish a product gesture failure; simulator touch-swipe tests
passed, while physical touch swiping is still unverified. The owner was asked to
Back from Sign in, touch-swipe3→2→3, report the result and sign back in directly.
No phone observations will be taken during credential entry. Owner-reported
swipe/sign-in results were subsequently supplied as recorded below.


The owner subsequently reported **Both swipes worked; signed back in**. This
supplies owner-reported physical touch-swipe3→2→3 and successful sign-in evidence
for TestFlight10, separate from simulator and Mirroring button checks. The next
Mirroring observation showed **iPhone in Use / Lock your iPhone to connect**;
no post-sign-in authenticated screenshot was available. The agent did not inspect
credential entry, request credentials or claim independent post-sign-in landing
verification. No additional sign-out is authorized or needed for this run.
