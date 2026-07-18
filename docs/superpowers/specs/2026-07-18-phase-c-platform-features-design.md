# Phase C — Platform Features Design

**Date:** 2026-07-18  
**Prerequisite:** Phase B gate passed  
**Goal:** Recurring games, weather context for outdoor sessions, and basic safety tools.

## Scope

### Recurring sessions (v1 — weekly only)

- Host toggles "Repeat weekly" on create (same weekday + time, same duration)
- Store `recurrence_rule` as JSON: `{ "frequency": "weekly", "count": 4 }` (max 4 future instances)
- On session `completed` (attendance or cron), spawn next occurrence if count remaining
- No edit-all-future UI in v1 — edit affects single session only

### Weather snapshot

- For outdoor venues (`venues.is_official = true` and not RWC indoor courts) OR custom map location
- Edge Function `fetch-weather` calls [Open-Meteo](https://open-meteo.com/) (no API key)
- Store in `weather_snapshot` jsonb: `{ "summary": "...", "temp_f": 82, "precip_pct": 30, "fetched_at": "..." }`
- Fetch on session create + refresh via cron 3 hours before `starts_at`
- Show one-line hint on session detail: "82°F · 30% rain"

### Moderation (v1 — minimal)

**`user_blocks` table:** blocker_id, blocked_id, created_at (PK blocker+blocked)

- Block from session detail host row or profile (future: keep v1 to session detail participant list)
- Blocked user's hosted sessions hidden in Discover
- Cannot join blocked host's session (RPC check)

**`session_reports` table:** reporter_id, session_id, reason text, created_at

- Report button on session detail (not host's own session)
- No admin dashboard in v1 — data collected for manual review

## Non-goals

- RRULE full spec / Google Calendar sync
- Weather-based auto-cancel
- In-app admin moderation queue
- DM blocking outside sessions

## Testing requirements

- SQL: recurrence spawn, block join prevention, report insert RLS
- iOS: recurrence toggle creates rule; weather decodes; blocked sessions filtered
- Edge: Open-Meteo response parsing unit tests
- Manual: create weekly series; block user; report session
