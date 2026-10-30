# US launch preparation — October 30, 2026

The owner selected US-first preparation after asking whether territories can be
expanded later, then requested continued work until 20% of the five-hour allowance
remains. Apple permits later availability changes in App Store Connect; a new
binary is not needed solely to add territories. Review submission/release remain
separate gates in the publishing plan.

## Saved draft metadata and configuration

- Public version remains iOS 1.0, Prepare for Submission.
- Promotional text, description and keywords use the reviewed local listing
  draft. Copyright: `2026 Nurlan Mammadli`.
- Subtitle: `Find your next campus game`; primary category Sports; secondary
  unset. Reload confirmed subtitle/category persistence.
- Release preference changed from automatic to **Manually release this version**.
- Pricing base United States (USD), selected **$0.00**. The wizard's comparison
  schedule also showed zero prices in other currencies; that is not availability
  in those storefronts.
- Availability selected **Specific Countries or Regions**, only **United States**.
  Future-country automatic availability remained unchecked. After confirmation
  and reload: **1 Available**, **174 Not Available**; available tooltip named only
  United States.
- Apple-silicon Mac and Apple Vision Pro availability are both off after save and
  reload. The binary targets iPhone only. Public distribution method unchanged;
  no paid agreement, banking, tax or trader declaration was accepted/changed.
- Support URL remains the deployed and verified dedicated support page.

Evidence screenshots: `/tmp/pickup-store-copy-saved.png`,
`/tmp/pickup-app-info-saved.png`, `/tmp/pickup-us-availability-saved.png`.

## Remaining preparation

Three [creation-flow screenshots](assets/2026-10-30/README.md) were rendered,
visually checked and uploaded to the required iPhone Dynamic Island medium slot.
Reload confirmed all three filenames and **3 of 10 App Screenshots**. RGB JPEGs
are1206×2622 without alpha. Raw normal-Release build8 captures remain unchanged;
the static layout adds headings and a proportional frame. No fake game feed,
account details, participants or messages appear. The draft form was discarded
without publishing a game. Browser viewport override was reset afterward.

Build **8** was selected and saved as the draft public candidate; reload confirmed
the row. Manual release remains selected. This did not submit review or release.
Reviewer first/last name and public support email plus generic navigation/permission
notes were saved. Reviewer username/password and phone remain unfilled in the
public version form. The existing TestFlight username was configured; no password
was obtained/entered and no credential was transferred into the simulator. Its
previously saved session restored after the initial welcome frame.

Age-rating wizard capabilities were prepared through Step1 (no parental controls,
age assurance, unrestricted in-app web access, advertising or under13 restriction;
yes UGC, chat and conservative social/discovery capability), then **Cancel** at
Step2 without choosing content frequencies or saving the declaration. These are
draft interpretations for owner review, not an assigned rating. No content-rights
declaration, privacy revision, review submission or release was saved.

Content-rights audit found a missing Open-Meteo weather attribution in build8's
forecast row. The provider's current pricing/licence guidance requires attribution
and identifying data modifications. A small local UI fix is being validated;
build8 must be replaced by its successor before public submission. No backend,
API calls, weather parsing, purchases or provider settings are changed by that fix.

Physical phone resumed its retained synthetic Chat successfully, then profile
loaded its saved details. The sports editor was opened incidentally while the
profile's loading layout shifted; returned with Back without edits or Save.
Settings opened, but later Mirroring paused and the phone moved to another app;
no new physical acceptance row is claimed. Do not treat this as offline, VoiceOver,
Calendar or account-transition proof. The old October4 reviewer fixture instructions
must not be reused as current game data.

Owner subsequently confirmed the necessary content rights. In a separate App
Information tab, selected **Yes, it contains, shows, or accesses third-party
content, and I have the necessary rights**, Done and Save. Reload confirmed
**Yes, this app has the necessary rights to its third-party content.** Evidence:
`/tmp/pickup-content-rights-saved.jpg`. This records the owner's declaration,
not an independent legal opinion. Reviewer-field entry remains owner-controlled;
the previously saved TestFlight username was identified privately at the owner's
request and was not copied into this repository.

Sources:
- [Apple availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/)
- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [Open-Meteo attribution requirement](https://open-meteo.com/en/pricing)

## Afternoon continuation

Owner-entered demo credentials and reviewer contact information persisted on a
fresh load, with Save disabled. Presence was verified without recording values.
Notes was empty on that fresh read; preserved the owner's current saved state.
Changed only the draft selected build from8 to9 and saved/reloaded successfully;
manual release and populated private fields persisted. Review remains unsubmitted.

The internal group's Builds table independently confirms1.0(9) Testing. The
physical phone already had9 installed; saved-session launch and a retained
synthetic Chat read passed bounded checks in the
[device record](2026-10-30-build-9-device-check.md).

Read-only App Privacy inspection confirms the same nine linked data types and
displayed purposes as `ios/PickUpUCF/PrivacyInfo.xcprivacy`: functionality for all,
plus personalization for Fitness/User ID. No privacy answer was changed. This is
label/manifest parity, not a new provider-retention or end-to-end privacy audit.

The owner confirmed expected rare profanity/substance references/mild suggestive
themes. The [completed age declaration](2026-10-30-age-rating-proposal.md) saved
and reload-verified13+ on current OS/12+ before26. No Kids category or override
was selected. App Review submission and final candidate acceptance remain open.
