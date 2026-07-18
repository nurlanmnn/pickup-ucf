# Pre-UI Master Roadmap

> **For agentic workers:** Implement **one phase at a time**. Do **not** start Phase B until Phase A gate passes. Do **not** start Phase C until Phase B gate passes. Within each phase, use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Complete Tier 1–3 product features (excluding visual UI polish) with tested, incremental delivery.

**Why one roadmap, three phases:** Features have dependencies (push before reminders matter; profile fields before onboarding; sports enum before filters). A single ordered roadmap prevents rushed parallel work and broken integrations.

---

## Phase Overview

| Phase | Focus | Plan doc | Tier coverage |
|-------|--------|----------|---------------|
| **A** | Core loop reliability | [2026-07-18-core-loop-reliability.md](./2026-07-18-core-loop-reliability.md) | Tier 1 (push), Tier 2 (attendance, reminders) |
| **B** | Discovery & identity | [2026-07-18-phase-b-discovery-identity.md](./2026-07-18-phase-b-discovery-identity.md) | Tier 1 (sports, onboarding, share hardening), Tier 2 (Discover filters) |
| **C** | Platform features | [2026-07-18-phase-c-platform-features.md](./2026-07-18-phase-c-platform-features.md) | Tier 3 (recurring, weather, moderation) |

**Already shipped (no phase work):** Session share link (`SessionShareLink` + Share button in session detail).

---

## Testing Strategy (all phases)

No phase is “done” without passing its gate. Do not skip automated tests to move faster.

### Layer 1 — SQL integration tests (`supabase/tests/`)

Run after every backend task:

```bash
cd supabase
supabase db reset   # local only — wipes data
supabase db push
psql "$DATABASE_URL" -f tests/run_all.sql
```

Tests use plain SQL with `ASSERT`-style checks (`DO $$ ... RAISE EXCEPTION ... $$`). No pgTAP required.

### Layer 2 — iOS unit tests (`PickUpUCFTests` target)

Run after every iOS task:

```bash
cd ios
xcodegen generate
xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Test pure logic: filters, sport display names, onboarding validation, recurrence parsing, block list filtering.

### Layer 3 — Edge Function smoke tests

```bash
cd supabase/functions/send-push && deno test --allow-env --allow-net
cd supabase/functions/fetch-weather && deno test --allow-env --allow-net
```

### Layer 4 — Manual device checklist

Push notifications and APNs **require a physical iPhone**. Each phase gate includes a short manual checklist.

---

## Task 0 (do once, before Phase A): Testing foundation

**Files:**
- Create: `supabase/tests/run_all.sql`, `supabase/tests/helpers.sql`
- Create: `ios/PickUpUCFTests/` (initial empty test + one sample)
- Modify: `ios/project.yml` (add test target)
- Modify: `README.md` (how to run tests)

- [ ] **Step 1: Add SQL test runner**

`supabase/tests/helpers.sql` — shared functions to create test users/sessions with service role patterns.

`supabase/tests/run_all.sql`:
```sql
\ir helpers.sql
\ir phase_a_notifications.sql
-- Phase B/C files added when those phases start
```

- [ ] **Step 2: Add iOS test target to `project.yml`**

```yaml
targets:
  PickUpUCFTests:
    type: bundle.unit-test
    platform: iOS
    sources: [PickUpUCFTests]
    dependencies:
      - target: PickUpUCF
```

- [ ] **Step 3: Sample test** — `PickUpUCFTests/SportTypeTests.swift` asserting `SportType.basketball.displayName == "Basketball"`.

- [ ] **Step 4: Verify both runners work**

```bash
cd supabase && supabase db reset && supabase db push && psql "$(supabase status -o env | grep DATABASE_URL | cut -d= -f2-)" -f tests/run_all.sql
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16'
```

- [ ] **Step 5: Commit** — `chore: add SQL and iOS test infrastructure`

---

## Phase A Gate — Core Loop Reliability

**Prerequisite:** Task 0 complete.

**Implement:** Full [Phase A plan](./2026-07-18-core-loop-reliability.md) (Tasks 1–9).

**Automated must-pass:**
- [ ] `psql … -f supabase/tests/run_all.sql` — includes notification dedupe, waitlist promote, attendance RPC, auto-complete
- [ ] `xcodebuild test` — DeviceTokenRepository encoding tests (mock), AppErrorMapper new cases
- [ ] `deno test` for `send-push` (mock APNs with stub fetch)

**Manual must-pass (physical device):**
- [ ] Push permission → token row in `device_tokens`
- [ ] Reminder push received (use session starting in 16 min for 15m test)
- [ ] Waitlist promotion push on leave
- [ ] Cancel push to participants
- [ ] Tap push → opens session detail
- [ ] Host marks attendance → profile stats update

**Do not proceed to Phase B until all boxes checked.**

---

## Phase B Gate — Discovery & Identity

**Prerequisite:** Phase A gate passed.

**Implement:** Full [Phase B plan](./2026-07-18-phase-b-discovery-identity.md).

**Automated must-pass:**
- [ ] SQL tests: sport enum values insertable, onboarding flag, filtered session queries
- [ ] iOS tests: `DiscoverFilterTests`, `OnboardingValidatorTests`, `SportTypeTests` (expanded sports)
- [ ] Share link message format test (existing `SessionShareLink`)

**Manual must-pass:**
- [ ] New user sees onboarding once; skip blocked on second launch
- [ ] Preferred sports persist on profile
- [ ] Discover filters (today / skill / sport) return expected subsets
- [ ] Create session with pickleball + flag football works
- [ ] Share sheet copies valid deep link

**Do not proceed to Phase C until all boxes checked.**

---

## Phase C Gate — Platform Features

**Prerequisite:** Phase B gate passed.

**Implement:** Full [Phase C plan](./2026-07-18-phase-c-platform-features.md).

**Automated must-pass:**
- [ ] SQL tests: recurrence spawn, block hides sessions, report row inserted
- [ ] iOS tests: recurrence UI state, weather snapshot decode, blocked host filter
- [ ] `deno test` for `fetch-weather`

**Manual must-pass:**
- [ ] Weekly recurring session creates next occurrence after first completes
- [ ] Weather line appears on outdoor session detail
- [ ] Block user → their hosted sessions hidden from Discover
- [ ] Report session submits without crash

---

## Execution Options

After reviewing this roadmap:

1. **Subagent-driven (recommended)** — one task per subagent, run tests after each task, phase gate before next phase
2. **Inline** — implement in-session with checkpoint after each task + phase gate

## Document Index

| Document | Purpose |
|----------|---------|
| [specs/2026-07-18-core-loop-reliability-design.md](../specs/2026-07-18-core-loop-reliability-design.md) | Phase A design |
| [specs/2026-07-18-phase-b-discovery-identity-design.md](../specs/2026-07-18-phase-b-discovery-identity-design.md) | Phase B design |
| [specs/2026-07-18-phase-c-platform-features-design.md](../specs/2026-07-18-phase-c-platform-features-design.md) | Phase C design |
| [plans/2026-07-18-core-loop-reliability.md](./2026-07-18-core-loop-reliability.md) | Phase A tasks |
| [plans/2026-07-18-phase-b-discovery-identity.md](./2026-07-18-phase-b-discovery-identity.md) | Phase B tasks |
| [plans/2026-07-18-phase-c-platform-features.md](./2026-07-18-phase-c-platform-features.md) | Phase C tasks |
