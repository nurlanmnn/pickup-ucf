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

5. Deploy push delivery (after APNs credentials are ready):

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

Schedule **Edge Functions → send-push → Cron** every 1 minute with header `Authorization: Bearer <CRON_SECRET>` (or invoke via pg_cron webhook). Do not commit real APNs keys.

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
