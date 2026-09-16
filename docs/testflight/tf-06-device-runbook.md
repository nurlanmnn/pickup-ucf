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
