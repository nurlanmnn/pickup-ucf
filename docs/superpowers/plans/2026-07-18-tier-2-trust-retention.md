# Tier 2 — Trust & Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:executing-plans`. **Prerequisite:** Tier 1 gate passed ([master roadmap](./2026-07-18-post-mvp-tiers-master-roadmap.md)).

**Goal:** Host mini profile, run-it-back session creation, chat message push, Apple Calendar export — fully tested.

**Spec:** [2026-07-18-post-mvp-tiers-design.md](../specs/2026-07-18-post-mvp-tiers-design.md)

---

## Task order

| Task | Summary | Backend | iOS |
|------|---------|---------|-----|
| T2-1 | Chat message → notification outbox | ✓ | |
| T2-2 | Host mini profile | | ✓ |
| T2-3 | Run it back prefill | | ✓ |
| T2-4 | Deep link open chat from push | | ✓ |
| T2-5 | Add to Apple Calendar | | ✓ |

---

### Task T2-1: Chat message push (database)

**Files:**
- Create: `supabase/migrations/20260718220000_chat_message_notifications.sql`
- Modify: `supabase/tests/phase_d_tier1.sql` OR create `supabase/tests/phase_d_tier2.sql` + add to `run_all.sql`

- [ ] **Step 1: Trigger**

```sql
CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sender_name text;
  v_sport text;
BEGIN
  SELECT display_name INTO v_sender_name FROM public.profiles WHERE id = NEW.user_id;
  SELECT sport::text INTO v_sport FROM public.sessions WHERE id = NEW.session_id;

  FOR r IN
    SELECT sp.user_id
    FROM public.session_participants sp
    WHERE sp.session_id = NEW.session_id
      AND sp.status IN ('joined', 'waitlist')
      AND sp.user_id <> NEW.user_id
  LOOP
    IF public.should_notify(r.user_id, 'chat_message') THEN
      PERFORM public.enqueue_notification(
        r.user_id,
        NEW.session_id,
        'chat_message',
        format('New message · %s', COALESCE(v_sport, 'Session')),
        format('%s: %s', COALESCE(v_sender_name, 'Someone'), left(NEW.body, 80)),
        format('chat_message:%s:%s', NEW.session_id, NEW.id)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message();
```

- [ ] **Step 2:** Update outbox payload in trigger to include `open_chat: true` in jsonb (extend `enqueue_notification` call payload param if needed — or build in trigger via direct INSERT).

- [ ] **Step 3: SQL test** — 2 participants, insert message, assert 1 outbox row for non-sender; prefs `chat_messages = false` → 0 rows.

- [ ] **Step 4: Commit** — `feat(db): chat message push notifications`

---

### Task T2-2: Host mini profile (iOS)

**Files:**
- Modify: `ios/PickUpUCF/Repositories/ProfileRepository.swift` — `fetchProfile(userId: UUID)`
- Create: `ios/PickUpUCF/Features/Profile/HostProfileView.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift` — host row tappable

- [ ] **Step 1:** Fetch public fields: display_name, username, games_played, show_up_streak, preferred_sports.

- [ ] **Step 2:** Read-only view; no edit actions; show block button only if not self and not host's own profile from own session.

- [ ] **Step 3:** NavigationLink from host Label on session detail.

- [ ] **Step 4: Commit** — `feat(ios): host mini profile`

---

### Task T2-3: Run it back (iOS)

**Files:**
- Create: `ios/PickUpUCF/Models/CreateSessionPrefill.swift`
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift` — `applyPrefill(_:)`
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift` — optional prefill init
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift` — button when `status == .completed`
- Create: `ios/PickUpUCFTests/CreateSessionPrefillTests.swift`

- [ ] **Step 1:** Prefill struct from `PickupSession` — sport, venue/custom location, skill, capacity, duration, notes.

- [ ] **Step 2:** Default `startsAt` = source.startsAt + 7 days (clamp to create allowed range).

- [ ] **Step 3:** "Run it back" opens create sheet from session detail (host or any participant).

- [ ] **Step 4:** Unit test — prefill maps fields; date +7 days.

- [ ] **Step 5: Commit** — `feat(ios): run it back session prefill`

---

### Task T2-4: Open chat from push (iOS)

**Files:**
- Modify: `ios/PickUpUCF/Core/PushNotificationService.swift` or `AppDelegate` — parse `chat_message` payload
- Modify: `ios/PickUpUCF/Core/AppState.swift` — `queueSessionDeepLink(id:openChat:)`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift` — auto-navigate to chat when flag set

- [ ] **Step 1:** When notification type is `chat_message`, set deep link with openChat=true.

- [ ] **Step 2:** Session detail pushes ChatView on appear if flag set; clear flag.

- [ ] **Step 3:** Manual test on device with chat push.

- [ ] **Step 4: Commit** — `feat(ios): open chat from push notification`

---

### Task T2-5: Add to Apple Calendar (iOS)

**Files:**
- Create: `ios/PickUpUCF/Core/CalendarExportService.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift`
- Modify: `ios/project.yml` — `NSCalendarsUsageDescription` in Info.plist properties

- [ ] **Step 1:** Request EventKit authorization once; build `EKEvent` with title, location, start/end, notes (include share link).

- [ ] **Step 2:** Button "Add to Calendar" on session detail (joined or host, upcoming only).

- [ ] **Step 3:** Handle denied permission with friendly error banner.

- [ ] **Step 4:** Unit test pure helper — event title/notes formatting (inject dates).

- [ ] **Step 5: Commit** — `feat(ios): add session to Apple Calendar`

---

## Tier 2 Gate Checklist

```bash
cd supabase && supabase db push && psql "$DATABASE_URL" -f tests/run_all.sql
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 17'
```

- [ ] Chat SQL test passes
- [ ] iOS tests pass
- [ ] Manual: host profile, run it back, chat push → chat, calendar event

**Next:** [Tier 3 plan](./2026-07-18-tier-3-campus-delight.md)
