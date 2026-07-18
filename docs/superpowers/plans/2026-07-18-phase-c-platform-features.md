# Phase C — Platform Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. **Prerequisite:** Phase B gate passed ([master roadmap](./2026-07-18-pre-ui-master-roadmap.md)).

**Goal:** Weekly recurring sessions, weather hints for outdoor games, and block/report moderation — fully tested.

**Spec:** [2026-07-18-phase-c-platform-features-design.md](../specs/2026-07-18-phase-c-platform-features-design.md)

---

### Task C1: Recurring sessions (database)

**Files:**
- Create: `supabase/migrations/20260718180000_recurring_sessions.sql`
- Create: `supabase/tests/phase_c_recurrence.sql`

- [ ] **Step 1: Add columns to track series**

```sql
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS recurrence_parent_id uuid REFERENCES public.sessions (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recurrence_index int NOT NULL DEFAULT 1 CHECK (recurrence_index >= 1);
```

`recurrence_rule` already exists — store JSON text: `{"frequency":"weekly","count":4}`.

- [ ] **Step 2: spawn_next_recurring_session RPC**

```sql
CREATE OR REPLACE FUNCTION public.spawn_next_recurring_session(p_completed_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_src public.sessions%ROWTYPE;
  v_rule jsonb;
  v_count int;
  v_next_starts timestamptz;
  v_next_ends interval;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_src FROM public.sessions WHERE id = p_completed_session_id;
  IF NOT FOUND OR v_src.recurrence_rule IS NULL THEN RETURN NULL; END IF;

  v_rule := v_src.recurrence_rule::jsonb;
  v_count := (v_rule->>'count')::int;
  IF v_src.recurrence_index >= v_count THEN RETURN NULL; END IF;

  v_next_starts := v_src.starts_at + interval '7 days';
  v_next_ends := v_src.ends_at - v_src.starts_at;

  INSERT INTO public.sessions (
    host_id, sport, venue_id, custom_location, custom_lat, custom_lng,
    starts_at, ends_at, capacity, player_count, skill_level, notes, status,
    recurrence_rule, recurrence_parent_id, recurrence_index
  )
  VALUES (
    v_src.host_id, v_src.sport, v_src.venue_id, v_src.custom_location,
    v_src.custom_lat, v_src.custom_lng,
    v_next_starts, v_next_starts + v_next_ends, v_src.capacity, 1,
    v_src.skill_level, v_src.notes, 'open',
    v_src.recurrence_rule,
    COALESCE(v_src.recurrence_parent_id, v_src.id),
    v_src.recurrence_index + 1
  )
  RETURNING id INTO v_new_id;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_new_id, v_src.host_id, 'host', 'joined');

  RETURN v_new_id;
END;
$$;
```

- [ ] **Step 3: Hook into complete flow** — call from `submit_session_attendance` and `complete_expired_sessions` when `recurrence_rule IS NOT NULL`.

- [ ] **Step 4: SQL test** — complete session with rule count=3, assert 2 spawns max, dates +7 days.

- [ ] **Step 5: Commit** — `feat(db): weekly recurring session spawn`

---

### Task C2: Recurring sessions (iOS create UI)

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift`
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift`
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift`
- Create: `ios/PickUpUCFTests/RecurrenceRuleTests.swift`

- [ ] **Step 1: Toggle "Repeat weekly" + stepper "Weeks (2–4)" default 4.**

- [ ] **Step 2: On create, set `recurrence_rule` JSON string on insert payload.**

- [ ] **Step 3: Unit test** — encoding produces `{"frequency":"weekly","count":4}`.

- [ ] **Step 4: Manual test** — create 2-week series, mark first complete, verify second appears in Discover.

- [ ] **Step 5: Commit** — `feat(ios): weekly recurring session creation`

---

### Task C3: Weather Edge Function

**Files:**
- Create: `supabase/functions/fetch-weather/index.ts`
- Create: `supabase/functions/fetch-weather/weather_test.ts`
- Create: `supabase/functions/fetch-weather/config.toml`

- [ ] **Step 1: Implement Open-Meteo fetch**

```typescript
// Input: lat, lng, starts_at ISO
// Output: { summary, temp_f, precip_pct, fetched_at }
// Use hourly forecast closest to starts_at
```

- [ ] **Step 2: Unit test** — mock fetch response, assert parse.

- [ ] **Step 3: Deploy + secret** — none required for Open-Meteo.

- [ ] **Step 4: Commit** — `feat: fetch-weather Edge Function`

---

### Task C4: Weather snapshot on sessions

**Files:**
- Create: `supabase/migrations/20260718181000_weather_cron.sql`
- Modify: `ios/PickUpUCF/Models/PickupSession.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift`
- Create: `ios/PickUpUCF/Models/WeatherSnapshot.swift`
- Create: `ios/PickUpUCFTests/WeatherSnapshotTests.swift`

- [ ] **Step 1: DB function `refresh_session_weather(p_session_id)`** — calls Edge Function via pg_net or invoked from cron scanning sessions starting in 3h with null/stale snapshot.

- [ ] **Step 2: On session create (iOS)** — invoke `fetch-weather` for outdoor sessions, patch `weather_snapshot`.

- [ ] **Step 3: WeatherSnapshot model + one-line UI** under location on session detail.

- [ ] **Step 4: Unit test decode sample jsonb.

- [ ] **Step 5: Manual test** — outdoor session at IM Fields shows temp line.

- [ ] **Step 6: Commit** — `feat: weather snapshot on outdoor sessions`

---

### Task C5: User blocks

**Files:**
- Create: `supabase/migrations/20260718182000_user_blocks.sql`
- Create: `supabase/tests/phase_c_blocks.sql`

- [ ] **Step 1: Table + RLS**

```sql
CREATE TABLE public.user_blocks (
  blocker_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_blocks_own ON public.user_blocks
  FOR ALL TO authenticated
  USING (blocker_id = auth.uid())
  WITH CHECK (blocker_id = auth.uid());
```

- [ ] **Step 2: RPCs `block_user`, `unblock_user`**

- [ ] **Step 3: Update `join_session`** — reject if host blocked caller or caller blocked host.

- [ ] **Step 4: SQL test** — block prevents join.

- [ ] **Step 5: Commit** — `feat(db): user blocks`

---

### Task C6: Block UI + Discover filter

**Files:**
- Create: `ios/PickUpUCF/Repositories/BlockRepository.swift`
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift` — filter blocked hosts client-side (fetch block list once)
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift` — "Block host" in menu (not own session)
- Create: `ios/PickUpUCFTests/BlockedSessionFilterTests.swift`

- [ ] **Step 1: BlockRepository.block(userId:)**

- [ ] **Step 2: DiscoverViewModel filters out sessions where hostId in blocked set**

- [ ] **Step 3: Unit test** — 3 sessions, 1 blocked host → 2 remain.

- [ ] **Step 4: Manual test** — block host, their game disappears from Discover.

- [ ] **Step 5: Commit** — `feat(ios): block user and hide their sessions`

---

### Task C7: Session reports

**Files:**
- Create: `supabase/migrations/20260718183000_session_reports.sql`
- Create: `supabase/tests/phase_c_reports.sql`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift`

- [ ] **Step 1: Table**

```sql
CREATE TABLE public.session_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 10 AND 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, session_id)
);
```

RLS: insert own, select own only.

- [ ] **Step 2: Report sheet** — text field min 10 chars, submit.

- [ ] **Step 3: SQL test** — insert report, duplicate rejected.

- [ ] **Step 4: Commit** — `feat: session report flow`

---

## Phase C Gate Checklist

```bash
cd supabase && supabase db reset && supabase db push && psql "$DATABASE_URL" -f tests/run_all.sql
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16'
cd supabase/functions/fetch-weather && deno test --allow-env --allow-net
```

- [ ] Recurring: 4-week series spawns correctly after complete
- [ ] Weather: outdoor session shows forecast line
- [ ] Block: host hidden, join rejected
- [ ] Report: submits once, duplicate prevented
- [ ] All automated tests green

**All pre-UI tiers complete.** UI polish can begin after this gate.

---

## Full Roadmap Complete

| Tier | Item | Phase |
|------|------|-------|
| 1 | Push notifications | A |
| 1 | Sport expansion | B |
| 1 | Onboarding + profile | B |
| 1 | Share (tested) | B |
| 2 | Attendance | A |
| 2 | Reminders | A |
| 2 | Discover filters | B |
| 3 | Recurring sessions | C |
| 3 | Weather | C |
| 3 | Moderation | C |
