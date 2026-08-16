# PickUp UCF

Native iOS app for UCF students to discover and host pickup sports sessions.

## Stack

- **iOS:** SwiftUI, iOS 17+, Supabase Swift SDK
- **Backend:** Supabase (Postgres, Auth, Realtime, Edge Functions)
- **Email:** Brevo via `send-auth-email` Auth hook (signup verify + password reset only)

## Getting started

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. Install [Supabase CLI](https://supabase.com/docs/guides/cli) and run:

```bash
cd supabase
supabase link --project-ref YOUR_REF
supabase db push
supabase db seed   # if using seed.sql via config
```

Optional migrations (run `supabase db push`, then reload PostgREST schema under **Database → API**):

- `20260519200000_sessions_custom_sport_name.sql` — dedicated `custom_sport_name` on `sessions`
- `20260520120000_sessions_custom_coordinates.sql` — `custom_lat` / `custom_lng` for map-picked custom locations
- `20260523140000_skill_level_any.sql` — adds `any` to `skill_level` enum

3. Enable **Email + Password** and **Confirm email** in Authentication.
4. Deploy the email hook:

```bash
supabase secrets set BREVO_API_KEY=... BREVO_SENDER_EMAIL=... BREVO_SENDER_NAME="PickUp UCF"
supabase functions deploy send-auth-email
```

Register the function URL under **Authentication → Hooks → Send Email**.

5. Enable **pg_cron** (Database → Extensions) on hosted Supabase, then push migrations. This schedules:

- `pickup-complete-expired-sessions` — every 15 minutes
- `pickup-reminder-1h` / `pickup-reminder-15m` — every 5 minutes

Verify with:

```sql
SELECT jobid, schedule, command FROM cron.job WHERE command LIKE '%pickup-%';
```

6. Deploy push delivery — see [Push notifications](#push-notifications) below.

**Edge Function tests:**

```bash
cd supabase/functions/send-push && deno test --allow-env --allow-net
```

### 2. iOS

```bash
cd ios
cp Config.xcconfig.example Config.xcconfig
# Edit Config.xcconfig with SUPABASE_URL and SUPABASE_ANON_KEY

./xcodegen generate   # or: brew install xcodegen && xcodegen generate
open PickUpUCF.xcodeproj
```

Build and run in Xcode. Use a `@knights.ucf.edu` or `@ucf.edu` account.

### Push notifications

Push delivery requires a **physical iPhone** (simulators do not receive APNs). Attendance and session lifecycle depend on the same backend cron jobs.

#### Apple Developer + Xcode

1. In [Apple Developer](https://developer.apple.com/account/resources/authkeys/list), create an **APNs Auth Key** (`.p8`). Note the **Key ID** and your **Team ID**.
2. Open `PickUpUCF.xcodeproj` → **PickUpUCF** target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
3. Set your **Development Team** if not already configured in `ios/project.yml` / Xcode.
4. Build to a physical device, sign in, and accept the notification permission prompt.

After sign-in, confirm a row exists in `device_tokens` for your user (`apns_token` populated).

#### Supabase secrets + deploy

Set Edge Function secrets (do not commit real keys):

```bash
supabase secrets set \
  APNS_KEY_ID=YOUR_KEY_ID \
  APNS_TEAM_ID=YOUR_TEAM_ID \
  APNS_BUNDLE_ID=edu.ucf.pickup \
  APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----" \
  APNS_ENV=sandbox \
  CRON_SECRET=$(openssl rand -hex 32)

supabase functions deploy send-push
```

| Secret | Purpose |
|--------|---------|
| `APNS_KEY_ID` | Key ID from the `.p8` auth key |
| `APNS_TEAM_ID` | Apple Developer Team ID |
| `APNS_BUNDLE_ID` | App bundle ID (`edu.ucf.pickup`) |
| `APNS_PRIVATE_KEY` | Full PEM contents of the `.p8` file |
| `APNS_ENV` | `sandbox` for Debug/dev builds; `production` for TestFlight/App Store |
| `CRON_SECRET` | Bearer token for scheduled `send-push` invocations |

**Sandbox vs production APNs:** `send-push` uses `https://api.sandbox.push.apple.com` when `APNS_ENV=sandbox`, and `https://api.push.apple.com` when `APNS_ENV=production`. Debug builds on a device use sandbox tokens; match `APNS_ENV` to the build you are testing.

#### Schedule outbox delivery

The `send-push` function drains `notification_outbox` rows where `sent_at IS NULL`.

In Supabase Dashboard → **Edge Functions → send-push → Cron**, schedule **every 1 minute** with header:

```http
Authorization: Bearer <CRON_SECRET>
```

Alternatively, invoke via pg_cron HTTP webhook to `/functions/v1/send-push` with the same header.

Manual smoke test:

```bash
curl -X POST "$SUPABASE_URL/functions/v1/send-push" \
  -H "Authorization: Bearer $CRON_SECRET"
```

#### Attendance (host RPC)

Hosts mark attendance via `submit_session_attendance` after the game starts and within 24 hours of `ends_at`. The iOS app surfaces user-friendly errors for RPC failures (`not_host`, `session_not_started`, `attendance_window_closed`, `session_cancelled`).

#### Manual device checklist

- [ ] Sign in on a physical device → permission granted → row in `device_tokens`
- [ ] Join a session → receive 1h and 15m reminder pushes (adjust `starts_at` for faster testing)
- [ ] Fill session → waitlisted user gets promoted push when someone leaves
- [ ] Host cancels → participants receive cancel push
- [ ] Tap push → app opens session detail via `pickupucf://session/{id}`
- [ ] Host marks attendance → `games_played` / `show_up_streak` update on profile
- [ ] Session past `ends_at` → status becomes `completed` via pg_cron

### Running tests

**SQL (local Supabase):**

```bash
cd supabase
supabase db reset && supabase db push
psql "$(supabase status -o env | grep DATABASE_URL | cut -d= -f2-)" -f tests/run_all.sql
```

**iOS unit tests:**

```bash
cd ios
xcodegen generate
xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16'
```

If the iPhone 16 simulator is unavailable, try `name=iPhone 15` or `-destination 'generic/platform=iOS Simulator'`.

## Project structure

```
ios/PickUpUCF/     SwiftUI app + DesignSystem
supabase/          Migrations, seed, Edge Functions
```

## License

MIT
