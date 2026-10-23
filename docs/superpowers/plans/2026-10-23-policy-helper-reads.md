# Policy helper read scope — October 23, 2026

## Contract and threat model

Authenticated callers need RLS checks of their own block relationships and
suspension state. Direct public helper RPCs must not reveal relationships between
two unrelated users or another user's moderation status. Trusted definer-owned
notification/moderation operations must still evaluate arbitrary actors/recipients.

Reproduce each disclosure with synthetic fixtures first. Preserve public function
names/signatures and existing own-subject RLS behavior. If reproduced, move raw
implementations to the existing unexposed pickup_private schema and retain
public invoker wrappers that scope authenticated caller arguments. Definer-owned
internal callers retain their trusted current_user context. Grant no table access.

pickup_private must remain absent from Data API exposed schemas. Local
supabase/config.toml exposes only public and graphql_public. Verify equivalent
production API configuration before any future deployment; this is a deployment
gate, not evidence that production configuration was checked by this change.

## Verification and disposition

- Separate red probes reproduced unrelated block-relationship and suspension
  disclosures. Logs: /tmp/pickup-helper-scope-red.log and
  /tmp/pickup-helper-suspension-red.log.
- Migration 20261023222000 moves the raw implementations, preserving their OIDs
  and ACLs, and adds public invoker wrappers with the same names/signatures.
  Caller-unrelated positive, negative and NULL guesses raise the same 42501
  helper_scope_denied error. Own-subject checks remain allowed.
- The private-schema design follows [Supabase's RLS helper guidance](https://supabase.com/docs/guides/database/postgres/row-level-security#use-security-definer-functions).
  Raw private functions retain authenticated EXECUTE for policy/invoker use; this
  is an API exposure boundary, not protection against direct SQL access by that
  role. Application users are not given database connections. Keep pickup_private
  outside REST/GraphQL exposure and do not grant clients arbitrary-SQL RPCs.
- Full candidate SQL/RLS suite passed with 34 phase success notices inside
  rollback, including own profile RLS, own pair checks in both orders, trusted
  arbitrary-actor checks and a nested definer invoked under authenticated role.
  Log: /tmp/pickup-helper-candidate-sql.log.
- Because this changes helpers on host/join paths, the isolated schema-only
  concurrency harness was rerun: four ordered host-action races, twelve
  cancellation/join races and six waitlist retries passed. New network-disabled
  tmpfs container was removed. Log: /tmp/pickup-helper-concurrency.log.
- Independent adversarial review found no actionable issue. git diff --check passed.
- Existing local DB migration head remains 20261005150000 and create_session is
  still absent there, confirming candidate changes did not persist.

This closes the reproduced public helper disclosures locally. No production
migration, push, merge, binary upload or device acceptance occurred. Before
future deployment verify production API schema exposure and review the complete
four-migration pending set in order.
