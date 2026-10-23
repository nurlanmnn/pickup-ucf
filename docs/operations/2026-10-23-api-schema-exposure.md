# Production API schema exposure — October 23, 2026

Read-only inspection of production project `dkvonsrdxqenozdkufwe` confirmed:

- Data API settings expose **public** and **graphql_public** only (2 of 3 schemas).
  The existing **pickup_private** schema is visibly unchecked.
- Extra search path is **public, extensions**; pickup_private is absent.
- The database has no installed `pg_graphql` extension or GraphQL resolver.
  `graphql_public.graphql(query := '{ __typename }')` returns the existing stub
  error `pg_graphql extension is not enabled.`

The Supabase connector lacks a project API-configuration read tool. SQL catalog
inspection returned no relevant role/database setting overrides, which alone is
insufficient to establish API configuration. The authoritative exposed-schema
selection was read in the already-authenticated Chrome dashboard at
`/dashboard/project/dkvonsrdxqenozdkufwe/integrations/data_api/settings`.
Opening the selector and inspecting its checkmarks did not change a selection or
save configuration. No sign-in, credentials, settings, rows, grants or schema were
changed. The in-app browser lacked a dashboard session; existing Chrome access
worked without entering credentials.

This resolves the current pre-deployment configuration check for moving raw
policy helpers into pickup_private. That migration remains undeployed. Recheck
configuration at the actual authorized deployment, especially if GraphQL is later
enabled or exposed/search-path schemas change. Existing public helper behavior
still reflects deployed source until the pending migration is applied.

This check does not establish production acceptance of the nine pending October
23 migrations, account/role API matrix, physical device/provider behavior or
external-review readiness. No deployment or API configuration change was made.
