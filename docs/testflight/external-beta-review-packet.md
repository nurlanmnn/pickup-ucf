# External TestFlight Review Packet

This file contains TestFlight metadata for the first external beta. Verify candidate-specific fields against the selected build before entering them in App Store Connect. Never put reviewer credentials, verification links, tokens, or account identifiers in this file.

## Candidate identity

- App: PickUp UCF
- Bundle ID: `edu.ucf.pickup`
- Version/build: `TBD`
- Source commit: `TBD`
- Production migration head: `20260917192500` observed September 30, 2026; recheck at submission
- Submitted by/date: `TBD`

## Beta App Description

PickUp UCF helps members of the UCF community find, organize, and join pickup sports games. Testers can discover nearby sessions, create and manage games, join or leave, coordinate in session chat, receive game updates, and manage safety controls including reporting and blocking.

This beta is focused on reliability, notification delivery, accessibility, and the complete create-to-play experience. Use synthetic content and do not include sensitive personal information in sessions, chat, reports, screenshots, or feedback.

## Feedback Email

`support.roomateapp@gmail.com`

Nurlan Mammadli confirmed on September 30, 2026 that this mailbox is monitored. External delivery remains a separate release check.

## What to Test

Please focus on these flows:

1. Sign in or create an account with an eligible UCF email and complete onboarding.
2. Browse Discover in list and map views, including filters and location-permission denial.
3. Create a synthetic game, then edit and cancel it.
4. Join and leave a game and confirm the participant count remains correct.
5. Exchange synthetic chat messages and check ordering after reopening the chat.
6. Verify game and chat notifications in the background and after force quit; tap them to check routing.
7. Report a synthetic message, user, or session; block and unblock a test account.
8. Add a game to Calendar, including permission denial and recovery.
9. Check Dynamic Type, VoiceOver labels, and light/dark appearance.
10. Edit a synthetic profile field, sign out, switch accounts, and delete a disposable account.

When reporting a problem, include the build number, device model, iOS version, time, steps, expected result, and actual result. Attach a screenshot only after confirming it contains no email address, message content, precise location, notification token, or other private data.

## Known Issues

Replace this section after the final internal run. Do not list a release-blocking issue as an accepted known issue.

- `TBD — confirm whether any non-blocking limitation remains in the candidate build.`

## Beta App Review Contact

- First name: `Nurlan`
- Last name: `Mammadli`
- Phone: `ENTERED PRIVATELY IN APP STORE CONNECT — DO NOT COMMIT`
- Email: `support.roomateapp@gmail.com`

The contact must be able to answer review questions while the build is in review.

## Demo account

- Username/email: `ENTER DIRECTLY IN APP STORE CONNECT — DO NOT COMMIT`
- Password: `ENTER DIRECTLY IN APP STORE CONNECT — DO NOT COMMIT`
- Account verified: `PASS — 2026-10-04; production auth reports email confirmed and password present`
- Last login check: `PASS — 2026-10-04; release owner reported successful TestFlight sign-in and seeded navigation`

Use a dedicated preverified UCF account containing synthetic data only. Keep it active and unchanged during review. In **App Store Connect → Apps → PickUp UCF → TestFlight → Test Information → Beta App Review Information → Sign-In Information**, select that sign-in is required and enter the account's email in **User Name** and password in **Password**. Enter these values manually in App Store Connect; do not paste them into this repository or release evidence.

Apple's [TestFlight test-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/) confirms the **TestFlight → Test Information** entry point. The candidate build's **What to Test** is entered when adding the build to an external testing group. Save the review information and metadata without selecting **Submit Review** until the external go/no-go gate is complete.

## Reviewer notes

PickUp UCF requires an `@ucf.edu` or `@knights.ucf.edu` address for normal registration. From a fresh TestFlight install, tap **Sign In** on Welcome, enter the dedicated demo email and password from the Sign-In Information fields, and tap **Sign In**. The demo account has already completed email verification and onboarding; no inbox access or one-time code is needed. If a session is already open, use **Profile → Settings → Sign out**, then sign in with the demo account.

After sign-in, the primary tabs are Discover, My Games, Create, and Profile:

- **Discover:** Browse the seeded basketball game at Memory Mall, the football report/block target at IM Fields, and other sample games in list or map form. Location permission is optional; denial does not prevent manual browsing.
- **My Games:** The prejoined soccer game at IM Fields and near-term tennis game at RWC Courts appear under Upcoming. Expand **Past games** to inspect the completed volleyball game at Memory Mall.
- **Create:** Tap **Create** in the tab bar to open the create-session sheet. Choose a future time and use non-sensitive test content.
- **Join/leave:** Open the basketball game at Memory Mall from Discover and use the session action. The demo account is not its host.
- **Chat:** Open the prejoined game from My Games and open its chat to read synthetic history. Use synthetic text only for new messages.
- **Reporting and blocking:** Open the separate football game at IM Fields and use **Session options → Report session** or **Block host**. A seeded soccer chat message can also be reported. Blocking hides contact and content between the accounts; the blocked list is under Profile → Settings → Blocked users. Blocking the football host leaves the other sample games available.
- **Notifications:** Notification permission is requested in context. Notification settings are under Profile → Settings. Background delivery depends on APNs and may take up to 90 seconds during the beta test.
- **Live Activity and widget extension:** Join an eligible near-term seeded game, then view its Live Activity on the Lock Screen or Dynamic Island on a supported iPhone. The widget extension provides this Live Activity; there is no separate Home Screen widget. It ends when the game ends, is cancelled, or the user leaves.
- **Deep links:** Tap a session or chat notification to open the authorized destination. Notification delivery requires permission and a second controlled account to trigger an event; the seeded content remains browsable without notifications.
- **Calendar:** Open a game detail and tap **Add to Calendar**. Calendar access is requested only after this action.
- **Privacy and support:** Profile → Settings contains Community rules, Privacy Policy, Terms of Use, blocked users, and Contact support. Public pages: Privacy Policy https://pickup-ucf-privacy.vercel.app/ ; Terms of Use https://pickup-ucf-privacy.vercel.app/terms.html ; Community Guidelines https://pickup-ucf-privacy.vercel.app/community-guidelines.html . Support: support.roomateapp@gmail.com .
- **Account deletion:** Profile → Settings → Delete account shows the irreversible-action confirmation and deletes the disposable account. Please avoid deleting the shared reviewer account; contact us if this flow must be tested so we can provide a separate disposable account.

The app has no purchases, subscriptions, advertising, or cross-app tracking. It uses Supabase for authentication and backend data, Brevo for account emails, Open-Meteo for game weather, and Apple Push Notification service for notifications and Live Activities. Location, Calendar, and notification permissions may be denied without blocking sign-in or basic game browsing. Use a physical iPhone for push and Live Activity checks.

## Seeded reviewer data

Create synthetic records shortly before submission and verify them from a fresh install.

| Record | Required state | Verification |
| --- | --- | --- |
| Reviewer profile | Complete onboarding; synthetic name | Production row and reviewer-scoped RLS verified; app Profile pending |
| Future open game | Basketball at Memory Mall; approved controlled host; space available | Reviewer-scoped RLS verified; app join pending |
| Joined game | Soccer at IM Fields; reviewer already joined | Reviewer-scoped RLS verified; app My Games pending |
| Chat history | Four neutral synthetic messages from two controlled accounts | Reviewer-scoped RLS verified; app order pending |
| Completed game | Volleyball at Memory Mall, joined by reviewer | Reviewer-scoped RLS verified; app Past games pending |
| Report target | Synthetic soccer chat message and football session | Visible under reviewer RLS; report action pending |
| Block target | Separate controlled football host | Visible under reviewer RLS; block/unblock pending |
| Near-term game | Tennis at RWC Courts, starts within 24 hours of 2026-10-04 seed | Visible under reviewer RLS; refresh date before review, activity check pending |

Do not seed real student data, private locations, authentic conversations, production secrets, or content that itself violates the Community Guidelines.

**Verification record (2026-10-04):** The public Privacy Policy, Terms of Use, and Community Guidelines opened successfully in a browser and cross-link to each other. Repository inspection confirmed the Sign In form, four tab labels, My Games past section, Settings links, and Live Activity-only widget extension. The dedicated reviewer auth account is email-confirmed and has a password; its synthetic profile has onboarding complete. Production seeding created five clearly labeled games, three joined by the reviewer, and four neutral chat messages from two controlled accounts. A transaction-scoped query under the reviewer's authenticated RLS claims returned one own profile, five visible sample games, four visible sample messages, and `is_current_user_moderator() = false`; the transaction was rolled back after the read. The account has zero moderator grants. The release owner subsequently confirmed TestFlight sign-in and seeded navigation below. No credential or account identifier has been recorded here.

## Age-rating declarations

Answer App Store Connect based on the shipped behavior:

- User-generated content: **Yes**
- Messaging and chat: **Yes**
- Social media: **No** unless Apple’s current questionnaire classifies Discover/session interaction as a social feed
- Unrestricted web access: **No**
- Advertising: **No**
- Age assurance: **No**, unless a new age-verification feature is added
- Objectionable-content frequency fields: answer from the expected moderated content, including the possibility of user violations before removal

Do not select the Kids category. Record App Store Connect’s calculated rating and the completion date in the release evidence.

## External group

- Group name: `PickUp UCF External Beta — Cohort 1`
- Initial size: 5–15 known testers
- Public link: Disabled for the first cohort
- Automatic distribution: Off until the release owner records the go decision
- Stop conditions: crash loop, authentication outage, cross-account disclosure, moderation bypass, account-deletion failure, or sustained notification queue failure

## Submission checklist

- [ ] All `TBD` fields resolved.
- [x] Demo credentials entered only in App Store Connect; values excluded from Git.
- [x] Reviewer sign-in and seeded navigation checked in TestFlight by the release owner on 2026-10-04; fresh-install status and individual action results were not recorded.
- [x] Seeded records verified as controlled synthetic content at public campus venues; ordinary production content may still appear under normal Discover policy.
- [x] Beta description, feedback email, reviewer contact, privacy URL, and reviewer notes saved in App Store Connect on 2026-10-04.
- [ ] Final candidate-specific “What to Test” and known issues saved.
- [ ] Export-compliance status completed for the candidate build.
- [ ] Age-rating questionnaire completed accurately.
- [ ] Exact build passed the two-account/two-device release gate.
- [ ] External group created with no testers invited before approval.
- [ ] First external build submitted to TestFlight Beta App Review.

**App Store Connect save verification (2026-10-04):** After an initial validation failure caused by incomplete contact information, the release owner entered the private phone number and reviewer password directly in App Store Connect. A reload of **TestFlight → Test Information** showed the beta description, feedback email, privacy URL, contact fields, sign-in requirement, username, password field, and review notes persisted, with no validation banner and Save disabled because there were no pending edits. No review submission was made. The phone number and password are intentionally absent from this file.

**Reviewer app check (2026-10-04):** The release owner reported signing in with the dedicated reviewer account in TestFlight and checking the seeded experience successfully. The report did not include the build, device/OS, fresh-install status, or a separate result for each join, chat, report, block, Live Activity, and account-deletion action. Production reviewer-scoped RLS previously confirmed the seeded rows were accessible and the reviewer was not a moderator. Refresh the near-term game before submission if its start time has passed.
