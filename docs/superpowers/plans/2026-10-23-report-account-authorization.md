# Report caller authorization — October 23, 2026

## Contract

Deleting an account must prevent its unexpired JWT from submitting new content.
The moderation-report RPC must verify the current confirmed UCF account before
looking up targets or inserting reports. Preserve typed reporting, duplicate and
rate checks, moderator access and retained audit records. Never mutate a real
account: reproduce only with synthetic rollback fixtures.

Source audit found that submit_moderation_report checks auth.uid and suspension,
but reporter_id intentionally has no auth FK (audit retention). A deleted account
may therefore pass both checks. This requires a red reproduction before fixing.

## Local fix and evidence

The synthetic deleted-account reproduction failed with
`invalid current account submitted moderation report`. Migration
`20261023223500` adds the authoritative `is_ucf_email()` check before target
lookup/content submission, using the existing not_authenticated error and client
sign-in recovery message. The original signature/ACLs, duplicate/rate checks,
moderation behavior and retained audit records remain unchanged.

Full candidate SQL/RLS passed with 35 phase notices inside rollback. Phase S
rejects deleted, unconfirmed, non-school (despite stale school claims), and
missing principals; confirms active reporting and no denied inserts. Independent
review found no actionable issue. No Swift/Edge changes justify repeating their
unchanged passing suites. Logs: /tmp/pickup-report-caller-red.log and
/tmp/pickup-report-caller-candidate-sql.log. git diff --check passed.

Local source only; migration is undeployed. Owner authorized feature-branch
GitHub pushes, not deployment, merge or a new binary upload.
