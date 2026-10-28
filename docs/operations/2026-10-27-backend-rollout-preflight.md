# Backend rollout preflight — October 27, 2026

Status: prepared for owner review. No migration applied or function deployed.
Approval of build6 upload, encryption declaration and internal assignment does
not authorize this separate production change.

## Exact proposed change

Target: existing production project `dkvonsrdxqenozdkufwe`.

Apply only these ten reviewed files, in this order:

1. `20261023215028_enforce_host_edit_boundaries.sql`
2. `20261023215505_preserve_waitlist_retry_priority.sql`
3. `20261023221000_restrict_participant_reads.sql`
4. `20261023222000_scope_public_policy_helpers.sql`
5. `20261023223500_authorize_current_report_callers.sql`
6. `20261023224500_require_chat_session_visibility.sql`
7. `20261023225500_restrict_message_insert_columns.sql`
8. `20261023230500_scope_attendance_ledger_reads.sql`
9. `20261023231500_serialize_report_submissions.sql`
10. `20261023232500_serialize_live_activity_registration.sql`

Then deploy only `send-push`, using the source already reviewed in `11c61f7`.
Proposed worker file SHA-256:
`57fdabe92d16c5982414ae1eb9fbd9e04aef659daf72b2cece9c3571d07d5dbb`.
It keeps failed outbox rows pending and continues later rows. Preserve existing
gateway JWT verification=false and the worker's own dispatcher-secret check.
Do not change secrets, cron schedules, providers or any other function.

The SQL tightens host edits, participant/helper/history reads, chat writes and
moderation caller authorization, while serializing waitlist/report/Live Activity
races. Existing local evidence includes38 candidate SQL/RLS phases and isolated
concurrency checks. Reviewed compatibility preserves build5 cancellation,
named-venue handling and own attendance history; candidate build6 includes the
session-edit client correction. These are local compatibility results; exact
production/API/device acceptance remains separate.

## Fresh read-only preflight

- Linked CLI project identity matches the intended production project.
- Remote history contains42 migrations, head `20261022170532`.
- CLI2.99.0 `db push --linked --dry-run` lists exactly the ten files above,
  in order. It did not apply migrations. No seed, custom-role or include-all
  option is part of the proposal.
- Downloaded active send-push v18 source matches the recorded October22 rollout
  baseline, apart from terminal-newline normalization. Current proposed source
  exactly matches reviewed `11c61f7`; no new worker diff was introduced.
- Dashboard schema checkmarks: public and graphql_public exposed; pickup_private
  unchecked. Extra search path: public/extensions. SQL's exposed-schema setting
  was null and was not treated as authoritative. No setting was saved.
- `pg_graphql` is not installed. The private schema allows authenticated usage
  for intended trusted policy paths and denies anonymous usage; that is distinct
  from being Data API exposed.
- Around21:02 Eastern, all five scheduled jobs were active. The prior15 minutes
  showed dispatch15/15, cleanup15/15, one-hour reminders3/3, completion1/1 and
  weather1/1 successful runs, with no failed runs. Outbox pending count was0.
  These counts do not prove function execution outcomes or APNs/device delivery.
- Security advisor has no ERROR findings. Existing intentional RLS-without-policy
  and authenticated definer-RPC notices, plus disabled leaked-password protection,
  remain in their established scope. No grants/policies/settings were changed to
  silence notices. See the [checkpoint remediation references](2026-10-26-release-checkpoint.md).

Read-only exposure screenshot: `/tmp/pickup-api-exposure-20261027.jpg`.

## Protected recovery material

Captured before this proposed rollout, around21:00 Eastern, outside Git:
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-27-preflight-build6`.

- Logical schema and data dumps explicitly include public, auth and pickup_private.
  Both commands exited0. Schema includes27 managed Auth table definitions;
  data has44 COPY blocks and a dump-completion marker.
- Deployed worker source/metadata, migration version/name history, cron definitions
  and capture/dry-run logs are retained privately.
- SHA-256/byte-length checks pass for all9 artifacts and all10 proposed migrations.
  Directory0700/files0600 verified. The temporary dry-run script, which can contain
  a CLI login credential, was removed; no credential/output was printed or committed.
- Manifest SHA-256:
  `954e8e315167cbd08bf63570cfdcb8496565089ab7f91db794847d3b09c18d47`.

This is a sequential logical capture, not a shared cross-file snapshot or a
restore-tested current backup. Earlier isolated logical restore/replay evidence
is recorded separately. Hosted Auth/platform recovery, Vault/environment-secret
recovery, retention and agreed RPO/RTO remain open. No database was restored or
existing local database modified. Never expose these raw materials in Git/chat.

## Execution after specific owner approval

1. Check five-hour usage and retain enough room for verification/cleanup before
   the85%-used stop. Recheck branch cleanliness, target identity, migration/worker
   hashes and remote head. If approval is delayed or state changes, refresh the
   relevant preflight/recovery capture rather than assuming this snapshot is current.
2. Apply the exact linked migration set, preserving file versions. CLI command:
   `supabase db push --linked --yes`, with stdout/stderr kept private. Do not add
   seeds, roles, include-all, unrelated source or any database reset.
3. Confirm all10 versions and expected head `20261023232500`; inspect actual
   function/grant/RLS/catalog state and API schema exposure. Stop on a failed
   migration and record applied history before deciding a repair; never fake
   history entries or blindly continue to the next stage.
4. Deploy only the reviewed worker:
   `supabase functions deploy send-push --project-ref dkvonsrdxqenozdkufwe --no-verify-jwt`.
   CLI help confirms these flags. Capture/re-read the deployed source/version and
   authorization setting; keep auth-email/weather/configuration unchanged.
5. Verify benign unauthorized worker requests still reject before dispatch,
   inspect subsequent scheduler/function/outbox health and record the result.
   Do not manufacture a notification, fixture, report or account action merely
   to make a health check pass. Queue/cron success is not device delivery proof.
6. Keep the role/API acceptance matrix and physical iOS17/current-iOS checks open
   until their scoped evidence exists on exact TestFlight build6. Controlled live
   fixture/provider/deletion actions still need their separate authorization.

Stop advancement for unintended access, client authorization regression, broken
membership invariants, scheduler failure or new sustained dispatch failures.
Worker recovery can re-deploy the privately captured prior source with its existing
authorization/configuration. Schema repair must be reviewed and forward-only:
do not restore older broad grants, revoke intended RPC access or reverse host
anonymization. This packet does not authorize a production database restore.

Nurlan is the confirmed primary operator/release owner. No backup responder is
assigned; backup/escalation readiness remains open before external expansion.
Merge, privacy-site deployment, external invitations and Apple review submission
are excluded from this rollout proposal.
