# PickUp UCF Moderation Response

## Service targets

- Imminent harm, credible threats, or doxxing: acknowledge within 24 hours and escalate immediately when reviewed.
- Harassment, hate, sexual content, impersonation, unsafe conduct, or repeated abuse: acknowledge within 72 hours.
- Spam and lower-risk rule violations: review within 72 hours when capacity permits.

These are operating targets, not emergency-response guarantees. The in-app rules direct immediate danger to 911 or UCF Police.

## Review sequence

1. Confirm the report target and preserve the original target identifiers and timestamps; do not copy private content into general logs.
2. Check related reports, blocks, account status, and the minimum content needed to decide.
3. Dismiss false/unsupported reports or record a warning, content removal, or suspension with a bounded reason.
4. Escalate credible imminent threats, child-safety concerns, or illegal conduct to the accountable owner and appropriate authority.
5. Resolve the report and retain the audit record. Do not reveal reporter identity or private moderator notes to the reported user.

## Access and provisioning

Moderator membership is stored in `public.moderator_accounts`. Authenticated clients cannot read or write that table. Provisioning or revocation requires a separately authorized production operation using a privileged administrative path and a named owner. Never grant moderator access by changing client metadata or a user-controlled profile field.

## Deployment and verification record

The master readiness checklist records deployment of migration `20260916090000_ugc_safety_and_moderation.sql` on September 16, 2026 and production moderator provisioning on September 30. These are historical deployment records, not a fresh production audit. Do not treat a passing local SQL suite as proof of candidate-build moderation behavior.

Before external testing, run the production role/access matrix and synthetic report/action flow in [external-beta-operations.md](external-beta-operations.md), verify the candidate's moderator and ordinary-user screens, and assign backup support/moderation coverage. New migrations or function revisions require their own deployment evidence. Deployment remains deferred for the October 14 local work.
