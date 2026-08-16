# Core Loop Reliability — Design Spec

**Date:** 2026-07-18  
**Goal:** Make the join → show up → play loop trustworthy before UI polish.  
**Scope:** Push notifications, attendance, session lifecycle, profile reliability stats.

## Problem

Pickup sports apps fail when people ghost. PickUp UCF already supports discover, join, waitlist, chat, and cancel — but users get no proactive reminders, hosts can't confirm who showed, and profile trust signals (`games_played`, `show_up_streak`) exist in the schema but aren't used.

## Success Criteria

1. A joined player receives a push **1 hour** and **15 minutes** before `starts_at`.
2. When a spot opens, the **first waitlisted** player gets a push within seconds.
3. When a host **cancels**, all joined/waitlisted players get a push.
4. After a session ends, the host can **mark attendance** for joined players within 24 hours.
5. Attendance updates `profiles.games_played` and `profiles.show_up_streak`.
6. Sessions auto-transition to `completed` after `ends_at`.
7. Profile shows `games_played` and `show_up_streak`.

## Non-Goals (this phase)

- Notification preference toggles per type
- Self check-in via GPS
- Player-to-player ratings
- Android
- Sport list expansion
- UI visual redesign

## Architecture

### Notifications

```
iOS (APNs token) → device_tokens table
DB events / pg_cron → notification_outbox table → send-push Edge Function → APNs
Notification tap → pickupucf://session/{id} (existing DeepLinkRouter)
```

**Event types (v1):**

| Type | Trigger |
|------|---------|
| `session_reminder_1h` | Scheduled job, `starts_at - 1 hour` |
| `session_reminder_15m` | Scheduled job, `starts_at - 15 minutes` |
| `waitlist_promoted` | `leave_session` promotes a waitlisted user |
| `session_cancelled` | Host sets `status = cancelled` |

Recipients: joined + waitlisted participants (reminders); promoted user only (waitlist); all joined + waitlisted (cancel).

### Attendance

Host-only RPC `submit_session_attendance(p_session_id, p_attended_user_ids uuid[])`:

- Allowed when `starts_at <= now()` and within 24h of `ends_at`
- Host must be session host
- Inserts into `attendance` for attended users
- Sets session `status = completed`
- Increments `games_played` for attended users
- Resets `show_up_streak` to 0 for joined non-attendees; increments streak for attended users who had streak > 0 or sets to 1

Joined non-attendees who were marked absent do not increment `games_played`.

### Session Lifecycle

- pg_cron every 15 minutes: `complete_expired_sessions()` sets `status = completed` where `ends_at < now()` and status in (`open`, `full`)
- Host attendance submission also sets `completed`
- Cancelled sessions skip attendance

## Data Model Additions

### `notification_outbox`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK profiles | recipient |
| session_id | uuid FK sessions nullable | |
| type | text | enum-like |
| title | text | |
| body | text | |
| payload | jsonb | `{ "session_id": "..." }` for deep link |
| dedupe_key | text UNIQUE | prevents duplicate sends |
| sent_at | timestamptz nullable | null = pending |
| created_at | timestamptz | |

Edge Function processes rows where `sent_at IS NULL`, sends via APNs, sets `sent_at`.

### RLS

- `attendance`: SELECT for session participants; INSERT/UPDATE via RPC only (no direct client writes)
- `notification_outbox`: no client access (service role only)

## iOS Changes

- `AppDelegate` + Push Notifications capability
- `PushNotificationService` — permission, register token, upsert to Supabase
- `DeviceTokenRepository`
- Notification tap routes through `AppState.queueSessionDeepLink`
- `AttendanceView` on session detail for host post-game
- Profile shows reliability stats

## External Dependencies

- Apple Developer: Push Notifications capability, APNs Auth Key (.p8)
- Supabase secrets: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID` (= `edu.ucf.pickup`)
- Supabase: enable `pg_cron` extension for reminders + session completion

## Error Handling

- Missing APNs token: skip send, log in Edge Function
- Invalid/expired token: delete from `device_tokens` on APNs 410
- Duplicate notification: `dedupe_key` unique constraint silently skips
- Host submits attendance twice: RPC idempotent (replace attendance set)

## Testing

- SQL: unit-test RPCs via Supabase local + psql scripts
- iOS: manual on device (push requires real device)
- Edge Function: curl with service role + sample outbox row
