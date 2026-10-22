# BETA-05 — Calendar write-only access

Source baseline: `c18ef78`, pushed and verified on origin/main on October 22.
Work branch: `codex/calendar-write-only`. Deployment target is iOS 17.

## Contract and scope

Request `requestWriteOnlyAccessToEvents` only when exporting, and only while
permission is undetermined. Already allowed full/write-only access can save;
denied users get a Settings action, restricted users get policy guidance.
Never read existing events, including after a previous full-access grant.

An export is an independent saved copy. Local legacy event identifiers become
opaque successful-export receipts, never proof an event still exists. Retain
receipts even when permission is revoked or Calendar entries are deleted.
Use “Previously added” wording. An explicit “Add another copy” confirmation
permits replacement after manual deletion and warns about duplicates. Failed saves
must retain the old receipt; successful saves without an identifier still count.
Cancellation and edits cannot automatically update/remove write-only copies;
explain management in Calendar before saving and after cancellation.
Account transition receipt cleanup remains unchanged; reinstall/sign-out can lose
local duplicate detection. No Calendar data is uploaded to the backend.

## Steps

1. Demonstrate regressions for write-only receipt retention, permission denial
   and repeated successful exports without readable identifiers.
2. Narrow the EventKit adapter to create/save/write-only permission; test initial
   allow/deny, restriction, Settings recovery, duplicate/explicit replacement,
   save failure, missing destination, cancellation and event formatting.
3. Replace permission usage strings in source plist and XcodeGen; update the
   detail card, cancellation copy, permission recovery and local privacy source.
4. Run the isolated simulator suite, unsigned Release build/analyzer, plist and
   diff review. Keep real EventKit prompt/Settings acceptance separate.

## Sources

- https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui

Apple documents that write-only access cannot read even the app's own events.

## Device gate (open)

On iOS 17 and current iOS: fresh allow/deny, restricted policy, Settings recovery,
legacy full-access upgrade, no calendar destination, event/calendar deletion,
manual duplicate confirmation, game edit/cancel and Accessibility XXXL/VoiceOver.
No production deployment, privacy-site publish or archive upload is part of this
source change. App Store privacy answers need review against the unchanged local
only Calendar flow. Rollback: revert this focused source change; existing local
receipt keys remain compatible with the old app.

## Local evidence

- Regression run against the previous implementation failed for write-only receipt
  loss, repeated denied permission requests and successful saves with no readable
  identifier (`/tmp/pickup-calendar-red-fixed.xcresult`).
- Final signed iPhone 17 Pro simulator suite: **255/255 passed**, 0 skipped/failures
  (`/tmp/pickup-calendar-suite-final.xcresult`). Calendar tests use a synthetic
  EventKit adapter; they do not exercise real permission prompts or Calendar saves.
- Built Debug plist: write-only key present, full-access key absent, version
  **1.0 (4)** preserved. No XcodeGen regeneration or project-ID changes needed.
- Review removed every full-access request/event lookup/calendar removal call from
  the app, including foreground/background cancellation notification handlers.
  Notification and Live Activity cleanup remain intact.
- Public privacy-site publishing, App Store privacy review, iOS 17/current-iOS
  Calendar acceptance and physical-device accessibility remain open.
- Unsigned generic-device Release build and static analyzer passed
  (`/tmp/pickup-calendar-release.log`). The Release bundle also contains only the
  write-only Calendar usage key and preserves version **1.0 (4)**.
- `git diff --check` passed. This follow-up remains uncommitted locally; the
  previously requested snapshot is verified on origin/main at `c18ef78`.
