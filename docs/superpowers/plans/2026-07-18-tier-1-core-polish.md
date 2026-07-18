# Tier 1 — Core Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:executing-plans` or `superpowers:subagent-driven-development`. **Prerequisite:** [Post-MVP master roadmap](./2026-07-18-post-mvp-tiers-master-roadmap.md). **One task per chat session recommended.**

**Goal:** My sports Discover filter, session roster/waitlist, blocked users settings, notification preferences, host push notifications — fully tested.

**Spec:** [2026-07-18-post-mvp-tiers-design.md](../specs/2026-07-18-post-mvp-tiers-design.md)

---

## Task order

| Task | Summary | Backend | iOS |
|------|---------|---------|-----|
| T1-1 | Notification preferences schema | ✓ | |
| T1-2 | `should_notify` + wire existing enqueue sites | ✓ | |
| T1-3 | Host join + host reminder notifications | ✓ | |
| T1-4 | Session roster + waitlist RPC | ✓ | |
| T1-5 | Notification settings UI | | ✓ |
| T1-6 | Session roster UI + waitlist label | | ✓ |
| T1-7 | Blocked users settings | | ✓ |
| T1-8 | Discover "My sports" default filter | | ✓ |

---

### Task T1-1: Notification preferences (database)

**Files:**
- Create: `supabase/migrations/20260718210000_notification_preferences.sql`
- Create: `supabase/tests/phase_d_tier1.sql` (first section)
- Modify: `supabase/tests/run_all.sql` — add `\ir phase_d_tier1.sql`

- [ ] **Step 1: Migration**

```sql
CREATE TABLE public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_reminders boolean NOT NULL DEFAULT true,
  waitlist_promoted boolean NOT NULL DEFAULT true,
  session_cancelled boolean NOT NULL DEFAULT true,
  host_player_joined boolean NOT NULL DEFAULT true,
  host_session_reminder boolean NOT NULL DEFAULT true,
  chat_messages boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY notification_preferences_own ON public.notification_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TRIGGER notification_preferences_updated_at
  BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
```

- [ ] **Step 2: SQL test** — insert row as test user, verify RLS (own row only).

- [ ] **Step 3:** `supabase db push` + run `run_all.sql`

- [ ] **Step 4: Commit** — `feat(db): notification_preferences table`

---

### Task T1-2: should_notify helper + wire existing triggers

**Files:**
- Modify: `supabase/migrations/20260718210000_notification_preferences.sql` (append) OR new migration `20260718211000_should_notify.sql`
- Modify: `supabase/migrations/20260718150000_notification_triggers.sql` pattern in new migration (replace functions)
- Modify: `supabase/migrations/20260718160000_session_reminders_cron.sql` pattern in new migration
- Modify: `supabase/tests/phase_d_tier1.sql`

- [ ] **Step 1: Helper**

```sql
CREATE OR REPLACE FUNCTION public.should_notify(p_user_id uuid, p_type text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE p_type
    WHEN 'session_reminder_1h' THEN COALESCE(p.session_reminders, true)
    WHEN 'session_reminder_15m' THEN COALESCE(p.session_reminders, true)
    WHEN 'waitlist_promoted' THEN COALESCE(p.waitlist_promoted, true)
    WHEN 'session_cancelled' THEN COALESCE(p.session_cancelled, true)
    WHEN 'host_player_joined' THEN COALESCE(p.host_player_joined, true)
    WHEN 'host_session_reminder_1h' THEN COALESCE(p.host_session_reminder, true)
    WHEN 'chat_message' THEN COALESCE(p.chat_messages, true)
    ELSE true
  END
  FROM (SELECT 1) _
  LEFT JOIN public.notification_preferences p ON p.user_id = p_user_id;
$$;
```

- [ ] **Step 2: Update `notify_session_cancelled`, `leave_session` waitlist promote, `enqueue_session_reminders`** — wrap each `enqueue_notification` with `IF public.should_notify(user_id, type) THEN ... END IF;`

- [ ] **Step 3: SQL test** — user with `session_reminders = false` → reminder enqueue skipped (mock via direct call to cron function or insert prefs + run enqueue helper).

- [ ] **Step 4: Commit** — `feat(db): should_notify gates notification enqueue`

---

### Task T1-3: Host notifications (database)

**Files:**
- Create: `supabase/migrations/20260718212000_host_notifications.sql`
- Modify: `supabase/tests/phase_d_tier1.sql`

- [ ] **Step 1: Trigger on join**

```sql
CREATE OR REPLACE FUNCTION public.notify_host_player_joined()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_joiner_name text;
  v_sport text;
BEGIN
  IF NEW.status <> 'joined' OR NEW.role = 'host' THEN
    RETURN NEW;
  END IF;

  SELECT s.host_id, s.sport::text INTO v_host_id, v_sport
  FROM public.sessions s WHERE s.id = NEW.session_id;

  IF v_host_id IS NULL OR v_host_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT display_name INTO v_joiner_name FROM public.profiles WHERE id = NEW.user_id;

  IF public.should_notify(v_host_id, 'host_player_joined') THEN
    PERFORM public.enqueue_notification(
      v_host_id,
      NEW.session_id,
      'host_player_joined',
      'Player joined',
      format('%s joined your %s game.', COALESCE(v_joiner_name, 'Someone'), v_sport),
      format('host_player_joined:%s:%s:%s', NEW.session_id, NEW.user_id, NEW.joined_at)
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_host_player_joined
  AFTER INSERT OR UPDATE OF status ON public.session_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_host_player_joined();
```

- [ ] **Step 2: Host 1h reminder** — extend `enqueue_session_reminders` to also notify `sessions.host_id` with type `host_session_reminder_1h` (dedupe key `host_session_reminder_1h:{session_id}`).

- [ ] **Step 3: SQL test** — insert join participant → outbox row for host; prefs off → no row.

- [ ] **Step 4: Commit** — `feat(db): host join and reminder notifications`

---

### Task T1-4: Session roster RPC (database)

**Files:**
- Create: `supabase/migrations/20260718213000_session_roster.sql`
- Modify: `supabase/tests/phase_d_tier1.sql`

- [ ] **Step 1: RPC**

```sql
CREATE OR REPLACE FUNCTION public.get_session_roster(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_viewer_waitlist int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT row_number INTO v_viewer_waitlist
  FROM (
    SELECT user_id, row_number() OVER (ORDER BY joined_at) AS row_number
    FROM public.session_participants
    WHERE session_id = p_session_id AND status = 'waitlist'
  ) w
  WHERE user_id = auth.uid();

  SELECT jsonb_build_object(
    'joined', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', sp.user_id,
        'display_name', p.display_name,
        'username', p.username,
        'role', sp.role
      ) ORDER BY sp.joined_at)
      FROM public.session_participants sp
      JOIN public.profiles p ON p.id = sp.user_id
      WHERE sp.session_id = p_session_id AND sp.status = 'joined'
    ), '[]'::jsonb),
    'waitlist_count', (
      SELECT count(*)::int FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
    ),
    'viewer_waitlist_position', v_viewer_waitlist
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_session_roster(uuid) TO authenticated;
```

- [ ] **Step 2: SQL test** — 2 joined, 2 waitlist, assert position for waitlisted user = 1 or 2.

- [ ] **Step 3: Commit** — `feat(db): get_session_roster RPC`

---

### Task T1-5: Notification settings (iOS)

**Files:**
- Create: `ios/PickUpUCF/Models/NotificationPreferences.swift`
- Create: `ios/PickUpUCF/Repositories/NotificationPreferencesRepository.swift`
- Create: `ios/PickUpUCF/Features/Profile/NotificationSettingsView.swift`
- Create: `ios/PickUpUCF/Features/Profile/NotificationSettingsViewModel.swift`
- Modify: `ios/PickUpUCF/Features/Profile/ProfileSettingsView.swift`
- Create: `ios/PickUpUCFTests/NotificationPreferencesTests.swift`

- [ ] **Step 1:** Model mirrors DB columns; Codable for upsert.

- [ ] **Step 2:** Repository `fetch()` / `save(_:)` against `notification_preferences` table.

- [ ] **Step 3:** Settings UI — 6 toggles with short descriptions.

- [ ] **Step 4:** Unit test — default all true when no row; encoding keys match snake_case.

- [ ] **Step 5: Commit** — `feat(ios): notification preferences settings`

---

### Task T1-6: Session roster UI (iOS)

**Files:**
- Create: `ios/PickUpUCF/Models/SessionRoster.swift`
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift` — `fetchRoster(sessionId:)`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailViewModel.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift`
- Create: `ios/PickUpUCFTests/SessionRosterTests.swift`

- [ ] **Step 1:** Decode RPC jsonb response.

- [ ] **Step 2:** ViewModel loads roster with session.

- [ ] **Step 3:** UI section "Players (N)" — list display names; if viewer waitlisted show "You're #K on the waitlist (M waiting)".

- [ ] **Step 4:** Unit test — decode sample JSON; waitlist label formatting.

- [ ] **Step 5: Commit** — `feat(ios): session roster and waitlist position`

---

### Task T1-7: Blocked users settings (iOS)

**Files:**
- Modify: `ios/PickUpUCF/Repositories/BlockRepository.swift` — `unblock`, `fetchBlockedUsers()`
- Create: `ios/PickUpUCF/Models/BlockedUser.swift`
- Create: `ios/PickUpUCF/Features/Profile/BlockedUsersView.swift`
- Modify: `ios/PickUpUCF/Features/Profile/ProfileSettingsView.swift`
- Create: `ios/PickUpUCFTests/BlockedUsersTests.swift`

- [ ] **Step 1:** `fetchBlockedUsers` — select `blocked_id` join profiles (display_name, username).

- [ ] **Step 2:** `unblock(userId:)` → `unblock_user` RPC.

- [ ] **Step 3:** List UI with unblock button; empty state "No blocked users".

- [ ] **Step 4:** Unit test — stub list mapping.

- [ ] **Step 5: Commit** — `feat(ios): blocked users management`

---

### Task T1-8: Discover "My sports" filter (iOS)

**Files:**
- Create: `ios/PickUpUCF/Models/DiscoverSportFilterMode.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverViewModel.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverView.swift`
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift` — optional `sports: [SportType]?` filter (client-side OK: filter `items.filter { prefs.contains($0.sport) }`)
- Create: `ios/PickUpUCFTests/MySportsFilterTests.swift`

- [ ] **Step 1:** Enum `.mySports` | `.single(SportType?)` — load preferred sports from profile on first fetch.

- [ ] **Step 2:** Sport chips — "My sports" chip when prefs non-empty; selecting single sport overrides.

- [ ] **Step 3:** Persist last mode in `UserDefaults`.

- [ ] **Step 4:** Unit test — filter logic with 3 sessions, 2 matching preferred sports.

- [ ] **Step 5: Commit** — `feat(ios): Discover my sports default filter`

---

## Tier 1 Gate Checklist

```bash
cd supabase && supabase db push && psql "$DATABASE_URL" -f tests/run_all.sql
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 17'
cd supabase/functions/send-push && deno test --allow-env --allow-net
```

- [ ] All automated tests green
- [ ] Manual device checklist from master roadmap

**Next:** [Tier 2 plan](./2026-07-18-tier-2-trust-retention.md)
