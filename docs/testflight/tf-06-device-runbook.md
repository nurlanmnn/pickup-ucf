# TF-06 Physical-Device Runbook — Build 1.0 (2)

Build 1.0 (2) is the processed internal build from source `316b29bd59f5efafcf43151f634ad55b46921b8f`. Run every row once on a physical iPhone running iOS 17 and once on a physical iPhone running the current iOS release. Record device model, iOS version, tester initials, date/time, and pass/fail. Use only controlled UCF accounts and synthetic content.

Do not capture email addresses, tokens, message bodies, precise locations, or secrets in evidence. For a failure, record the step, expected result, visible symptom, timestamp, device/OS, and a redacted screenshot or Console excerpt.

## Install

1. On each device, sign in to the invited Apple Account, accept the TestFlight invitation, install TestFlight, open **PickUp UCF 1.0 (2)** from **Internal Testers**, and confirm the build number.

## Core flow

2. Fresh-launch the app; confirm auth UI loads without a crash, placeholder configuration, or setup copy.
3. Create controlled account A, verify its UCF email, finish onboarding, force quit, relaunch, background, and foreground; confirm the same account returns to a coherent screen.
4. Sign in as controlled account B on the second device.
5. With A, create a uniquely named test session; confirm correct host, sport, time, place, capacity, and player count on both devices.
6. With B, join and leave the session twice, including once during refresh; confirm membership/count changes exactly once.
7. Exchange synthetic chat messages; confirm one in-order copy on each device and persistence after reopening chat.
8. With A, edit then cancel the session; confirm B sees both changes and cannot act on stale content.
9. With B, report the controlled session/account and block then unblock A; confirm clear acknowledgements and suppressed blocked content/contact.
10. Edit a synthetic profile field and relaunch; confirm it persists.
11. On one device, sign out A, sign in B, then switch back; confirm no profile, notification, badge, token, chat, or cached-content leak.
12. After every other test, delete one disposable account; confirm explicit warning, cleared session, failed subsequent sign-in, and policy-consistent retained/anonymized content.

## Notifications and Live Activities

13. Allow notifications. Trigger join, chat, edit, and cancellation events in foreground, background, and terminated states; confirm exactly one safe notification per eligible event.
14. Tap each notification, including after cancellation/access revocation; confirm an authorized destination opens or the app fails safely without disclosure.
15. Accumulate then clear notifications, switch accounts, and sign out; confirm badges never carry across accounts.
16. Sign in as A, sign out, sign in as B, then trigger an A-only event; confirm the device receives no A notification.
17. Join an eligible near-term session and inspect its Live Activity. Then edit, leave/cancel/end, force quit, and restart; confirm the activity updates/ends and exposes no other account's data. Record the known limitation caused by the deferred Live Activity end-push migration.

## Permissions and recovery

18. Deny location, retry, enable it in Settings, and return; confirm safe denial and recovery.
19. Deny calendar access, retry export, grant access, and export again; confirm one correct event.
20. Deny notifications, use the app's Settings guidance, enable them in Settings, and confirm later eligible delivery.
21. Enable airplane mode during launch and during create/join/leave/chat/profile actions; restore network and retry once; confirm actionable errors, recovery, and no duplicate records/messages/counts.
22. Background and force quit during refresh and notification/deep-link handling; reopen and confirm authorized coherent state.
23. Exercise a controlled expired/revoked session, including from a notification tap; confirm return to auth without destination disclosure.

## Stop conditions

Stop and record a failure for any crash; cross-account data/token/notification/badge/chat/Live Activity leak; auth or deletion failure; authorization/RLS bypass; duplicate destructive operation; inconsistent membership count; PII/secret in UI/logs; or repeatable P1 regression.

TF-06 remains open until all rows have evidence for both OS lanes. Production migration parity does not substitute for physical-device evidence.

## Device result — 2026-09-16 sign-out cleanup failure

- Build: **PickUp UCF 1.0 (2)**, source `316b29bd59f5efafcf43151f634ad55b46921b8f`
- Date/time: **2026-09-16, approximately 10:09 AM America/New_York**
- Device model: **not recorded**
- iOS version: **not recorded**
- Tester initials: **not recorded**
- Evidence: redacted screenshot supplied locally as `Screenshot 2026-09-16 at 10.09.55 AM.png`; it shows the signed-out Welcome screen and the warning “You’re signed out. Some server cleanup could not be confirmed.” No email, APNs token, session token, or message content is visible.
- Step 11 result: **FAILED** for the sign-out/account-transition portion. Local authenticated UI state cleared, but server cleanup was not confirmed, so the account-switch isolation requirement did not pass.
- Step 16 result: **BLOCKED**. Do not mark account-specific notification isolation passed until a physical-device retest proves A’s token cleanup and B’s subsequent ownership claim; migration deployment alone is not runtime proof.
- TF-06 status: **OPEN / NOT COMPLETE**.

### Confirmed diagnosis

The confirmed broken cleanup dependency is APNs token unregistration. Build 1.0 (2) calls the authenticated `unregister_device_token` RPC before Supabase sign-out whenever the device has a stored APNs token. A read-only linked migration listing on 2026-09-16 showed `20260910120000_secure_device_token_ownership.sql` absent from production. A fresh schema-only production export independently confirmed that neither `register_device_token` nor `unregister_device_token` exists; production still has the prior `(user_id, apns_token)` primary key and owner-scoped `device_tokens_all` policy. Any unregister attempt from this build therefore fails at the missing RPC.

Live Activity cleanup did not cause this warning: the shipped local cleanup closure is non-throwing and cannot set the warning outcome. Supabase Swift removes the persisted local auth session before attempting remote logout, which matches the observed Welcome screen. Build 1.0 (2) aggregated token-cleanup and remote-logout failures into the same warning, and the device’s notification-permission/token state was not recorded. The screenshot therefore cannot forensically prove which branch set the warning or whether remote logout also failed. The missing APNs RPC is the only cleanup defect independently confirmed; no evidence establishes a remote sign-out failure.

Immediately before this remediation, `main` at `0fba725` had no changes from the build source in `AccountTransitionCoordinator.swift`, `PushNotificationService.swift`, `DeviceTokenRepository.swift`, or the device-token ownership migration. Later `main` changes affected moderation, UI, documentation, and Live Activity lifecycle behavior, but not the shipped token-unregistration path.

### Required physical-device retest

Prerequisites: install a build containing the remediation. Production migration `20260910120000_secure_device_token_ownership.sql` was deployed and its token RPCs were verified on 2026-09-16; confirm migration parity again before testing if the backend changes. Use controlled accounts A and B on the same physical iPhone. Record the device model, exact iOS version, tester initials, build number/source SHA, production migration version, and timestamp.

1. Sign in as A, allow notifications, background and foreground the app once, and confirm the app remains authenticated.
2. Sign out A while online. Confirm the Welcome screen appears **without** the server-cleanup warning.
3. Sign in as B on the same device, then force quit and relaunch. Confirm only B’s profile, badges, chat, cached content, and notification state are present.
4. From a second controlled device/account, trigger an A-only eligible notification. Confirm the switched device receives no A notification.
5. Trigger a B-only eligible notification. Confirm exactly one safe B notification arrives and routes only to authorized B content.
6. Repeat steps 1–5 once with network loss during A sign-out. Confirm the cleanup warning remains visible, local auth clears, B does not enable push while ownership is unconfirmed, and notification registration recovers only after connectivity returns and atomic server ownership succeeds.
7. Repeat the full sequence in both required lanes: one physical iPhone on iOS 17 and one on the current iOS release. Step 11 and step 16 remain open until both lanes pass with recorded evidence.

Migration `20260910120000_secure_device_token_ownership.sql` is the authoritative production fix for atomic one-token/one-account ownership and was deployed on 2026-09-16. This removes the known backend prerequisite but does not change the recorded failure or close steps 11 and 16 without a passing device retest.

### Production migration result — 2026-09-16

- Authorization: the user explicitly authorized deploying all four pending migrations without first creating a backup.
- Deployment time: approximately **10:07 PM America/New_York**.
- Applied in order: `20260822000000_fix_leave_session_player_count.sql`, `20260909000000_live_activity_end_pushes.sql`, `20260910120000_secure_device_token_ownership.sql`, and `20260916090000_ugc_safety_and_moderation.sql`.
- Post-deployment migration listing: **verified local/remote parity** for all four versions.
- Post-deployment schema export: **verified** `device_tokens` has primary key `(apns_token)`; `register_device_token(text)` and `unregister_device_token(text)` exist as `SECURITY DEFINER` functions with fixed `search_path`; public execution is revoked and authenticated execution is granted; unregistration deletes only the current authenticated user's exact token.
- Backup: **not created**, by explicit user authorization. Rollback therefore depends on forward repair or any provider-managed recovery that may independently exist.
- TF-06 status: **OPEN / NOT COMPLETE**. Step 11 remains failed and step 16 remains blocked pending the exact physical-device retest below.

### Code verification — 2026-09-16

The remediation adds a missing-RPC compatibility delete constrained by both authenticated user ID and exact APNs token, with the existing owner-scoped RLS as a second boundary. It does not add a registration/upsert fallback. Confirmed cleanup clears the stored token; unconfirmed cleanup is retried once, keeps the warning, locally disables APNs, and quarantines registration until an authenticated atomic token claim succeeds. Failure categories contain no backend text or private identifiers.

- Focused device-token tests: **15/15 passed**.
- Focused account-transition tests: **5/5 passed**.
- Complete iOS suite: **171/171 passed**.
- Unsigned generic-device Release build: **passed**.
- Release static analyzer: **passed**.
- Static logging/privacy scan and `git diff --check`: **passed**.
- Physical-device retest: **pending**; step 11 remains failed and step 16 remains blocked.

## Device result — 2026-09-16 chat notification delivery failure

- Date/time: **2026-09-16, approximately 11:10 PM America/New_York**
- Sending client: **Xcode simulator**, signed in as controlled account A
- Receiving device: **personal physical iPhone**, signed in as controlled account B
- Receiving device model: **not recorded**
- Receiving iOS version: **not recorded**
- Receiving app build/source SHA: **not recorded for this observation**
- Tester initials: **not recorded**
- Observed result: account A sent chat messages while account B was eligible for chat notifications, but the physical phone received no notification.
- Step 13 result: **FAILED** for background/terminated chat notification delivery. Foreground banner behavior was not evaluated by this observation.
- Step 16 result: **BLOCKED** pending a fresh two-account physical-device isolation test after delivery is proven.
- TF-06 status: **OPEN / NOT COMPLETE**.

### Confirmed diagnosis and production remediation — 2026-09-17 through 2026-09-18

Privacy-safe production checks confirmed four chat messages had four matching `notification_outbox` rows, each with an eligible recipient, chat notifications enabled, a registered device token, no block relationship, and no sender suspension. All four outbox rows remained unprocessed. Production had no cron job invoking the `send-push` Edge Function, so message creation and notification eligibility worked but dispatch never ran. This was the first confirmed cause of the observed delivery failure; it was not an iOS message-creation failure or a device-token ownership failure.

After scheduling was restored, the outbox still did not drain. A direct authenticated invocation returned HTTP 200 with zero successful sends, proving scheduler/function authentication and execution while preserving failed rows for retry. A privacy-safe diagnostic revision then recorded only APNs status and a documented reason. Production APNs returned HTTP 429 `TooManyProviderTokenUpdates` for every attempted device delivery. The function created a new provider JWT for each outbox recipient, including 16 tokens within seconds during the recovered backlog. Apple requires provider-token refreshes no more than once every 20 minutes, so APNs rejected the batch. This was the second confirmed server-side cause.

The code-owned correction caches one provider JWT for 50 minutes, resolves it only once per notification/Live Activity batch, reuses it across warm scheduled invocations, and clears the cache if token generation fails. It neither suppresses APNs failures nor marks rejected rows sent. Once APNs accepted the stable provider token, 10 of the 16 pending chat rows advanced. The remaining six were repeatedly rejected as HTTP 400 `BadDeviceToken`, proving those exact registered tokens were unusable in the now-working production APNs configuration. The narrow recovery deletes only a token explicitly rejected with that status/reason, leaves the current outbox attempt failed, and allows a subsequent app registration to claim a fresh token; other APNs failures remain logged and pending.

The function tests pass **19/19**, including explicit single-JWT batch reuse, cache refresh, safe diagnostics, exact `BadDeviceToken` recovery, 410 stale-token cleanup, account-token isolation, notification payload routing, and Live Activity cleanup. The corrected function was deployed on 2026-09-18. At approximately 8:55 AM America/New_York, a privacy-safe count confirmed zero pending chat outbox rows. The six invalid-token rows were retired only after their unusable tokens had been removed and a later retry confirmed there was no registered destination; they were not falsely counted as successful APNs deliveries. A fresh physical-device registration and delivery remains required before step 13 can pass.

Production runs the function with gateway JWT verification disabled because the function performs its own dedicated `CRON_SECRET` bearer check. A random dispatcher credential is stored in Supabase Vault and synchronized to the Edge Function secret. The `pickup-dispatch-push` cron job invokes `send-push` once per minute. Temporary `service_role`-only bootstrap/rotation RPCs were removed after setup. `APNS_ENV` is explicitly `production` for TestFlight delivery. No APNs token, email address, session token, message body, private key, or dispatcher secret was written to the runbook, logs added by this remediation, or committed files.

Five migration records capture the production operation: `20260917190000_bootstrap_push_dispatch.sql`, `20260917190500_fix_push_dispatch_secret_generation.sql`, `20260917191000_remove_push_dispatch_bootstrap.sql`, `20260917192000_rotate_push_dispatch_secret.sql`, and `20260917192500_remove_push_dispatch_secret_rotation.sql`. The correction migration safely schema-qualifies key generation. The later pair records the one-time credential resynchronization and immediately removes that helper. Applying these migrations alone does not schedule or rotate another environment because each production-only helper required an explicit `service_role` invocation and no helper remains callable after the full sequence.

### Exact notification retest

No new iOS build is required for this server-side scheduler and provider-token repair. Use the currently installed remediated build, but record its exact build number and source SHA before testing. The recovered outbox is clear; the receiving app must now launch while signed in and online so it can register a fresh device token before generating the test message.

1. Record the receiving iPhone model, exact iOS version, installed build number/source SHA, tester initials, and timestamp.
2. Launch the app while online, sign in as controlled account B on the physical iPhone, and leave it open through one background/foreground cycle so APNs registration can complete. Confirm iOS notification permission and in-app chat notifications are enabled.
3. Open the relevant session chat once, then leave that chat and put the app in the background. Do not keep the chat visible in the foreground for the delivery check.
4. On the Xcode simulator, sign in as controlled account A and send one new synthetic message in the same session.
5. Wait up to **90 seconds**. Confirm exactly one notification arrives on B's phone and exposes no message body or private account data on the lock screen beyond the app's intended safe copy.
6. Tap the notification. Confirm it opens the authorized session chat for B and shows the new message exactly once.
7. Force quit the app on B's phone. From A, send a second synthetic message. Wait up to **90 seconds** and confirm exactly one notification arrives and routes safely after launch.
8. Sign out B on the phone and sign in as controlled account C. From A, send a B-only eligible message. Confirm the phone receives no B notification while C is signed in.
9. Trigger one C-only eligible notification and confirm exactly one notification reaches C. Then complete the existing step 11 and step 16 account-switch sequence in both required physical-device OS lanes.

Step 13, step 11, and step 16 remain open until the applicable physical-device checks pass with recorded evidence.
