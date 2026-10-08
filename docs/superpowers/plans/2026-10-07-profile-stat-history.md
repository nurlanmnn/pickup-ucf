# Clickable profile statistics

Games opens paginated, host-confirmed attendance history with links to session
details. Streak opens the same recorded attendance with the current streak and
an explanation that a missed game resets it; do not infer exact streak membership
from calendar dates because counters are updated when hosts submit attendance.
Sports currently counts preferred sports. Preserve that meaning unless the user
requests a played-sports metric; link to the preferred-sport list/editor.

Use signed-in user filtering and existing RLS, no schema or production writes.
Page attendance by marked_at descending, session_id as tie-breaker, 20 records at
a time. Missing/inaccessible session details must not break the page or expose
restricted data. Include loading, empty, error/retry, and load-more states.
Scope: ProfileView, new history model/repository/view-model/view, focused tests,
and generated Xcode project membership. Verify pagination/failure/reset behavior,
iOS tests/build, and simulator navigation. Rollback by restoring profile links
and removing the added history files/project membership. No commit/push requested.

## Implementation and verification — 2026-10-07

- All three profile stat tiles are navigation links with chevrons and accessible
  hints/identifiers. User confirmed Sports keeps its preferred-sports meaning;
  it opens the existing editor with current preferences selected.
- Games and Streak open paginated own-user attendance history, with session-detail
  navigation, loading/empty/error states, pull to refresh, and safe missing-detail
  rendering. Streak shows current count plus recent confirmed attendance; it does
  not claim to reconstruct past streaks or show missed-game history.
- New tests cover paging offsets, refresh replacement, failed pagination/refresh
  retry, and overlapping-page deduplication. Missing types failed before
  implementation; all five final history tests pass.
- Initial full suite passed 188/188. Final suite ran 190 tests; one existing
  ActivityKit runtime dismissal assertion intermittently failed. It passed in
  isolation alongside the history tests. An intermediate Discover preference
  test failure also passed in isolation and the final unattended full run.
- Authenticated simulator checks verified Games loads the existing attended game,
  its row opens the completed session, Streak shows count/history, and Sports
  shows the four saved selections. No preferences or production records changed.
- Accessibility XXXL summary wraps and the history row remains in the accessibility
  tree. Visual inspection of the scrolled large-text row stopped when the Mac
  locked; that remaining check belongs to candidate-device verification.
- Restored simulator text size to Large. No backend migration/deployment required.
- Query follows https://supabase.com/docs/reference/swift/select and uses a small
  selected payload plus existing attendance/session RLS. No credentials added.
