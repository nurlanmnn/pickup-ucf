# Store listing draft and audit — October 27

Local copy only. No App Store Connect fields changed, no assets uploaded and no
declarations submitted. Confirm the exact shipped candidate before using this.

## Read-only audit

- Public iOS 1.0 remains Prepare for Submission with no selected build.
- Description, keywords, support URL, copyright and reviewer/contact fields were
  empty in the public-version form. Subtitle was empty in App Information.
- Primary category remained the Primary placeholder; age ratings displayed
  Set Up Age Ratings; content rights displayed Set Up Content Rights Information.
  Owner decisions are still needed before entering those declarations.
- The version form currently selects Automatically release this version.
  No release preference changed; obtain the owner's intended release timing
  before eventual submission.
- App Privacy is published with the expected privacy-policy URL and nine linked
  data types: name, email address, fitness, precise location, emails/text messages,
  other user content, user ID, device ID and product interaction. This records
  existing declarations; accuracy against the final binary still needs review.
- Screenshot slots, accessibility declarations and pricing/territories were not
  audited in this pass. Do not infer completion or absence from this record.

## Copy for review

Name: **PickUp UCF**

Subtitle: **Find your next campus game**

Suggested primary category: **Sports**. Leave secondary unset unless the owner
selects a useful fit. This is a proposal, not a saved category.

Promotional text:

Find pickup sports around UCF, join a game, and coordinate with other players.
Create a session when you have a sport, time, and place in mind.

Description:

PickUp UCF helps the UCF community find and organize pickup sports games.

Browse upcoming games, see where and when people are playing, and join a session
with an open spot. Organizing a game? Choose a sport, time, venue, and player limit,
then share the details with your group.

- Discover games in list and map views.
- Create, edit, and cancel games you host.
- Join or leave games and check the roster.
- Coordinate in session chat and manage game notifications.
- Add an independent copy of a game to your calendar.
- Use reporting and blocking controls when you need them.

Sign up with an eligible UCF email address. Location, Calendar, and notification
permissions are optional for basic browsing and sign-in. Calendar copies are
independent of the game and do not update when a host edits or cancels it.

Keywords:

`UCF,pickup,sports,basketball,soccer,volleyball,tennis,campus,games`

Copyright proposal: **2026 Nurlan Mammadli**; owner to confirm rights holder.

Support URL: select a public page with usable support information after checking
its rendered content; do not use a mailto URL in the URL field. Marketing URL is
optional and remains unproposed here.

October 28: dedicated `privacy-site/support.html` is prepared and verified locally.
Proposed URL after approved deployment and an HTTPS recheck:
`https://pickup-ucf-privacy.vercel.app/support.html`. It has not been deployed or
entered in App Store Connect; local verification is in the build-6 device record.

Browser recheck during build-6 processing: the existing privacy-policy page
renders successfully and includes a Contact section with the support mailbox,
worded for privacy questions/requests. This verifies the current contact path;
it does not establish a dedicated general app-support page or mailbox delivery.

## Candidate-specific internal testing note

Build 6 includes more reliable session edits, visible sport-name validation, and
clearing of abandoned password drafts. It also adds privacy-safe diagnostics and
isolated UI coverage. Test game creation/editing, two-account chat and notification
routing, Calendar copy behavior, offline recovery, accessibility, and account
switching on the exact candidate. The compatible backend rollout and device
acceptance remain separate gates; do not present them as complete.

Reviewer credentials/contact details must be entered privately. Existing October 4
reviewer game descriptions require a specifically approved refresh before review.

## October 28 read-only follow-up

Owner sign-in restored access. Public version remains Prepare for Submission,
with empty copy/support/reviewer fields and no selected build. Automatically
release this version remains selected; no preference was changed.

The selected iPhone with Dynamic Island (medium display) screenshot panel shows
0 of 3 App Previews and 0 of 10 App Screenshots. This does not inventory every
device-size/localization slot. Header shows 0 of 1 asset; it is not treated as a
required screenshot. No assets were uploaded.

Pricing and Availability shows Add Pricing and Set Up Availability. No price or
territory selection is established by this audit. Apple silicon Mac availability
is checked; Vision Pro availability is disabled and the page says version 1.0 is
not compatible. Public distribution and the Apple School Manager reduced-price
option are selected. These are existing settings, not owner-confirmed release
choices. Resolve pricing, territories, Mac availability and release timing before
public submission; no settings were saved.

App Accessibility shows Get Started; no supported-feature declarations were
entered. Do not declare VoiceOver, larger text or other support without completing
the corresponding candidate acceptance checks.

## October 30 support completion

After explicit owner approval, the dedicated support page was deployed and
verified live. Only Support URL was saved as
`https://pickup-ucf-privacy.vercel.app/support.html`; reload confirmed it persisted.
This supersedes the historical undeployed/empty support statements above.
The public version remains Prepare for Submission, with no selected build and
the other version copy/reviewer fields still empty in this read. See the
[deployment packet](../operations/2026-10-29-support-deployment-packet.md).
