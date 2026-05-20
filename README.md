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

Optional: migration `20260519200000_sessions_custom_sport_name.sql` adds a dedicated `custom_sport_name` column on `sessions`. The app works with or without it; if you apply it, reload the PostgREST schema (**Database → API → Reload schema**) so the API cache matches Postgres.

3. Enable **Email + Password** and **Confirm email** in Authentication.
4. Deploy the email hook:

```bash
supabase secrets set BREVO_API_KEY=... BREVO_SENDER_EMAIL=... BREVO_SENDER_NAME="PickUp UCF"
supabase functions deploy send-auth-email
```

Register the function URL under **Authentication → Hooks → Send Email**.

### 2. iOS

```bash
cd ios
cp Config.xcconfig.example Config.xcconfig
# Edit Config.xcconfig with SUPABASE_URL and SUPABASE_ANON_KEY

./xcodegen generate   # or: brew install xcodegen && xcodegen generate
open PickUpUCF.xcodeproj
```

Build and run in Xcode. Use a `@knights.ucf.edu` or `@ucf.edu` account.

## Project structure

```
ios/PickUpUCF/     SwiftUI app + DesignSystem
supabase/          Migrations, seed, Edge Functions
```

## License

MIT
