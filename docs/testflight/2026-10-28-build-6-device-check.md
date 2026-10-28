# Build 6 physical check — October 28, 2026

Bounded iPhone Mirroring check around 09:41–09:44 Eastern. TestFlight's Apps
screen showed PickUp UCF **1.0 (6)** with **Open**, rather than an install/update
button. Opening it restored the existing signed-in session. No installation or
credential entry was performed. CoreDevice reported the iPhone unavailable even
while Mirroring worked; do not use that status to claim Mirroring was unavailable.
The device's iOS version was not independently re-read during this check.

The compatible backend baseline is the separately approved
[October 27 rollout](../operations/2026-10-27-production-rollout.md), migration
head `20261023232500` and send-push v19. This session did not re-audit production.

| Check | Observation | Limit |
| --- | --- | --- |
| Launch/session | Brief welcome screen, then saved session restored and Discover rendered | Not a clean sign-in or account-transition test |
| Discover/My Games | Empty 48-hour Discover and no upcoming joined games; past history expanded to 15 shown | Does not test discovery/join of a fresh game |
| Profile/Settings | Loaded saved profile, statistics and preferred sports; Settings opened | No account/profile settings saved |
| Notification preferences | App reports notifications allowed; all six displayed toggles enabled | Focus crescent visible; no OS settings changed, no delivery claim |
| Create validation | Selected Other, left sport name empty, tapped Next; readable required-name error scrolled into view | Unpublished local draft only; no successful create/edit acceptance |
| Draft cleanup | Closed draft, confirmed Discard, returned to Notifications | No game was published |
| Retained cancelled game | Existing October 26 Device Test remained CANCELLED; venue map, two-player roster and saved host notes rendered | Read-only check; no reopening, live edit propagation or new two-account test |

Initial navigation sometimes captured transition/loading frames. Final observations
above use settled views. A tap while Profile was loading opened Edit sports after
the layout shifted; returned without selecting or saving anything. Do not report
this as a settings mutation or a reproduced product defect.

No messages, reports, blocks, Calendar copies, accounts or provider settings were
created/changed. No private identifiers or content are included in this record.
The phone remained in the existing cancelled game's detail view after inspection.

## Next gate

The request below was subsequently approved and completed using a simulator second
client. The new fixture is cancelled with zero active tokens/pending outbox rows.
See [hybrid results and the notification-routing blocker](2026-10-28-hybrid-build-6-check.md).
The original pending checkpoint below is retained as dated context.

Owner approval was requested for one new October 28 10:30 AM Eastern Basketball /
RWC Park / capacity 2 / Any / nonrecurring synthetic game, cancellation by 11:00 AM,
and second-account participation. No approval has been received at this checkpoint
and no fixture has been created. Recheck time, phone readiness and the exact draft
before acting; an unanswered request is not approval. Keep older fixtures cancelled.

Notification dispatch/presentation/navigation, live two-account actions, offline,
Calendar, account-transition, accessibility, provider flows, deletion and the
physical iOS 17 lane remain open. This is partial exact-build evidence.

## Local support-page preparation

Added `privacy-site/support.html` to fill the store listing's dedicated support-URL
gap. Static page uses the established public support mailbox and policy links,
native expandable FAQs and light/dark styling, with no JavaScript or third-party
assets. Local HTTP and policy links returned 200. Browser rendering and FAQ
expansion passed; narrow layout reported viewport/content width 341/341 with no
horizontal overflow, and console warning/error log was empty. Text/link contrast
was checked in both palettes (all at least 6.5:1). Preview:
`/tmp/pickup-support-preview.png`.

Code review checked wording against existing app routes, native disclosure and
heading semantics, privacy, link paths and layout. No required issue remains.
Chrome DevTools MCP was unavailable; the connected in-app browser supplied visual,
DOM and console checks. No unchanged iOS/backend suites were repeated for this
static page. Production deployment and App Store Connect URL entry remain pending.

Current continuation stop rule: stop at **65% used / 35% remaining** in the
five-hour window, or when required user input blocks the next action. Never consume
reset credits. Latest checked usage during this work was 16% used / 84% remaining.

After the physical checks and support-page preparation, a fresh Chrome tab opened
App Store Connect and redirected to `/login`. The metadata audit cannot continue
without owner sign-in; no credentials were entered or store fields changed. The
tab was retained for handoff. Source/support and evidence commits `e890ba6` and
`3cf0e85` were pushed to `origin/codex/calendar-write-only`; no merge occurred.
