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

TF-06 remains open until all rows have evidence for both OS lanes. The intentionally deferred production migrations remain limitations rather than passes.

## Device result — 2026-09-16 sign-out cleanup failure

- Build: **PickUp UCF 1.0 (2)**, source `316b29bd59f5efafcf43151f634ad55b46921b8f`
- Date/time: **2026-09-16, approximately 10:09 AM America/New_York**
- Device model: **not recorded**
- iOS version: **not recorded**
- Tester initials: **not recorded**
- Evidence: redacted screenshot supplied locally as `Screenshot 2026-09-16 at 10.09.55 AM.png`; it shows the signed-out Welcome screen and the warning “You’re signed out. Some server cleanup could not be confirmed.” No email, APNs token, session token, or message content is visible.
- Step 11 result: **FAILED** for the sign-out/account-transition portion. Local authenticated UI state cleared, but server cleanup was not confirmed, so the account-switch isolation requirement did not pass.
- Step 16 result: **BLOCKED**. Do not trigger or evaluate an A-only notification on account B until A’s device-token cleanup is proven; absence of a notification would not be trustworthy while production ownership cleanup is unresolved.
- TF-06 status: **OPEN / NOT COMPLETE**.

### Confirmed diagnosis

The confirmed broken cleanup dependency is APNs token unregistration. Build 1.0 (2) calls the authenticated `unregister_device_token` RPC before Supabase sign-out whenever the device has a stored APNs token. A read-only linked migration listing on 2026-09-16 showed `20260910120000_secure_device_token_ownership.sql` absent from production. A fresh schema-only production export independently confirmed that neither `register_device_token` nor `unregister_device_token` exists; production still has the prior `(user_id, apns_token)` primary key and owner-scoped `device_tokens_all` policy. Any unregister attempt from this build therefore fails at the missing RPC.

Live Activity cleanup did not cause this warning: the shipped local cleanup closure is non-throwing and cannot set the warning outcome. Supabase Swift removes the persisted local auth session before attempting remote logout, which matches the observed Welcome screen. Build 1.0 (2) aggregated token-cleanup and remote-logout failures into the same warning, and the device’s notification-permission/token state was not recorded. The screenshot therefore cannot forensically prove which branch set the warning or whether remote logout also failed. The missing APNs RPC is the only cleanup defect independently confirmed; no evidence establishes a remote sign-out failure.

Immediately before this remediation, `main` at `0fba725` had no changes from the build source in `AccountTransitionCoordinator.swift`, `PushNotificationService.swift`, `DeviceTokenRepository.swift`, or the device-token ownership migration. Later `main` changes affected moderation, UI, documentation, and Live Activity lifecycle behavior, but not the shipped token-unregistration path.

### Required physical-device retest

Prerequisites: install a build containing the remediation, then obtain separate production authorization to deploy migration `20260910120000_secure_device_token_ownership.sql` and verify both token RPCs exist. Without that migration, positive B notification delivery cannot pass even though the compatibility cleanup safely removes A's legacy row. Use controlled accounts A and B on the same physical iPhone. Record the device model, exact iOS version, tester initials, build number/source SHA, production migration version, and timestamp.

1. Sign in as A, allow notifications, background and foreground the app once, and confirm the app remains authenticated.
2. Sign out A while online. Confirm the Welcome screen appears **without** the server-cleanup warning.
3. Sign in as B on the same device, then force quit and relaunch. Confirm only B’s profile, badges, chat, cached content, and notification state are present.
4. From a second controlled device/account, trigger an A-only eligible notification. Confirm the switched device receives no A notification.
5. Trigger a B-only eligible notification. Confirm exactly one safe B notification arrives and routes only to authorized B content.
6. Repeat steps 1–5 once with network loss during A sign-out. Confirm the cleanup warning remains visible, local auth clears, B does not enable push while ownership is unconfirmed, and notification registration recovers only after connectivity returns and atomic server ownership succeeds.
7. Repeat the full sequence in both required lanes: one physical iPhone on iOS 17 and one on the current iOS release. Step 11 and step 16 remain open until both lanes pass with recorded evidence.

Deploying `20260910120000_secure_device_token_ownership.sql` remains the authoritative production fix for atomic one-token/one-account ownership. This investigation did not deploy or alter production schema or data.

### Code verification — 2026-09-16

The remediation adds a missing-RPC compatibility delete constrained by both authenticated user ID and exact APNs token, with the existing owner-scoped RLS as a second boundary. It does not add a registration/upsert fallback. Confirmed cleanup clears the stored token; unconfirmed cleanup is retried once, keeps the warning, locally disables APNs, and quarantines registration until an authenticated atomic token claim succeeds. Failure categories contain no backend text or private identifiers.

- Focused device-token tests: **15/15 passed**.
- Focused account-transition tests: **5/5 passed**.
- Complete iOS suite: **171/171 passed**.
- Unsigned generic-device Release build: **passed**.
- Release static analyzer: **passed**.
- Static logging/privacy scan and `git diff --check`: **passed**.
- Physical-device retest: **pending**; step 11 remains failed and step 16 remains blocked.
