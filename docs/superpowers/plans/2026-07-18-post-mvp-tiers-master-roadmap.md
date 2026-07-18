# Post-MVP Tiers — Master Roadmap

> **For agentic workers:** Implement **one tier at a time**. Do **not** start Tier 2 until Tier 1 gate passes. Do **not** start Tier 3 until Tier 2 gate passes. Within each tier, use `superpowers:subagent-driven-development` or `superpowers:executing-plans` — **one task per session** to stay within context limits.

**Goal:** Ship Tier 1 (core polish), Tier 2 (trust & retention), and Tier 3 (campus delight) with tested incremental delivery.

**Design spec:** [2026-07-18-post-mvp-tiers-design.md](../specs/2026-07-18-post-mvp-tiers-design.md)

---

## Phase Overview

| Tier | Focus | Plan doc | Features |
|------|--------|----------|----------|
| **1** | Core polish | [2026-07-18-tier-1-core-polish.md](./2026-07-18-tier-1-core-polish.md) | My sports filter, roster/waitlist, blocked list, notification prefs, host pushes |
| **2** | Trust & retention | [2026-07-18-tier-2-trust-retention.md](./2026-07-18-tier-2-trust-retention.md) | Host profile, run it back, chat push, Apple Calendar |
| **3** | Campus delight | [2026-07-18-tier-3-campus-delight.md](./2026-07-18-tier-3-campus-delight.md) | Discover map, venue filter, Live Activity, empty-state nudges |

**Already shipped (no tier work):** Auth, discover/join/waitlist, chat, attendance, recurring, weather, block/report, onboarding (sports only), session skill level.

---

## How to Run a Tier (new chat session)

1. Open the tier plan doc (e.g. `tier-1-core-polish.md`).
2. Tell the agent: *"Execute Tier 1 Task T1-X using executing-plans. Run tests after each task. Stop at tier gate."*
3. After tier gate passes, commit (if requested) and start next tier in a **fresh chat**.

**Do not** implement multiple tiers in one session unless each task is tiny and tests stay green.

---

## Testing Strategy (all tiers)

### Layer 1 — SQL (`supabase/tests/`)

After every backend task:

```bash
cd supabase
supabase db push          # remote or local after reset
psql "$DATABASE_URL" -f tests/run_all.sql
```

Add new files to `run_all.sql` when each tier starts:
- Tier 1: `\ir phase_d_tier1.sql`
- Tier 2: `\ir phase_d_tier2.sql`
- Tier 3: (mostly iOS; optional `phase_d_tier3.sql` if server filter added)

### Layer 2 — iOS unit tests

```bash
cd ios
xcodegen generate
xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

### Layer 3 — Edge Functions

Only if Tier 2 chat trigger affects shared helpers — existing `send-push` tests must still pass:

```bash
cd supabase/functions/send-push && deno test --allow-env --allow-net
```

### Layer 4 — Manual (physical iPhone for push)

Each tier gate lists device checks. Tier 1 and 2 are push-heavy.

---

## Tier 1 Gate — Core Polish

**Implement:** [Tier 1 plan](./2026-07-18-tier-1-core-polish.md) (Tasks T1-1 through T1-8)

**Automated must-pass:**
- [ ] `psql … -f supabase/tests/run_all.sql` — roster RPC, waitlist position, notification prefs, host join outbox
- [ ] `xcodebuild test` — MySportsFilterTests, SessionRosterTests, BlockedUsersTests, NotificationPreferencesTests

**Manual must-pass:**
- [ ] Discover opens on "My sports" when profile has preferred sports
- [ ] Session detail shows player names + waitlist position
- [ ] Settings → Blocked users → unblock restores host in Discover
- [ ] Disable reminders in settings → no 1h/15m push
- [ ] Host receives push when player joins

**Do not proceed to Tier 2 until all boxes checked.**

---

## Tier 2 Gate — Trust & Retention

**Prerequisite:** Tier 1 gate passed.

**Implement:** [Tier 2 plan](./2026-07-18-tier-2-trust-retention.md)

**Automated must-pass:**
- [ ] SQL: chat message inserts outbox row for participants
- [ ] iOS: CreateSessionPrefillTests, CalendarEventBuilderTests (or equivalent pure helpers)
- [ ] `xcodebuild test` green

**Manual must-pass:**
- [ ] Tap host → mini profile shows stats
- [ ] "Run it back" on completed session opens create form pre-filled
- [ ] Chat message → push to other participant; tap opens chat
- [ ] Add to Calendar creates event with correct time

**Do not proceed to Tier 3 until all boxes checked.**

---

## Tier 3 Gate — Campus Delight

**Prerequisite:** Tier 2 gate passed.

**Implement:** [Tier 3 plan](./2026-07-18-tier-3-campus-delight.md)

**Automated must-pass:**
- [ ] iOS: DiscoverMapAnnotationTests, VenueFilterTests, EmptyStateCTATests
- [ ] `xcodebuild test` green

**Manual must-pass:**
- [ ] Discover map shows pins for sessions with coordinates
- [ ] Venue chip filters list (and map)
- [ ] Live Activity appears for next joined game (device iOS 16.1+)
- [ ] Empty Discover shows "Host [sport]" CTA → create sheet pre-filled

---

## Document Index

| Document | Purpose |
|----------|---------|
| [specs/2026-07-18-post-mvp-tiers-design.md](../specs/2026-07-18-post-mvp-tiers-design.md) | Full design |
| [plans/2026-07-18-tier-1-core-polish.md](./2026-07-18-tier-1-core-polish.md) | Tier 1 tasks |
| [plans/2026-07-18-tier-2-trust-retention.md](./2026-07-18-tier-2-trust-retention.md) | Tier 2 tasks |
| [plans/2026-07-18-tier-3-campus-delight.md](./2026-07-18-tier-3-campus-delight.md) | Tier 3 tasks |

---

## Suggested Commit Strategy

One commit per task step (matching Phase A–C style), e.g.:
- `feat(db): notification preferences and should_notify helper`
- `feat(ios): Discover my sports default filter`
- `feat(ios): session roster and waitlist position`

Tier gate = all tasks done + tests green, then optional merge commit or PR per tier.
