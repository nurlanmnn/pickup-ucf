# October 22 production rollout

Owner instruction: “push whatever we have, and whatever that needs to be deployed.”
Execution/verification completed October 22, 2026, approximately 1:11 PM America/New_York
(17:11 UTC). Application source: `b8349d27b580d15ef8333509343ab44bba1a369b`, pushed to
`origin/main` with remote SHA re-read. The final documentation commit follows that
source commit and does not change the deployed application/function code.

## Delivered

- Calendar write-only source, HTTPS auth/share source, recovery email correction,
  new-password completion and readiness records committed and pushed.
- Vercel production deployment `dpl_CyuEUpV5p5HaVJ39Ty9MWgsJs9jZ` is READY and aliased
  to https://pickup-ucf-privacy.vercel.app. Published privacy text now matches
  anonymized hosted-game retention and independent write-only Calendar exports.
- AASA is public at `/.well-known/apple-app-site-association`; origin and Apple CDN
  both return HTTP 200 and the exact source JSON. AASA uses the App ID verified from
  the previous signed archive: `AS53KCG63V.edu.ucf.pickup`.
- `/auth/reset-password`, `/auth/confirm` and `/session/<UUID>` return HTTP 200 without
  redirects. Auth fallback has no-store/no-referrer/noindex/CSP protections, no scripts
  and no credential forwarding. Privacy/terms/guidelines hashes match source.
- Hosted auth `site_url` is `https://pickup-ucf-privacy.vercel.app/auth/confirm` and
  `uri_allow_list` contains only that URL and the exact HTTPS reset route. Re-read
  confirms persistence; other auth options were preserved with a two-field PATCH.
- `send-auth-email` **v23** and `send-push` **v18** are ACTIVE. Downloaded deployed
  source exactly matches committed source. Gateway JWT verification is disabled
  because the email hook verifies its webhook signature and push verifies its
  dedicated cron credential. Public GET email rejects with 405; unsigned email
  POST and unauthorized push POST reject with 401. No test email or push was sent.

## Database rollout

All pending migrations were applied in reviewed dependency order using the linked
CLI so the original file versions are preserved:

1. `20261005140000_quiet_session_reminders`
2. `20261005150000_live_activity_lifecycle`
3. `20261022145737_input_content_boundaries`
4. `20261022150215_restrict_application_rpc_grants`
5. `20261022150858_serialize_session_leave`
6. `20261022152043_anonymize_hosted_games_on_deletion`
7. `20261022152456_secure_session_roster_reads`
8. `20261022154815_enforce_host_status_transitions`
9. `20261022155106_serialize_account_mutations_with_deletion`
10. `20261022170532_skip_anonymized_host_cleanup_recipient`

The last migration was added during preflight after a local regression reproduced
scheduled cleanup inserting a null recipient after host deletion. It skips only
that null recipient, retains cleanup for surviving players, and keeps API-role
execution closed. The deletion phase calls cleanup twice to verify retry behavior.
The full local candidate SQL/RLS suite passed inside rollback transactions.

Post-deployment migration history contains all ten versions; a new CLI dry run
reports the remote database up to date. SELECT-only metadata checks confirm:

- sessions.host_id is nullable and its foreign key uses ON DELETE SET NULL;
- the deployed cleanup function skips null recipients;
- live_activity_tokens has the expected lifecycle column;
- anon/authenticated cannot execute enqueue_notification or enqueue_session_reminders;
- authenticated create/delete RPC access is preserved;
- authenticated direct session inserts and participant mutations are denied.

The 15-minute reminder cron is gone; 1-hour reminders and push dispatch remain,
and minute-by-minute session cleanup is active. At 1:10 PM local, recent dispatch,
reminder and cleanup job runs reported success. Cron success is not APNs device
or email-provider acceptance.

The security advisor reports no ERROR-level findings. It still reports 24 intended
allowlisted authenticated SECURITY DEFINER functions, nine intentionally RLS-closed
internal tables without client policies, and disabled leaked-password protection.
No subscription or new paid service was enabled.

## Recovery and evidence

Before deployment, logical schema/data dumps, hosted auth configuration and previous
function sources were captured outside Git with a private directory/file mode and
SHA-256 manifest. Schema/data include public, auth and private receipt data as
appropriate. Hosted backup metadata reported WALG enabled, no PITR and no available
recovery timestamps. These logical snapshots are not restore-tested or a complete
platform backup. Never restore over production as a test.

A CLI dump dry run printed a temporary CLI database-login credential. Subsequent
CLI calls reinitialized that login; sensitive command/configuration output was
captured privately afterward. No credential was committed or added to these docs.

Evidence logs (local, no live user bodies/credentials in this record):

- `/tmp/pickup-deploy-sql-red.log` and `/tmp/pickup-deploy-sql-green.log`
- `/tmp/pickup-production-migrations.log` and `/tmp/pickup-production-parity.log`
- `/tmp/pickup-production-functions.log` and `/tmp/pickup-vercel-production.log`
- Existing unchanged app validation: 261/261 isolated simulator tests, 39/39 Edge
  Function tests and unsigned Release build/analyzer; see the secure-links plan.

Recovery should preserve anonymized games and close exposed internal RPC grants.
Use reviewed forward repairs for schema problems; do not reintroduce NOT NULL on
host_id or broad grants. Previous function/config snapshots are recovery material,
not permission to restore insecure custom-scheme auth routing. Vercel can be rolled
back to a retained deployment, but keep HTTPS association/fallback available for any
distributed HTTPS-link clients.

## Remaining release gates

This deployment retires old direct-write creation and custom-scheme password reset.
Older TestFlight builds are not an acceptable candidate for further testing. The
atomic/nullable-host/HTTPS-link iOS source still needs Associated Domains provisioning,
a fresh unique build number, signed archive provenance, validation and distribution.
Local app/widget metadata remains version 1.0/build 4; no new archive/upload occurred.

Physical iOS 17/current-iOS two-account acceptance remains open for chat recovery,
APNs ownership/delivery, deletion, Calendar permission/Settings behavior, HTTPS
association/password reset, accessibility and offline/relaunch flows. The paired
phone was unavailable during local discovery. Production ordinary/moderator/blocked/
deleted-user end-to-end acceptance, successful provider recovery mail/password change,
backup restore exercise, reviewer-account refresh, candidate metadata and Beta App
Review/external invitations also remain open. No user account was deleted, seeded,
or signed into as part of deployment verification.
