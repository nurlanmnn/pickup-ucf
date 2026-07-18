# Phase A — Core Loop Reliability Implementation Plan

> **Part of:** [Pre-UI Master Roadmap](./2026-07-18-pre-ui-master-roadmap.md) — complete **Task 0** (test infrastructure) first, then this phase. Do **not** start Phase B until the Phase A gate passes.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship push notifications, host attendance, and session lifecycle automation so the join → show up → play loop is reliable.

**Architecture:** iOS registers APNs tokens in `device_tokens`. Database triggers and pg_cron enqueue rows in `notification_outbox`. A `send-push` Edge Function delivers via APNs HTTP/2. Hosts submit attendance through a secure RPC that updates `attendance` and profile stats. Expired sessions auto-complete via cron.

**Tech Stack:** SwiftUI (iOS 17+), Supabase Swift SDK 2.21+, Supabase Postgres + Edge Functions (Deno), APNs Auth Key, pg_cron

## Global Constraints

- UCF email only (`@ucf.edu`, `@knights.ucf.edu`) — existing `is_ucf_email()` guard
- Bundle ID: `edu.ucf.pickup`
- Deep link scheme: `pickupucf://session/{uuid}` — existing `DeepLinkRouter`
- No new third-party iOS dependencies
- Follow existing patterns: `@Observable` ViewModels, `*Repository` protocols, `Loadable<T>`, `AppErrorMapper`
- Migrations in `supabase/migrations/` with timestamp prefix
- Edge Functions in `supabase/functions/` matching `send-auth-email` layout

**Spec:** [2026-07-18-core-loop-reliability-design.md](../specs/2026-07-18-core-loop-reliability-design.md)

---

## File Map

| File | Responsibility |
|------|----------------|
| `supabase/migrations/20260718140000_core_loop_reliability.sql` | Outbox table, attendance RLS, RPCs, triggers, cron |
| `supabase/functions/send-push/index.ts` | APNs delivery + outbox processing |
| `supabase/functions/send-push/config.toml` | Edge function config |
| `ios/PickUpUCF/Core/AppDelegate.swift` | APNs registration + notification delegate |
| `ios/PickUpUCF/Core/PushNotificationService.swift` | Permission + token lifecycle |
| `ios/PickUpUCF/Repositories/DeviceTokenRepository.swift` | Upsert/delete device tokens |
| `ios/PickUpUCF/Repositories/AttendanceRepository.swift` | Fetch participants + submit attendance |
| `ios/PickUpUCF/Features/SessionDetail/AttendanceSheet.swift` | Host attendance UI |
| `ios/PickUpUCF/Models/SessionParticipant.swift` | Participant row for attendance list |
| Modify: `PickUpUCFApp.swift`, `SessionDetailView*.swift`, `ProfileView.swift`, `Profile.swift`, `project.yml`, `Info.plist`, `README.md` |

---

### Task 1: Database foundation — outbox, attendance RLS, enqueue helper

**Files:**
- Create: `supabase/migrations/20260718140000_core_loop_reliability.sql`

**Interfaces:**
- Produces: `public.enqueue_notification(p_user_id uuid, p_session_id uuid, p_type text, p_title text, p_body text, p_dedupe_key text) RETURNS void`

- [ ] **Step 1: Write migration**

Create `supabase/migrations/20260718140000_core_loop_reliability.sql`:

```sql
-- Core loop reliability: notifications, attendance, session lifecycle

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Notification outbox (service role / Edge Function only)
CREATE TABLE public.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.sessions (id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  dedupe_key text NOT NULL,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_outbox_dedupe_key_unique UNIQUE (dedupe_key)
);

CREATE INDEX idx_notification_outbox_pending
  ON public.notification_outbox (created_at)
  WHERE sent_at IS NULL;

ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
-- No policies: clients cannot read/write outbox

-- Attendance RLS (reads only; writes via RPC)
CREATE POLICY attendance_select ON public.attendance
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND public.is_session_participant(session_id)
  );

-- Enqueue helper (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid,
  p_session_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_dedupe_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_outbox (
    user_id, session_id, type, title, body, payload, dedupe_key
  )
  VALUES (
    p_user_id,
    p_session_id,
    p_type,
    p_title,
    p_body,
    jsonb_build_object('session_id', p_session_id),
    p_dedupe_key
  )
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_notification(uuid, uuid, text, text, text, text) FROM PUBLIC;
```

- [ ] **Step 2: Apply migration locally**

Run:
```bash
cd supabase && supabase db push
```
Expected: migration applies without error.

- [ ] **Step 3: Verify table exists**

Run in Supabase SQL editor or psql:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'notification_outbox' ORDER BY ordinal_position;
```
Expected: 9 columns including `dedupe_key`, `sent_at`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260718140000_core_loop_reliability.sql
git commit -m "feat(db): add notification outbox and attendance select policy"
```

---

### Task 2: Attendance RPC + auto-complete expired sessions

**Files:**
- Modify: `supabase/migrations/20260718140000_core_loop_reliability.sql` (append)

**Interfaces:**
- Produces: `public.submit_session_attendance(p_session_id uuid, p_attended_user_ids uuid[]) RETURNS void`
- Produces: `public.complete_expired_sessions() RETURNS int`

- [ ] **Step 1: Append RPCs to migration**

```sql
-- Auto-complete sessions past end time
CREATE OR REPLACE FUNCTION public.complete_expired_sessions()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.sessions
  SET status = 'completed', updated_at = now()
  WHERE status IN ('open', 'full')
    AND ends_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Host marks attendance within 24h after session ends
CREATE OR REPLACE FUNCTION public.submit_session_attendance(
  p_session_id uuid,
  p_attended_user_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_status session_status;
  v_joined_user uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT host_id, starts_at, ends_at, status
  INTO v_host_id, v_starts_at, v_ends_at, v_status
  FROM public.sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  IF v_host_id <> auth.uid() THEN
    RAISE EXCEPTION 'not_host';
  END IF;

  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'session_cancelled';
  END IF;

  IF v_starts_at > now() THEN
    RAISE EXCEPTION 'session_not_started';
  END IF;

  IF now() > v_ends_at + interval '24 hours' THEN
    RAISE EXCEPTION 'attendance_window_closed';
  END IF;

  -- Replace attendance rows for this session
  DELETE FROM public.attendance WHERE session_id = p_session_id;

  INSERT INTO public.attendance (session_id, user_id)
  SELECT p_session_id, uid
  FROM unnest(p_attended_user_ids) AS uid
  WHERE EXISTS (
    SELECT 1 FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = uid
      AND sp.status = 'joined'
  );

  -- Attended: increment games_played + streak
  UPDATE public.profiles p
  SET
    games_played = games_played + 1,
    show_up_streak = show_up_streak + 1,
    updated_at = now()
  WHERE p.id = ANY(p_attended_user_ids)
    AND EXISTS (
      SELECT 1 FROM public.session_participants sp
      WHERE sp.session_id = p_session_id
        AND sp.user_id = p.id
        AND sp.status = 'joined'
    );

  -- No-shows among joined players: reset streak
  UPDATE public.profiles p
  SET show_up_streak = 0, updated_at = now()
  WHERE EXISTS (
    SELECT 1 FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = p.id
      AND sp.status = 'joined'
  )
  AND p.id <> ALL(COALESCE(p_attended_user_ids, ARRAY[]::uuid[]));

  UPDATE public.sessions
  SET status = 'completed', updated_at = now()
  WHERE id = p_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_session_attendance(uuid, uuid[]) TO authenticated;
```

- [ ] **Step 2: Apply and smoke-test RPC**

```bash
cd supabase && supabase db push
```

Manual SQL (replace UUIDs with test session):
```sql
-- As host via authenticated role in app, or use service role for local test
SELECT public.complete_expired_sessions();
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260718140000_core_loop_reliability.sql
git commit -m "feat(db): add attendance submission and session auto-complete"
```

---

### Task 3: Notification triggers — cancel + waitlist promote

**Files:**
- Modify: `supabase/migrations/20260718140000_core_loop_reliability.sql` (append)
- Modify: `supabase/migrations/20260520180000_fix_join_session_status_type.sql` is NOT touched; update `leave_session` in new migration

**Interfaces:**
- Produces: trigger `trg_sessions_notify_cancelled` on `sessions`
- Produces: updated `public.leave_session(p_session_id uuid)` with waitlist promotion notification

- [ ] **Step 1: Session cancelled trigger**

Append to migration:

```sql
CREATE OR REPLACE FUNCTION public.notify_session_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sport text;
  v_location text;
BEGIN
  IF NEW.status <> 'cancelled' OR OLD.status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  v_sport := NEW.sport::text;
  SELECT COALESCE(v.name, NEW.custom_location, 'campus')
  INTO v_location
  FROM public.venues v WHERE v.id = NEW.venue_id;

  FOR r IN
    SELECT sp.user_id
    FROM public.session_participants sp
    WHERE sp.session_id = NEW.id
      AND sp.status IN ('joined', 'waitlist')
  LOOP
    PERFORM public.enqueue_notification(
      r.user_id,
      NEW.id,
      'session_cancelled',
      'Game cancelled',
      format('%s at %s was cancelled by the host.', v_sport, v_location),
      format('session_cancelled:%s:%s', NEW.id, r.user_id)
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sessions_notify_cancelled
  AFTER UPDATE OF status ON public.sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_session_cancelled();
```

- [ ] **Step 2: Replace leave_session with promotion notification**

Append full replacement (copy existing logic from `20260520180000_fix_join_session_status_type.sql` and add notification block after waitlist promotion):

```sql
CREATE OR REPLACE FUNCTION public.leave_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev_status participant_status;
  v_promoted_user uuid;
  v_sport text;
  v_location text;
BEGIN
  SELECT status INTO v_prev_status
  FROM public.session_participants
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF NOT FOUND THEN
    RETURN;
  END IF;

  UPDATE public.session_participants
  SET status = 'left'
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF v_prev_status = 'joined' THEN
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = 'open'
    WHERE id = p_session_id AND status = 'full';

    WITH next_wait AS (
      SELECT user_id FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
      ORDER BY joined_at ASC
      LIMIT 1
    )
    UPDATE public.session_participants sp
    SET status = 'joined'
    FROM next_wait nw
    WHERE sp.session_id = p_session_id AND sp.user_id = nw.user_id
    RETURNING sp.user_id INTO v_promoted_user;

    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE
          WHEN player_count + 1 >= capacity THEN 'full'::session_status
          ELSE status
        END
    WHERE id = p_session_id
      AND v_promoted_user IS NOT NULL;

    IF v_promoted_user IS NOT NULL THEN
      SELECT s.sport::text, COALESCE(v.name, s.custom_location, 'campus')
      INTO v_sport, v_location
      FROM public.sessions s
      LEFT JOIN public.venues v ON v.id = s.venue_id
      WHERE s.id = p_session_id;

      PERFORM public.enqueue_notification(
        v_promoted_user,
        p_session_id,
        'waitlist_promoted',
        'You''re in!',
        format('A spot opened for %s at %s.', v_sport, v_location),
        format('waitlist_promoted:%s:%s', p_session_id, v_promoted_user)
      );
    END IF;
  END IF;
END;
$$;
```

- [ ] **Step 3: Apply migration**

```bash
cd supabase && supabase db push
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260718140000_core_loop_reliability.sql
git commit -m "feat(db): enqueue notifications on cancel and waitlist promotion"
```

---

### Task 4: Scheduled reminders + session completion cron

**Files:**
- Modify: `supabase/migrations/20260718140000_core_loop_reliability.sql` (append)

**Interfaces:**
- Produces: `public.enqueue_session_reminders(p_window text)` where `p_window` is `'1h'` or `'15m'`

- [ ] **Step 1: Reminder enqueue function**

```sql
CREATE OR REPLACE FUNCTION public.enqueue_session_reminders(p_window text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
  v_type text;
  v_title text;
  v_body text;
  v_interval interval;
BEGIN
  IF p_window = '1h' THEN
    v_type := 'session_reminder_1h';
    v_title := 'Game in 1 hour';
    v_interval := interval '1 hour';
  ELSIF p_window = '15m' THEN
    v_type := 'session_reminder_15m';
    v_title := 'Game in 15 minutes';
    v_interval := interval '15 minutes';
  ELSE
    RAISE EXCEPTION 'invalid_window';
  END IF;

  FOR r IN
    SELECT s.id AS session_id, sp.user_id, s.sport::text AS sport,
           COALESCE(v.name, s.custom_location, 'campus') AS location
    FROM public.sessions s
    JOIN public.session_participants sp ON sp.session_id = s.id
    LEFT JOIN public.venues v ON v.id = s.venue_id
    WHERE s.status IN ('open', 'full')
      AND sp.status IN ('joined', 'waitlist')
      AND s.starts_at > now()
      AND s.starts_at <= now() + v_interval + interval '5 minutes'
      AND s.starts_at > now() + v_interval - interval '5 minutes'
  LOOP
    v_body := format('%s at %s starts soon.', r.sport, r.location);
    PERFORM public.enqueue_notification(
      r.user_id,
      r.session_id,
      v_type,
      v_title,
      v_body,
      format('%s:%s:%s', v_type, r.session_id, r.user_id)
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- pg_cron jobs (requires extension enabled on hosted Supabase: Database → Extensions → pg_cron)
SELECT cron.schedule(
  'pickup-complete-expired-sessions',
  '*/15 * * * *',
  $$SELECT public.complete_expired_sessions();$$
);

SELECT cron.schedule(
  'pickup-reminder-1h',
  '*/5 * * * *',
  $$SELECT public.enqueue_session_reminders('1h');$$
);

SELECT cron.schedule(
  'pickup-reminder-15m',
  '*/5 * * * *',
  $$SELECT public.enqueue_session_reminders('15m');$$
);
```

- [ ] **Step 2: Enable pg_cron on hosted Supabase**

In Supabase Dashboard → Database → Extensions → enable `pg_cron`.

Run `supabase db push` again if needed.

- [ ] **Step 3: Verify cron jobs**

```sql
SELECT jobid, schedule, command FROM cron.job WHERE command LIKE '%pickup-%';
```
Expected: 3 jobs.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260718140000_core_loop_reliability.sql
git commit -m "feat(db): schedule session reminders and auto-complete cron jobs"
```

---

### Task 5: send-push Edge Function

**Files:**
- Create: `supabase/functions/send-push/index.ts`
- Create: `supabase/functions/send-push/config.toml`

**Interfaces:**
- Consumes: `notification_outbox` rows (`user_id`, `title`, `body`, `payload`)
- Consumes: `device_tokens.apns_token` for recipient
- Produces: HTTP POST callable by pg_cron webhook or Supabase scheduled trigger

- [ ] **Step 1: Create config**

`supabase/functions/send-push/config.toml`:
```toml
[functions.send-push]
verify_jwt = false
```

Set `verify_jwt = false` because cron invokes with service role secret header; validate `Authorization: Bearer ${CRON_SECRET}` in function body.

- [ ] **Step 2: Implement Edge Function**

Create `supabase/functions/send-push/index.ts` using APNs HTTP/2 with JWT auth. Core logic:

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

const BATCH_SIZE = 50;

Deno.serve(async (req) => {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const auth = req.headers.get("Authorization") ?? "";
  if (!cronSecret || auth !== `Bearer ${cronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: pending, error } = await supabase
    .from("notification_outbox")
    .select("id, user_id, title, body, payload")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) return new Response(error.message, { status: 500 });
  if (!pending?.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  let sent = 0;
  for (const row of pending) {
    const ok = await sendToUserDevices(supabase, row);
    if (ok) {
      await supabase
        .from("notification_outbox")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", row.id);
      sent++;
    }
  }

  return new Response(JSON.stringify({ sent }), {
    headers: { "Content-Type": "application/json" },
  });
});

async function sendToUserDevices(supabase: any, row: any): Promise<boolean> {
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("apns_token")
    .eq("user_id", row.user_id);

  if (!tokens?.length) return true; // nothing to send; mark processed

  const jwt = await apnsJwt();
  const sessionId = row.payload?.session_id;
  const url = sessionId
    ? `pickupucf://session/${sessionId}`
    : undefined;

  let anySuccess = false;
  for (const { apns_token } of tokens) {
    const res = await fetch(
      `https://api.push.apple.com/3/device/${apns_token}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: { alert: { title: row.title, body: row.body }, sound: "default" },
          ...(url ? { url } : {}),
        }),
      },
    );

    if (res.ok) anySuccess = true;
    if (res.status === 410) {
      await supabase.from("device_tokens").delete().eq("apns_token", apns_token);
    }
  }
  return anySuccess || !tokens.length;
}

async function apnsJwt(): Promise<string> {
  const key = await importPKCS8(Deno.env.get("APNS_PRIVATE_KEY")!, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt()
    .sign(key);
}
```

Use `https://api.sandbox.push.apple.com` when `APNS_ENV=sandbox`.

- [ ] **Step 3: Set secrets and deploy**

```bash
supabase secrets set \
  APNS_KEY_ID=... \
  APNS_TEAM_ID=... \
  APNS_BUNDLE_ID=edu.ucf.pickup \
  APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----" \
  APNS_ENV=sandbox \
  CRON_SECRET=$(openssl rand -hex 32)

supabase functions deploy send-push
```

- [ ] **Step 4: Schedule Edge Function invocation**

In Supabase Dashboard → Edge Functions → send-push → schedule every 1 minute, OR add pg_cron:

```sql
SELECT cron.schedule(
  'pickup-dispatch-push',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret')
    )
  );
  $$
);
```

Alternative (simpler for v1): use Supabase **Scheduled Functions** in dashboard calling `send-push` with `CRON_SECRET` header.

- [ ] **Step 5: Manual test**

Insert test outbox row + device token, invoke:
```bash
curl -X POST "$SUPABASE_URL/functions/v1/send-push" \
  -H "Authorization: Bearer $CRON_SECRET"
```
Expected: `{ "sent": 1 }` and push arrives on device.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/send-push/
git commit -m "feat: add send-push Edge Function for APNs delivery"
```

---

### Task 6: iOS push registration

**Files:**
- Create: `ios/PickUpUCF/Core/AppDelegate.swift`
- Create: `ios/PickUpUCF/Core/PushNotificationService.swift`
- Create: `ios/PickUpUCF/Repositories/DeviceTokenRepository.swift`
- Modify: `ios/PickUpUCF/App/PickUpUCFApp.swift`
- Modify: `ios/PickUpUCF/Info.plist`
- Modify: `ios/project.yml` (Push capability note — enable in Xcode Signing & Capabilities)

**Interfaces:**
- Produces: `PushNotificationService.shared.registerIfAuthorized()`
- Produces: `DeviceTokenRepository.upsert(token: String) async throws`

- [ ] **Step 1: DeviceTokenRepository**

```swift
import Foundation
import Supabase

protocol DeviceTokenRepositoryProtocol {
    func upsert(token: String) async throws
    func delete(token: String) async throws
}

final class DeviceTokenRepository: DeviceTokenRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared) {
        self.client = client
    }

    func upsert(token: String) async throws {
        let userId = try await client.auth.session.user.id
        struct Row: Encodable {
            let userId: UUID
            let apnsToken: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case apnsToken = "apns_token"
            }
        }
        try await client.from("device_tokens")
            .upsert(Row(userId: userId, apnsToken: token))
            .execute()
    }

    func delete(token: String) async throws {
        try await client.from("device_tokens")
            .delete()
            .eq("apns_token", value: token)
            .execute()
    }
}
```

- [ ] **Step 2: PushNotificationService + AppDelegate**

`PushNotificationService.swift`:
```swift
import UserNotifications
import UIKit

@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    private let tokenRepository: DeviceTokenRepositoryProtocol

    init(tokenRepository: DeviceTokenRepositoryProtocol = DeviceTokenRepository()) {
        self.tokenRepository = tokenRepository
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            // Non-fatal; user can enable later in Settings
        }
    }

    func handleDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        try? await tokenRepository.upsert(token: token)
    }
}
```

`AppDelegate.swift`:
```swift
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushNotificationService.shared.handleDeviceToken(deviceToken) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let urlString = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlString) else { return }
        NotificationCenter.default.post(name: .pushDeepLink, object: url)
    }
}

extension Notification.Name {
    static let pushDeepLink = Notification.Name("pushDeepLink")
}
```

- [ ] **Step 3: Wire into PickUpUCFApp**

```swift
@main
struct PickUpUCFApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                // ... existing modifiers ...
                .onReceive(NotificationCenter.default.publisher(for: .pushDeepLink)) { note in
                    guard let url = note.object as? URL,
                          case .session(let id) = DeepLinkRouter.destination(from: url) else { return }
                    appState.queueSessionDeepLink(id: id)
                }
                .task {
                    // ... existing bootstrap ...
                    if appState.isAuthenticated {
                        await PushNotificationService.shared.requestAuthorizationAndRegister()
                    }
                }
        }
    }
}
```

Also call `requestAuthorizationAndRegister()` after successful sign-in in `AuthenticatedSessionCoordinator.bootstrap`.

- [ ] **Step 4: Info.plist background mode**

Add to `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

- [ ] **Step 5: Xcode capability**

Open Xcode → PickUpUCF target → Signing & Capabilities → **+ Capability** → Push Notifications.

Set Development Team in `project.yml` / Xcode if not set.

- [ ] **Step 6: Build verification**

```bash
cd ios && xcodegen generate && xcodebuild -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Expected: BUILD SUCCEEDED (push registration only works on device).

- [ ] **Step 7: Commit**

```bash
git add ios/PickUpUCF/Core/AppDelegate.swift ios/PickUpUCF/Core/PushNotificationService.swift \
  ios/PickUpUCF/Repositories/DeviceTokenRepository.swift ios/PickUpUCF/App/PickUpUCFApp.swift \
  ios/PickUpUCF/Info.plist
git commit -m "feat(ios): register APNs tokens and handle push deep links"
```

---

### Task 7: Attendance UI for hosts

**Files:**
- Create: `ios/PickUpUCF/Models/SessionParticipant.swift`
- Create: `ios/PickUpUCF/Repositories/AttendanceRepository.swift`
- Create: `ios/PickUpUCF/Features/SessionDetail/AttendanceSheet.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailViewModel.swift`
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailView.swift`

**Interfaces:**
- Produces: `AttendanceRepository.fetchJoinedParticipants(sessionId:) async throws -> [SessionParticipant]`
- Produces: `AttendanceRepository.submitAttendance(sessionId:attendedUserIds:) async throws`
- Produces: `SessionDetailViewModel.canSubmitAttendance: Bool`

- [ ] **Step 1: SessionParticipant model**

```swift
import Foundation

struct SessionParticipant: Identifiable, Decodable, Equatable {
    let userId: UUID
    let displayName: String
    let username: String?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case username
    }
}
```

- [ ] **Step 2: AttendanceRepository**

```swift
struct SubmitAttendanceParams: Encodable {
    let pSessionId: UUID
    let pAttendedUserIds: [UUID]
    enum CodingKeys: String, CodingKey {
        case pSessionId = "p_session_id"
        case pAttendedUserIds = "p_attended_user_ids"
    }
}

final class AttendanceRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient = SupabaseManager.shared) { self.client = client }

    func fetchJoinedParticipants(sessionId: UUID) async throws -> [SessionParticipant] {
        struct Row: Decodable {
            let userId: UUID
            let profile: SessionParticipant
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case profile = "profiles"
            }
        }
        let rows: [Row] = try await client
            .from("session_participants")
            .select("user_id, profiles!session_participants_user_id_fkey(user_id, display_name, username)")
            .eq("session_id", value: sessionId.uuidString)
            .eq("status", value: ParticipantStatus.joined.rawValue)
            .execute()
            .value
        return rows.map(\.profile)
    }

    func submitAttendance(sessionId: UUID, attendedUserIds: [UUID]) async throws {
        try await client.rpc(
            "submit_session_attendance",
            params: SubmitAttendanceParams(
                pSessionId: sessionId,
                pAttendedUserIds: attendedUserIds
            )
        ).execute()
    }
}
```

Adjust embed key to match Supabase FK naming after codegen test.

- [ ] **Step 3: AttendanceSheet UI**

Host sees toggles for each joined player (default all ON). Primary button "Submit attendance".

- [ ] **Step 4: SessionDetailViewModel additions**

```swift
var canSubmitAttendance: Bool {
    guard isHost, let s = session.value else { return false }
    let now = Date()
    return s.status != .cancelled
        && s.startsAt <= now
        && now <= s.endsAt.addingTimeInterval(86400)
}
```

- [ ] **Step 5: Show "Mark attendance" button in SessionDetailView**

When `viewModel.canSubmitAttendance`, show secondary button opening `AttendanceSheet`.

- [ ] **Step 6: Manual test flow**

1. Create session starting in 2 minutes (or backdate in local DB for test)
2. Join as second user
3. After start, host opens Mark attendance → submit
4. Verify `profiles.games_played` incremented in Supabase

- [ ] **Step 7: Commit**

```bash
git add ios/PickUpUCF/Models/SessionParticipant.swift \
  ios/PickUpUCF/Repositories/AttendanceRepository.swift \
  ios/PickUpUCF/Features/SessionDetail/
git commit -m "feat(ios): host attendance sheet and submit flow"
```

---

### Task 8: Profile reliability stats

**Files:**
- Modify: `ios/PickUpUCF/Models/Profile.swift`
- Modify: `ios/PickUpUCF/Repositories/ProfileRepository.swift`
- Modify: `ios/PickUpUCF/Features/Profile/ProfileView.swift`

- [ ] **Step 1: Extend Profile model**

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var username: String?
    var gamesPlayed: Int
    var showUpStreak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username
        case gamesPlayed = "games_played"
        case showUpStreak = "show_up_streak"
    }
}
```

- [ ] **Step 2: Update ProfileRepository select**

Ensure fetch includes `games_played, show_up_streak` columns.

- [ ] **Step 3: ProfileView stats row**

Below username, show:
- `\(profile.gamesPlayed) games played`
- `\(profile.showUpStreak) show-up streak`

Use existing typography/colors — functional, not polished UI.

- [ ] **Step 4: Commit**

```bash
git add ios/PickUpUCF/Models/Profile.swift ios/PickUpUCF/Repositories/ProfileRepository.swift \
  ios/PickUpUCF/Features/Profile/ProfileView.swift
git commit -m "feat(ios): show games played and show-up streak on profile"
```

---

### Task 9: Error mapping + README

**Files:**
- Modify: `ios/PickUpUCF/Core/AppErrorMapper.swift`
- Modify: `README.md`

- [ ] **Step 1: Map new RPC errors**

```swift
case "not_host": return "Only the host can mark attendance."
case "session_not_started": return "Attendance opens when the game starts."
case "attendance_window_closed": return "The attendance window has closed."
case "session_cancelled": return "This session was cancelled."
```

- [ ] **Step 2: README section — Push setup**

Document:
- Enable Push Notifications capability
- APNs key secrets for Edge Function
- pg_cron + scheduled send-push
- Sandbox vs production APNs URL

- [ ] **Step 3: Commit**

```bash
git add ios/PickUpUCF/Core/AppErrorMapper.swift README.md
git commit -m "docs: document push notifications and attendance setup"
```

---

## Manual Test Plan (end-to-end)

- [ ] Sign in on **physical device**, accept notification permission, confirm row in `device_tokens`
- [ ] Join session → receive 1h and 15m reminders (adjust session `starts_at` for faster test)
- [ ] Fill session → waitlist user gets promoted push when someone leaves
- [ ] Host cancels → participants receive cancel push
- [ ] Tap push → app opens session detail via deep link
- [ ] Host marks attendance → `games_played` / `show_up_streak` update correctly
- [ ] Session past `ends_at` → status becomes `completed` via cron

---

## Spec Coverage Check

| Spec requirement | Task |
|------------------|------|
| 1h + 15m reminders | Task 4 |
| Waitlist promoted push | Task 3 |
| Cancel push | Task 3 |
| Host attendance | Task 2, 7 |
| Profile stats | Task 2, 8 |
| Auto-complete sessions | Task 2, 4 |
| APNs delivery | Task 5, 6 |

## Execution Order

Tasks 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 (backend before iOS; push infra before attendance UI).

---

**Plan complete.** Saved to `docs/superpowers/plans/2026-07-18-core-loop-reliability.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — implement tasks in this session with checkpoints

Which approach do you want?
