# Player count clarity

Replace the capacity dots, which testers mistook for swipe/page controls, with a
static people icon and explicit `1/8 players` text. Apply through the shared
CapacityIndicator to session cards, session hero metadata, and roster headers.
Preserve sport/hero colors, Dynamic Type, and a single VoiceOver description.

Implementation: update CapacityIndicator.swift and its callers in SessionCard.swift
and SessionDetailView.swift. Remove obsolete dot sizing/scaling configuration.
Verify all callers, compile the iOS app, and inspect normal and accessibility-size
rendering. No backend, migrations, or dependency changes. Rollback: restore these
three source files' prior capacity presentation.

## Completed — 2026-10-06

- Shared component now uses `person.2.fill` and explicit `X/Y players` text.
- All session-card, hero, and roster callers use the new icon color configuration.
- Debug simulator build succeeded on iPhone 17 Pro / iOS 26.3.
- Runtime visual checks passed for Discover cards, hero, and roster at normal text
  size; the roster count remains fully readable at Accessibility XXXL.
- Accessibility tree exposes one `1 of 8 player spots filled` element for each
  standalone count, with the decorative icon excluded.
- Restored simulator text size to Large. `git diff --check` passed.
- Physical-device verification remains part of the next candidate-build gate.
