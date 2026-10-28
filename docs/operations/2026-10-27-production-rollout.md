# Production rollout — October 27, 2026

The owner explicitly approved applying the ten reviewed migrations and deploying
the send-push fix in the linked [preflight packet](2026-10-27-backend-rollout-preflight.md).
Executed against production `dkvonsrdxqenozdkufwe`, around21:11–21:15 Eastern.
No merge, external invitation, review submission or new live fixture was included.

## Delivered and verified

- Before mutation, branch was clean; linked target, all protected snapshot hashes,
  ten migration hashes and approved worker hash matched. Remote history was still
  42 migrations/head20261022170532. Protected capture was about11 minutes old.
- `supabase db push --linked --yes` exited0 and applied exactly the ten files in
  the preflight, preserving their original versions. Remote history now has52
  migrations, all ten present, head **20261023232500**.
- All six created/replaced public function bodies match the final reviewed SQL
  by body MD5; security-definer/invoker modes match too. Fixed search paths remain.
  Raw block/suspension helpers exist in pickup_private as definers; public wrappers
  are scoped invokers. Authenticated wrapper execution remains; anonymous is denied.
- Application/private tables retain RLS. Deployed participant, message SELECT/
  INSERT and own-attendance SELECT predicates match the reviewed policies.
- Authenticated chat inserts permit session_id/user_id/body and deny id/created_at;
  anonymous table inserts are denied. Authenticated attendance SELECT remains,
  bounded by its own-user policy. Live Activity RPC is authenticated-only; direct
  client execution of the session guard remains denied.
- Dashboard recheck confirms only public/graphql_public exposed, pickup_private
  unchecked, extra search path public/extensions. No configuration was saved.
  Screenshot: `/tmp/pickup-api-exposure-post-rollout.jpg`.
- **send-push v19** is ACTIVE, deployed at21:12:55 Eastern. Downloaded source
  matches the approved worker after terminal-newline normalization; gateway JWT
  verification remains false and the dedicated dispatcher-secret guard remains.
  send-auth-email staysv23 and fetch-weather staysv12; their settings are unchanged.

## Short post-deployment observation

Through approximately21:15 Eastern, bounded logs for send-push showed v19 with
**three HTTP200 scheduled invocations** and **two HTTP401 negative probes**.
The probes used missing/incorrect authorization and did not trigger dispatch.
No warning/error Log events appeared in the checked window; observed runtime
events were Boot/Shutdown. One retiring v18 Shutdown was also visible.

Since worker deployment, cron recorded dispatch3/3, cleanup3/3, reminders1/1,
completion1/1 and weather1/1 successful runs, with no failed runs. All five jobs
remain active and outbox pending count is0. These are bounded server observations,
not sustained monitoring, APNs delivery, Live Activity display or device acceptance.

Security advisor still has no ERROR findings. Existing RLS-without-policy INFO,
authenticated definer-RPC WARN and leaked-password-protection WARN categories
remain. No grant, policy or provider setting was changed to silence notices;
see the [existing remediation links](2026-10-26-release-checkpoint.md).

Unchanged passing local SQL/Edge/iOS suites were not repeated. Deployment parity,
ACL/policy checks, real unauthorized HTTP probes and bounded live health checks
were performed instead. No production test data, message, report or account
mutation was manufactured. No secrets or credentials were printed or committed.

## Recovery and remaining gates

Private deployment logs are under
`/Users/nurlanmammadli/.local/share/pickup-ucf/recovery/2026-10-27-rollout-build6`.
The protected pre-change logical dumps, worker source, migration/cron metadata,
hashes and recovery limitations are described in the preflight. No restore was
performed. Do not reverse authorization hardening or restore old grants; use a
reviewed forward repair. Prior worker source is retained privately for scoped
function recovery with its existing configuration.

Build **1.0(6)**, source `2d4310d`, is Validated/Testing in the existing internal
group. Physical installation and acceptance against this newly deployed baseline
remain open, as do the full production role/API matrix, provider/notification/
Calendar/offline/account-transition/accessibility checks and physical iOS17 lane.
The October26 cancelled fixture must stay cancelled. Any new live fixture still
needs its exact draft approved and teardown verified before the usage cutoff.

Backup responders, private escalation and retention/RPO/RTO/platform recovery
decisions remain open before external expansion. No external Beta App Review,
public App Review or release was submitted.
