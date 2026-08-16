# Phase B — Discovery & Identity Design

**Date:** 2026-07-18  
**Prerequisite:** Phase A gate passed  
**Goal:** UCF-relevant sports, first-run onboarding, and Discover filters so students find the right games.

## Scope

### In scope
- Expand `sport_type` enum with UCF RWC popular sports
- Onboarding: preferred sports + default skill level
- Profile fields: `preferred_sports`, `skill_level` (schema exists, wire up)
- Discover filters: time window, skill level (sport chips remain)
- Share link verification tests (already built; harden copy + deep link handling)

### Out of scope
- UI visual redesign
- Push / attendance (Phase A)
- Recurring / weather / moderation (Phase C)

## Sports to add

Based on UCF RWC 2025–26 intramurals:

| Enum value | Display name |
|------------|--------------|
| `pickleball` | Pickleball |
| `flag_football` | Flag Football |
| `spikeball` | Spikeball |
| `softball` | Softball |
| `floor_hockey` | Floor Hockey |
| `dodgeball` | Dodgeball |
| `racquetball` | Racquetball |
| `badminton` | Badminton |
| `cornhole` | Cornhole |

Keep existing: basketball, soccer, tennis, volleyball, football, other.

**Note:** `football` = tackle/standard football label; `flag_football` is separate (UCF IM primary format).

## Onboarding

Add `onboarding_completed_at timestamptz` to `profiles` (null = show onboarding).

Flow after email verified + profile ensured:
1. Pick 1+ preferred sports (chips)
2. Pick default skill level
3. Save → set `onboarding_completed_at = now()`

Skip onboarding on subsequent launches when column is set.

## Discover filters

Extend `fetchUpcoming` with optional:
- `timeWindow`: `.today` | `.weekend` | `.next48h` (default, current behavior)
- `skillLevel`: optional filter

Client-side search text remains (location, host, notes).

## Share (hardening only)

- Unit test `SessionShareLink.message(for:)` format
- Ensure `pickupucf://session/{id}` resolves when app cold-starts from Messages

## Testing requirements

- SQL: each new sport inserts into `sessions`; onboarding column updates; filtered queries return correct rows
- iOS: onboarding validator, filter date math, sport icons/display names
- Manual: full onboarding once; filters on device
