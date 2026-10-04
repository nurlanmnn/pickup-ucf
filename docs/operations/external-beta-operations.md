# External Beta Operations

Use this runbook before submitting a PickUp UCF build to TestFlight Beta App Review. Record evidence without copying email addresses, authentication data, device tokens, message bodies, precise locations, or secrets.

## Named ownership

Complete every field before external testing.

| Responsibility | Named owner | Backup | Verified date |
| --- | --- | --- | --- |
| Support mailbox monitoring | Nurlan Mammadli | `TBD` | September 30, 2026 |
| Routine moderation queue | Nurlan Mammadli | `TBD` | September 30, 2026 |
| Urgent safety escalation | `TBD` | `TBD` | `TBD` |
| Supabase operations | `TBD` | `TBD` | `TBD` |
| APNs and notification delivery | `TBD` | `TBD` | `TBD` |
| TestFlight release decision | `TBD` | `TBD` | `TBD` |

Nurlan Mammadli confirmed on September 30, 2026 that `support.roomateapp@gmail.com` is actively monitored. External-delivery verification remains part of the release check. The moderation owner follows [moderation-response.md](moderation-response.md).

## Production moderator provisioning

Provision moderators only through a privileged administrative session. Never store moderator status in client-controlled profile data.

1. Identify the production user UUID for the named moderation owner without recording their email in this runbook.
2. Insert or enable that UUID in `public.moderator_accounts` through the approved privileged path.
3. Sign in to the candidate build with that account and confirm **Settings → Review reports** appears.
4. Sign in with an ordinary account and confirm the moderation entry is absent.
5. Submit a synthetic report, resolve it from the moderator account, and confirm the audit entry is created.
6. Revoke the test grant if the account is not the continuing production moderator.

Record the moderator UUID only in the access-controlled operations record, not in Git.

On September 30, 2026, the production grant resolved exactly one intended profile,
created exactly one moderator row, and made `is_current_user_moderator()` return
`true` for that profile. A separate unrelated authenticated profile returned
`false`. Candidate-build visibility and the synthetic report/action flow remain
to be verified on-device.

## Beta App Review account and synthetic content

Use a dedicated controlled `@ucf.edu` or `@knights.ucf.edu` inbox. Do not reuse the production moderator or a personal profile as the reviewer identity. Keep the reviewer password in an approved private credential store and enter it directly in App Store Connect's TestFlight **Test Information → Beta App Review Information → Sign-In Information** fields. No password, verification link, account UUID, token, or private email address belongs in Git or release evidence.

1. Create the reviewer as an ordinary auth user, confirm its email through the controlled inbox or approved admin flow, and complete onboarding with clearly synthetic profile fields.
2. Create separate controlled synthetic host and block-target accounts. Use only public campus venues, future dates, neutral notes, and synthetic chat. Avoid real student profiles and private coordinates.
3. Seed one open game the reviewer can join, one already joined game with neutral messages from two synthetic accounts, one past joined game, and one near-term Live Activity-eligible game. Keep capacity available and refresh dates if review is delayed.
4. Sign in as the reviewer through the shipped app from a clean session. Confirm Discover, My Games, past games, session detail, chat, Profile, Settings, and report/block targets are reachable. Confirm a future open game can be joined and that the reviewer is not its host.
5. Verify `is_current_user_moderator()` is false for the reviewer and **Profile → Settings → Review reports** is absent. Do not grant moderator status to the reviewer.
6. Record only the date, candidate build, migration head, count of synthetic records by category, pass/fail for sign-in and each flow, and the non-moderator result. Keep identifiers and message contents in the private operations record if needed.

**2026-10-04 status:** The release owner approved a dedicated plus-addressed UCF reviewer identity and use of two existing controlled counterpart accounts. The owner entered the reviewer password directly into Supabase's auto-confirmed admin form. Production auth shows one confirmed reviewer user with a password and no moderator grant. One synthetic reviewer profile, five labeled games at public campus venues, three reviewer memberships, and four neutral messages from two controlled accounts were added. A transaction-scoped `authenticated` RLS query using the reviewer's claims returned one own profile, five visible sample games, four visible messages, and `is_current_user_moderator() = false`. The transaction was rolled back after the read. Actual TestFlight sign-in, UI navigation, and refresh of the near-term game before review remain open. The public policy pages were verified over HTTPS; the review packet has complete draft navigation and setup notes.

**Reviewer app check (2026-10-04):** The release owner subsequently signed in with the reviewer account in TestFlight, checked the seeded experience, and reported success. This is owner attestation; build/device details, fresh-install status, and individual action outcomes were not supplied. The near-term game still needs a date refresh if it expires before Beta App Review.

The dashboard's **Send invitation** path was attempted but did not create an auth user. Source inspection found that the deployed email-hook source's action allowlist does not include `invite`; the precise dashboard failure was not surfaced. The direct auto-confirmed form succeeded. Recheck the invitation path separately before using it for another account; do not assume invitation email delivery works.

## RLS and role verification

Run against production with disposable synthetic accounts and content.

The linked migration inventory was rechecked read-only on September 30, 2026.
Local and production histories matched through `20260917192500`.

- Anonymous: cannot read private profiles, sessions requiring membership, chat, reports, moderator tables, tokens, or authenticated RPC results.
- Authenticated user: can access only their permitted profile/session/chat data and cannot read other users’ reports or moderator notes.
- Blocked pair: cannot discover, join, message, view protected profile content, or trigger actor-generated notifications across the block.
- Suspended user: cannot create user content or perform restricted session actions.
- Moderator: can use only the intended moderation RPCs and cannot bypass unrelated data policies.
- Deleted user: cannot authenticate or regain account-linked data; retained safety records follow the published policy.

Record the candidate build, migration parity timestamp, disposable account identifiers, assertion counts, and pass/fail. Do not record content or credentials.

## Email verification and password reset

1. Create a disposable eligible UCF account and confirm the verification email arrives.
2. Confirm an invalid or expired verification link fails with safe recovery guidance.
3. Request a password reset and confirm the reset email arrives once.
4. Confirm a used or expired reset link cannot be reused.
5. Confirm the app returns to an authorized screen after a successful reset.
6. Confirm Brevo/email-hook failures are visible to the operations owner without leaking message content or credentials.

Record timestamps, delivery latency, build number, and pass/fail.

## Push and scheduled work

1. Confirm the `pickup-dispatch-push` schedule is active at the intended once-per-minute cadence.
2. Confirm the function accepts only the dedicated dispatcher credential and rejects missing or incorrect authorization.
3. Create one eligible synthetic notification and confirm its outbox row is processed once.
4. Confirm an APNs `BadDeviceToken` response removes only the rejected token and leaves the failed attempt observable.
5. Confirm APNs provider-token reuse remains within Apple’s refresh guidance.
6. Tap a notification for valid, deleted, cancelled, blocked, and access-revoked content; confirm authorized routing or safe failure without disclosure.

Operational monitoring should expose queue depth, oldest pending age, invocation failures, and privacy-safe APNs reason codes. Alert thresholds and their recipient must be recorded in the private operations system.

## Account deletion and retention

Use a disposable account containing a profile, session membership, chat message, report, device token, and notification preferences.

1. Delete the account through the candidate build.
2. Confirm local auth, caches, widget state, badge state, notification registration, and Live Activities are cleared.
3. Confirm subsequent sign-in fails and the same device can safely register a different account.
4. Inspect production data through the approved administrative path and classify each prior record as deleted, anonymized, retained for integrity/safety, or awaiting backup expiry.
5. Compare the result with the Privacy Policy and Terms. Resolve any mismatch before external review.

The private evidence record must state the retention reason and expected expiry for every retained category.

## Backup and restore expectations

Before external testing, record in the private operations system:

- Supabase backup mechanism, frequency, retention window, and responsible owner;
- the most recent successful backup or recovery-point timestamp;
- whether point-in-time recovery is available;
- the tested restore destination and the date of the latest restore exercise;
- which secrets, Edge Function deployments, cron configuration, and Vault values require separate recovery; and
- the maximum acceptable data loss and recovery time for the beta.

Never test a restore over the production project. Restore to an isolated project, verify schema and representative synthetic records, then destroy or restrict the temporary environment according to the operations policy.

## Deployment, rotation, rollback, and incident response

For every external candidate, record:

- build number and source commit;
- production migration head and Edge Function revision;
- configuration and secret owners, never secret values;
- deployer and deployment timestamp;
- rollback or forward-fix procedure for each changed migration/function;
- stop-ship criteria and the person authorized to expire a TestFlight build; and
- incident channel, severity, owner, and user-communication path.

Stop external expansion for any crash loop, authentication outage, cross-account disclosure, moderation bypass, destructive-operation duplication, or sustained notification queue failure.

## Completion record

| Gate | Evidence location | Result | Verified by/date |
| --- | --- | --- | --- |
| Support mailbox ownership | This runbook | `CONFIRMED` | Nurlan Mammadli, September 30, 2026 |
| Remaining named ownership | Private operations record | `OPEN` | `TBD` |
| Moderator provisioning | Production `moderator_accounts` grant; identifiers excluded from Git | `CONFIRMED` | September 30, 2026 |
| Reviewer account and synthetic content | This runbook and review packet; no identifiers in Git | `RLS VERIFIED; APP SIGN-IN OPEN` | October 4, 2026 |
| RLS/role matrix | Redacted release evidence | `OPEN` | `TBD` |
| Email flows | Redacted release evidence | `OPEN` | `TBD` |
| Push/scheduler | Redacted release evidence | `OPEN` | `TBD` |
| Deletion/retention | Redacted release evidence | `OPEN` | `TBD` |
| Backup/restore | Private operations record | `OPEN` | `TBD` |
| Rollback/incident readiness | Private operations record | `OPEN` | `TBD` |
