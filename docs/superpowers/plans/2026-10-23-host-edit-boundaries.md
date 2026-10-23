# Host edit boundaries — October 23, 2026

## Problem and contract

BETA-13's numeric/edit audit found that authenticated hosts could bypass atomic
creation's numeric contract with direct sessions UPDATE. A synthetic local
regression reproduced an accepted capacity of 1; the app requires 2–50. Schedule
and coordinate fields had the same missing server boundary.

Migration `20261023215028_enforce_host_edit_boundaries.sql` extends the existing
invoker status guard, retaining its lifecycle restrictions and server-owned
open/full reconciliation. For changed client field groups it now enforces:

- capacity 2–50 (existing table checks still prevent capacity below player_count);
- finite timestamps, duration 15–300 minutes, future start within seven days;
- latitude -90…90, longitude -180…180, and a complete pin when changing into
  custom-location mode. PostgreSQL NaN/infinity values are rejected by the bounds.

Checks run only for authenticated client writes. Definer-owned RPCs, moderation
and maintenance retain their existing behavior. Unchanged legacy values do not
strand a notes edit or cancellation. No table rewrite, stored-data cleanup, new
grant, role, external integration or iOS binary change is involved.

Build 5 omits optional nulls in edit patches, so a named venue may retain valid
custom-coordinate fields from a prior selection. This migration preserves that
representation; it does not enforce create's exactly-one-location representation.
Sport/custom-name synchronization and complete read minimization remain separate
audit work. Do not label all of BETA-13 complete from this fix.

## Verification

- Initial direct test hit the older local baseline (no atomic create RPC); the
  reproduction was rerun using the candidate harness's pending-migration pattern.
  Local migration history was read first, and pending files were applied only
  inside the rollback transaction.
- Before the fix, the regression failed with `host patch accepted: capacity=1`.
- Focused numeric/schedule/coordinate cases passed after the first guard change.
- A second regression reproduced a named-venue → custom-location transition
  without a pin even though both coordinate values were unchanged NULL. The
  location-group guard now checks venue/label changes as well; that case passes.
- Complete `python3 supabase/tests/run_candidate_suite.py` passed with **31 phase
  success notices**, including new `phase_o_host_edit_boundaries.sql`.
- Inclusive capacity/duration/coordinate/schedule limits, valid venue switching,
  status reconciliation, internal legacy-value preservation, notes edits and
  cancellation are covered. Existing status/role/account/deletion tests passed.
- `git diff --check` passed. Local migration head remained `20261005150000` after
  testing and the atomic creation RPC remained absent from that older baseline,
  confirming candidate changes did not persist.

Logs: `/tmp/pickup-host-edit-red.log`,
`/tmp/pickup-host-location-mode-red.log`, `/tmp/pickup-host-edit-green.log`,
`/tmp/pickup-host-edit-candidate-sql.log`. These use synthetic local fixtures only.
Five-axis review found no new privilege grant, unbounded query or data migration;
the added checks are constant-time comparisons on the row already being edited.

## Delivery boundary

This is **local source and rollback-test evidence only**. The new migration has
not been deployed; the previously verified production catalog still has the
older status guard. Current TestFlight build 5 is unchanged. No upload, push,
merge, external invitation or review submission was performed. Deployment needs
its separate authorization and subsequent compatible-candidate device edit tests.
