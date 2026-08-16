# Post-MVP Tiers — Design Spec

**Date:** 2026-07-18  
**Prerequisite:** Phases A–C complete; profile global `skill_level` removed (skill is per-session only)  
**Goal:** Ship Tier 1–3 features incrementally with tests — clarity, trust, retention, and UCF campus feel.

## Problem

The core loop works, but users still join blind, onboarding data is underused, moderation is one-way, notifications are all-or-nothing, and Discover feels like a generic list—not a campus map of pickup games.

## Success Criteria (all tiers)

1. Discover defaults to a signed-in user's preferred sports (overridable).
2. Session detail shows joined roster and the viewer's waitlist position when applicable.
3. Users can view and unblock blocked hosts from Settings.
4. Users can toggle notification categories; disabled types are not enqueued.
5. Hosts receive join and reminder pushes.
6. Tapping a host opens a read-only mini profile (stats + preferred sports).
7. Completed sessions offer "Run it back" to pre-fill a new session.
8. New chat messages notify joined participants (respecting prefs).
9. Sessions can be added to Apple Calendar.
10. Discover has list/map toggle; map shows upcoming session pins.
11. Discover can filter by official venue.
12. Live Activity shows countdown for next joined game (optional capability).
13. Empty Discover states nudge users to host with sport pre-filled.

## Architecture Overview

```
Tier 1 (core polish)
  ├── iOS: Discover defaults, roster UI, blocked list, notification settings
  └── DB: notification_preferences, host join trigger, roster/waitlist RPCs

Tier 2 (trust & retention)
  ├── iOS: HostProfileView, RunItBack flow, Calendar export, chat push handling
  └── DB: messages trigger → outbox; public profile fetch (existing RLS OK)

Tier 3 (campus delight)
  ├── iOS: MapKit Discover, venue filter, Live Activity, empty-state CTA
  └── DB: optional venue_id filter on fetch (client or server)
```

## Tier 1 — Core Polish

### 1. Preferred sports → Discover default

- On first Discover load after sign-in, if profile has `preferred_sports`, filter feed to those sports (union).
- Add chip **"My sports"** (selected by default when prefs exist) vs individual sport chips.
- Persist user's last sport filter choice in `UserDefaults` (`discoverSportFilterMode`).
- No backend change required.

### 2. Participant roster + waitlist position

**New RPC:** `get_session_roster(p_session_id uuid)` returns:
- `joined`: array of `{ user_id, display_name, username, role }` ordered by `joined_at`
- `waitlist_count`: int
- `viewer_waitlist_position`: int nullable (only for `auth.uid()` when waitlisted)

**RLS:** Callable by any authenticated UCF user who can SELECT the session (same as session detail).

**Waitlist position:** `ROW_NUMBER() OVER (ORDER BY joined_at)` among `status = 'waitlist'`.

**iOS:** Section on `SessionDetailView` — "Players (N)" list; subtitle "#K on waitlist" for viewer.

### 3. Blocked users management

**Extend BlockRepository:**
- `fetchBlockedUsers() -> [BlockedUser]` (join `profiles` for display_name, username)
- `unblock(userId:)` → existing `unblock_user` RPC

**iOS:** `BlockedUsersView` under Settings; swipe or button to unblock.

### 4. Notification preferences

**New table:** `notification_preferences`

| Column | Type | Default |
|--------|------|---------|
| user_id | uuid PK FK profiles | |
| session_reminders | boolean | true |
| waitlist_promoted | boolean | true |
| session_cancelled | boolean | true |
| host_player_joined | boolean | true |
| host_session_reminder | boolean | true |
| chat_messages | boolean | true |
| updated_at | timestamptz | now() |

**RLS:** user reads/writes own row only.

**Helper:** `should_notify(p_user_id, p_type text) RETURNS boolean` — SECURITY DEFINER, returns true if no row (default all on) or column enabled.

**Update all enqueue sites** (reminder cron, cancel trigger, leave/waitlist trigger, new host join trigger, new chat trigger) to call `should_notify` before `enqueue_notification`.

**iOS:** `NotificationSettingsView` in Settings with toggles; upsert on change.

### 5. Host notifications

**New types:**
- `host_player_joined` — when a non-host joins (not waitlist)
- `host_session_reminder_1h` — cron, same window as player 1h reminder

**Trigger:** `AFTER INSERT OR UPDATE ON session_participants` when status becomes `joined` and user is not host → notify session host (dedupe per join event).

**Cron:** extend `enqueue_session_reminders` or add `enqueue_host_session_reminders` for hosts only.

## Tier 2 — Trust & Retention

### 6. Host mini profile

- `ProfileRepository.fetchProfile(userId:)` — select public fields by id (RLS already allows authenticated read).
- `HostProfileView` — display name, @username, games_played, show_up_streak, preferred sports.
- Entry: tap host row on session detail (NavigationLink).

### 7. Run it back

- Button on completed session detail (host or participant): "Run it back".
- Opens `CreateSessionView` with fields pre-filled from source session (sport, venue/location, skill, capacity, duration, notes); **new** start time default = same weekday/time next week or +7 days.
- No backend change; pure iOS prefill via `CreateSessionPrefill` struct.

### 8. Chat message push

**Trigger:** `AFTER INSERT ON messages` → for each joined/waitlisted participant except sender, enqueue `chat_message` type if `should_notify(..., 'chat_messages')`.

**Payload:** `{ session_id, message_id }` — deep link to session chat tab.

**iOS:** Extend `DeepLinkRouter` / session detail to open chat when payload includes `open_chat: true`.

### 9. Add to Apple Calendar

- `EventKit` — request calendar access once; "Add to Calendar" button on session detail.
- Create event: title = sport + location, start/end = session times, notes = deep link + host.
- No backend change. Add `NSCalendarsUsageDescription` to Info.plist via `project.yml`.

## Tier 3 — Campus Delight

### 10. Discover map view

- Segmented control: **List | Map**.
- Map: `Map` with annotations for sessions that have coordinates (venue lat/lng or custom_lat/lng).
- Tap pin → navigate to session detail (same as list).
- Sessions without coordinates omitted from map (still in list).

### 11. Venue filter

- Optional `venueId` param on `fetchUpcoming` (client filter OK initially; server `.eq("venue_id", ...)` when venue set).
- Horizontal venue chips below sport chips (official venues from `fetchVenues()`).
- "All venues" default.

### 12. Live Activity

- ActivityKit widget for next upcoming joined session (within 24h).
- Start when user joins; end after `starts_at + 15m`.
- Requires iOS 16.1+ ActivityKit; gate behind availability check.
- Push update optional in v1 — local timer updates sufficient.

### 13. Empty-state host nudges

- When filtered Discover list empty and user authenticated: CTA **"Host [sport] game"** opens Create with sport pre-filled.
- Copy varies by active filter (sport chip, venue, my sports).

## Non-Goals (all tiers)

- Per-sport skill on profile
- GPS check-in
- Player ratings
- Android
- Admin moderation dashboard
- Edit all future recurring sessions
- In-app friend graph

## Testing Requirements (all tiers)

- SQL integration tests per tier in `supabase/tests/phase_d_*.sql`
- iOS unit tests for pure logic (filters, prefill, preference encoding, waitlist position display)
- Edge: chat trigger test (mock or SQL insert message → outbox row)
- Manual device checklist per tier gate (push-heavy items)

## Notification Type Registry

| type | Tier | Recipient |
|------|------|-----------|
| session_reminder_1h | existing | joined + waitlist |
| session_reminder_15m | existing | joined + waitlist |
| waitlist_promoted | existing | promoted user |
| session_cancelled | existing | joined + waitlist |
| host_player_joined | 1 | host |
| host_session_reminder_1h | 1 | host |
| chat_message | 2 | joined + waitlist except sender |
