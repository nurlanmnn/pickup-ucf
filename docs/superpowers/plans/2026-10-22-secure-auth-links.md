# BETA-07 — Secure auth links and recovery

Baseline: `c18ef78`, branch `codex/calendar-write-only`. Preserve the uncommitted
BETA-05 work and synthetic test isolation. No commit, push, deployment, website
publication, archive or upload is authorized in this continuation.

## Findings and contract

The app currently generates custom-scheme reset/share links. The existing public
privacy host is `pickup-ucf-privacy.vercel.app` (Settings source); its
`/.well-known/apple-app-site-association` returned HTTP 404 on October 22.
There is no Associated Domains entitlement. The owner requested the free Vercel option. Local preparation uses that existing
host; its production deployment and signing capability still require authorization.

The send-auth-email recovery branch used redirect_to itself as the email link,
which omits provider verification entirely. The fallback instead put a hash on
the site URL where the Swift PKCE callback expects a code. The resolved SDK uses
PKCE by default, sends a challenge on reset request, and exchanges the returned
code with a verifier retained on the requesting install. Keep that binding.
Do not accept access/refresh tokens or token hashes from incoming app URLs.

A successful reset callback currently bootstraps ordinary authenticated UI without
a new-password form. Fix that locally; only show recovery UI after successful
provider code exchange, and clear its state across account transitions.

## Ordered work

1. Preserve/review Calendar source against its plan without repeating unchanged tests.
2. Regress and fix recovery-email provider verification and exact redirect allowlist.
3. Reject malformed/ambiguous app callbacks before SDK mutation, retaining PKCE.
4. Add new-password completion after successful callback with validation and retry.
5. Once host is resolved, prepare AASA with the signed App ID prefix and bundle ID,
   exact auth/share paths, matching entitlement/XcodeGen configuration, HTTPS URL
   generation and NSUserActivity handling. Provide a credential-free web fallback.
6. Run focused regressions, full isolated suite for changed auth behavior, Release
   build/analyzer, static secrets/callback review and diff check. No live auth calls.

## External release gates

- Confirm stable HTTPS host and App ID prefix from signed provisioning provenance;
  source team ID alone is not proof of the App ID prefix.
- Authorize publishing AASA/fallback and matching privacy copy, enabling Associated
  Domains on the App ID, updating exact hosted auth redirect allowlists and deploying
  the email hook. Coordinate legacy reset requests/builds explicitly.
- Check AASA origin/CDN returns JSON over HTTPS without redirects, signed entitlements
  and install-time association. Never route recovery credentials back to a custom
  scheme from the fallback page. Do not place analytics or third-party scripts there.
- On iOS 17/current physical devices verify installed/uninstalled, signed in/out,
  cold/warm launch, fresh/expired/replayed link, wrong install/no verifier, repeated
  reset request, provider delivery, password update/relogin, relaunch during recovery,
  revoked/deleted account, malformed URLs, blocked/deleted game and accessibility.
- The paired iPhone 17 was listed as unavailable by devicectl on October 22. No
  device, APNs, email-provider or App Store acceptance is claimed.
- Nine recorded pending migrations, exposed production grants, notification parity,
  candidate build number/archive provenance and two-account matrix remain open in
  the launch-gates plan; a fresh read-only migration/grant audit reconfirmed these blockers below.

## Sources

- [Supabase password/PKCE flow](https://supabase.com/docs/guides/auth/passwords)
- [Send Email Hook payload](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook)
- [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- Resolved supabase-swift Sources/Auth/AuthClient.swift: resetPasswordForEmail,
  handlePKCEFlow and exchangeCodeForSession; Defaults.swift: defaultFlowType.

## Prepared source and rollout sequence

- HTTPS `/auth/reset-password`, `/auth/confirm` and `/session/<UUID>` use the existing
  Vercel host. Source entitlements and XcodeGen agree. The previous signed TF-06
  archive confirms `application-identifier = AS53KCG63V.edu.ucf.pickup`; AASA uses it.
  This does not prove the next profile includes Associated Domains.
- The app receives browsing-web NSUserActivity callbacks and also validates URL
  deliveries. Auth callbacks require one nonempty PKCE code on an exact HTTPS
  path, no credentials/port/fragment or extra parameters. Custom-scheme auth is
  rejected at both routing and repository boundaries. Legacy session links remain
  for existing notifications, whose authorization still comes from backend reads.
- Provider verification links are generated from trusted SUPABASE_URL, with a fixed
  HTTPS redirect, encoded query parameters and escaped HTML. Missing hashes or
  mismatched redirects fail before sending. No arbitrary redirect or site_url fallback.
  Wrong-install/expired/replayed codes remain provider errors; no token-import fallback.
- Root UI presents the new-password form after successful exchange/bootstrap. It
  validates password/confirmation, retains fields on failure, prevents duplicate
  submits, clears password fields after success and clears recovery context on
  account changes. Recovery context is in memory; force-quitting during recovery
  requires requesting a fresh link from the app. Verify that workflow on devices.
- Static fallback pages contain no scripts, token rendering, network auth exchange
  or custom-scheme forwarding. Auth routes have no-store/noindex/no-referrer/CSP
  headers. Session fallback describes invitation-based TestFlight access honestly;
  no public App Store/TestFlight URL has been invented.

For an authorized rollout: publish the prepared `privacy-site/` root (including
its vercel.json and .well-known file), verify origin/CDN association and fallback
responses, enable Associated Domains/sign a unique candidate, configure the exact
HTTPS auth redirect URLs and deploy send-auth-email together with candidate access.
Retire legacy reset-link clients first: the new hook intentionally rejects their
custom-scheme redirect. Existing signup OTP handling is unchanged. Do not distribute
this source as a working recovery candidate before that configuration is complete.
The nine backend migrations need their own reviewed compatibility/backup gate.
Rollback: retain the HTTPS association/fallback for distributed clients; repair the
HTTPS hook/configuration forward or pause recovery distribution. Do not restore
sensitive custom-scheme callbacks as a security rollback.

## Read-only production refresh — October 22

The migration list still includes atomic creation `20261021155014` and omits both
October 5 migrations and all seven October 22 migrations. SELECT-only privilege
checks confirm both anon and authenticated can execute `enqueue_notification`
and `enqueue_session_reminders`. No RPC was invoked and no rows/configuration
were changed. These remain external-release blockers, independent of local auth
or Calendar results. Device discovery lists the paired iPhone 17 as unavailable.

## Local verification and review

- Calendar diff reviewed across receipts, denied/restricted/no-calendar errors,
  duplicate confirmation, cancellation notifications and privacy copy; no new
  launch blocker found. Its prior 255-test evidence was not rerun for reassurance.
- Signed isolated iPhone 17 Pro simulator suite: **261/261 passed**, zero failures
  (`/tmp/pickup-auth-links-verified.xcresult`, `/tmp/pickup-auth-links-verified.log`).
  The full suite was warranted by changed auth/navigation behavior. This is synthetic
  app/SDK state coverage, not mail-provider/Universal Link association acceptance.
- Before implementation, callback-boundary regressions failed with eight malformed
  callbacks accepted (`/tmp/pickup-auth-boundary-red.xcresult`). Three signed-hook
  recovery tests also failed against the old email implementation
  (`/tmp/pickup-auth-email-red.log`). Final Edge Function suite: **39/39 passed**,
  provider fetch mocked; no mail sent (`/tmp/pickup-auth-deno-final.log`).
- An intermediate iOS run failed only because Calendar notes still expected the old
  custom-scheme share URL. Updated that assertion to the intended HTTPS URL; the
  final suite above includes the correction and repository/legacy-session checks.
- Unsigned generic-device Release build and analyzer passed
  (`/tmp/pickup-auth-links-release.log`), with only the unused AppIntents metadata
  notice. Both Debug/Release plists retain **1.0 (4)** and only the write-only
  Calendar usage key. This is not signed archive/distribution evidence.
- AASA JSON/App ID, Vercel rewrite destinations, script-free fallback content,
  entitlement plist, Deno formatting and `git diff --check` passed. No XcodeGen
  regeneration/dependency change was needed; source scheme test isolation remains.
- Reviewed code exchange guards, exact trusted origin/redirect, HTML escaping,
  no-token-import behavior, account-bound recovery UI, and backend authorization
  for game navigation. Optional polish was deferred. All changes remain local.


## Deployment authorization and preflight — October 22

The owner subsequently authorized pushing current source and deploying required
changes. That supersedes the earlier authorization limits above for Git, database,
Edge Functions, Vercel and hosted auth configuration. App Store submission and
external invitations remain separate release actions.

Deployment review reproduced a scheduled-cleanup failure after anonymized host
retention: enqueue_finished_session_cleanup attempted a NULL user_id insert.
Migration 20261022170532 skips the null host recipient and preserves surviving
players; the account-deletion SQL phase now invokes cleanup twice after deletion.
The regression failed with a NOT NULL violation before the fix and the full local
candidate SQL/RLS suite then passed inside rollback transactions
(/tmp/pickup-deploy-sql-red.log, /tmp/pickup-deploy-sql-green.log).

Before deployment, restricted local schema/data recovery snapshots were captured
outside Git (including application, auth and private receipt data). Hosted backup
metadata reported WALG enabled, no PITR, and no available recovery timestamps.
These local logical snapshots have not been restore-tested and are not a complete
platform backup. CLI login was reinitialized after a dry run printed a temporary
login credential; subsequent credential/configuration output is captured privately.

The hardened backend requires the atomic/nullable-host client. Legacy direct-write
creation and custom-scheme password-reset requests are intentionally retired by
this rollout. Do not widen testing with old builds. Candidate signing, a unique
build number, distribution and the physical-device matrix remain release gates.


## Deployment result

The authorized rollout completed; see the
[production record](../../operations/2026-10-22-production-rollout.md). All ten
migrations, both functions (email v23/push v18), Vercel AASA/fallback/privacy source,
and exact hosted HTTPS auth fields are deployed. Origin and Apple CDN return matching
AASA JSON, deployed function sources match, unauthorized requests reject safely,
and cron cleanup has succeeded. Source b8349d2 is verified on main. Signed iOS
candidate/device/provider acceptance and App Store actions remain separate/open.
