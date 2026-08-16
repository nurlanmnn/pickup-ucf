# Task C7 — Session Reports

**Branch:** `feat/pre-ui-roadmap`  
**Date:** 2026-07-18  
**Commit:** `feat: session report flow`

## Summary

Implemented session reporting end-to-end: database table with RLS, SQL verification, and iOS report sheet on session detail for non-host viewers.

## Database

**Migration:** `supabase/migrations/20260718183000_session_reports.sql`

- `session_reports` table: `id`, `reporter_id`, `session_id`, `reason` (10–500 chars), `created_at`
- Unique constraint on `(reporter_id, session_id)` prevents duplicate reports
- RLS: authenticated users may **insert** and **select** only their own rows

**Pushed:** `supabase db push --linked --include-all` (also applied pending `20260718181000_weather_cron.sql`)

## SQL tests

**File:** `supabase/tests/phase_c_reports.sql`  
**Wired in:** `supabase/tests/run_all.sql`

Covers:

- Check constraint rejects reason shorter than 10 characters
- Successful insert and reporter can select own row
- Duplicate insert raises `unique_violation`
- Other users cannot see reporter's row (RLS)

**Note:** Local `supabase db reset` + `run_all.sql` not run here (Docker unavailable). Remote migration applied successfully.

## iOS

**New files:**

- `ios/PickUpUCF/Repositories/ReportRepository.swift` — inserts into `session_reports` with client-side length validation and duplicate detection
- `ios/PickUpUCF/Features/SessionDetail/ReportSheet.swift` — reason text field (min 10 / max 500), submit with feedback

**Modified:**

- `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift` — "Report session" in the ⋯ menu when authenticated and not host (alongside existing "Block host" from C6)

## Manual verification

1. Open another user's session in Discover
2. Tap ⋯ → **Report session**
3. Enter at least 10 characters → **Submit report** (sheet dismisses)
4. Repeat report on same session → "You already reported this session."

## Gate checklist (C7 slice)

- [x] Migration + RLS
- [x] SQL test file
- [x] Report sheet on SessionDetailView (not own session)
- [x] `db push --linked`
- [x] Commit `feat: session report flow`
