# Phase B — Discovery & Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. **Prerequisite:** Phase A gate passed ([master roadmap](./2026-07-18-pre-ui-master-roadmap.md)).

**Goal:** UCF sport list, onboarding, profile preferences, and Discover filters — fully tested before Phase C.

**Spec:** [2026-07-18-phase-b-discovery-identity-design.md](../specs/2026-07-18-phase-b-discovery-identity-design.md)

## Global Constraints

Same as Phase A master roadmap. Enum migrations must use `ALTER TYPE ... ADD VALUE` (one value per statement in Postgres).

---

### Task B1: Expand sport_type enum (database)

**Files:**
- Create: `supabase/migrations/20260718160000_expand_sports.sql`
- Create: `supabase/tests/phase_b_sports.sql`
- Modify: `supabase/tests/run_all.sql` — add `\ir phase_b_sports.sql`

- [ ] **Step 1: Migration**

```sql
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'pickleball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'flag_football';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'spikeball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'softball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'floor_hockey';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'dodgeball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'racquetball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'badminton';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'cornhole';
```

- [ ] **Step 2: SQL test** — `phase_b_sports.sql`

```sql
DO $$
BEGIN
  PERFORM 'pickleball'::sport_type;
  PERFORM 'flag_football'::sport_type;
  PERFORM 'cornhole'::sport_type;
  RAISE NOTICE 'phase_b_sports: enum values OK';
END $$;
```

- [ ] **Step 3: Run**

```bash
cd supabase && supabase db push && psql "$DATABASE_URL" -f tests/phase_b_sports.sql
```

- [ ] **Step 4: Commit** — `feat(db): expand sport_type for UCF RWC sports`

---

### Task B2: iOS SportType + icons

**Files:**
- Modify: `ios/PickUpUCF/Models/SportType.swift`
- Modify: `ios/PickUpUCFTests/SportTypeTests.swift`

- [ ] **Step 1: Add cases** matching DB enum exactly (snake_case raw values).

- [ ] **Step 2: displayName** — e.g. `flag_football` → `"Flag Football"`.

- [ ] **Step 3: systemImage** — use SF Symbols (`figure.racquet`, `figure.american.football`, etc.) or `sportscourt.fill` fallback.

- [ ] **Step 4: Unit tests**

```swift
import XCTest
@testable import PickUpUCF

final class SportTypeTests: XCTestCase {
    func testPickleballDisplayName() {
        XCTAssertEqual(SportType.pickleball.displayName, "Pickleball")
    }

    func testAllCasesMatchDatabaseCount() {
        // 6 original + 9 new = 15
        XCTAssertEqual(SportType.allCases.count, 15)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(SportType.flagFootball)
        let decoded = try JSONDecoder().decode(SportType.self, from: data)
        XCTAssertEqual(decoded, .flagFootball)
    }
}
```

- [ ] **Step 5: Run** — `xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16'`

- [ ] **Step 6: Commit** — `feat(ios): add UCF sport types and tests`

---

### Task B3: Onboarding database column

**Files:**
- Create: `supabase/migrations/20260718161000_profile_onboarding.sql`
- Create: `supabase/tests/phase_b_onboarding.sql`

- [ ] **Step 1: Migration**

```sql
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed_at timestamptz;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_preferred_sports sport_type[],
  p_skill_level skill_level
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_preferred_sports IS NULL OR array_length(p_preferred_sports, 1) IS NULL THEN
    RAISE EXCEPTION 'preferred_sports_required';
  END IF;

  UPDATE public.profiles
  SET
    preferred_sports = p_preferred_sports,
    skill_level = p_skill_level,
    onboarding_completed_at = now(),
    updated_at = now()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(sport_type[], skill_level) TO authenticated;
```

- [ ] **Step 2: SQL test** — verify function exists and rejects empty sports array.

- [ ] **Step 3: Commit** — `feat(db): onboarding completion RPC`

---

### Task B4: Onboarding UI flow

**Files:**
- Create: `ios/PickUpUCF/Features/Onboarding/OnboardingView.swift`
- Create: `ios/PickUpUCF/Features/Onboarding/OnboardingViewModel.swift`
- Modify: `ios/PickUpUCF/Models/Profile.swift`
- Modify: `ios/PickUpUCF/Repositories/ProfileRepository.swift`
- Modify: `ios/PickUpUCF/App/RootView.swift`

**Interfaces:**
- Produces: `ProfileRepository.fetchCurrentProfile()` includes `onboardingCompletedAt`, `preferredSports`, `skillLevel`
- Produces: `ProfileRepository.completeOnboarding(sports:skillLevel:) async throws`

- [ ] **Step 1: Extend Profile model**

```swift
var preferredSports: [SportType]
var skillLevel: SkillLevel?
var onboardingCompletedAt: Date?
```

- [ ] **Step 2: OnboardingView** — two steps: sport multi-select chips, skill picker, "Get started" button.

- [ ] **Step 3: RootView routing**

```swift
if appState.isAuthenticated {
    if appState.needsOnboarding {
        OnboardingView()
    } else {
        MainTabView()
    }
}
```

Add `AppState.needsOnboarding` set during bootstrap from profile fetch.

- [ ] **Step 4: Unit test** — `OnboardingViewModelTests`: cannot submit with zero sports selected.

- [ ] **Step 5: Manual test** — new account → onboarding → relaunch skips onboarding.

- [ ] **Step 6: Commit** — `feat(ios): first-run onboarding for sports and skill`

---

### Task B5: Profile shows preferences

**Files:**
- Modify: `ios/PickUpUCF/Features/Profile/ProfileView.swift`
- Modify: `ios/PickUpUCF/Features/Profile/ProfileSettingsView.swift` (optional edit preferred sports)

- [ ] **Step 1: Display preferred sports as comma-separated list under stats.**

- [ ] **Step 2: Settings → "Edit sports" sheet reuses onboarding sport picker (no skill required on edit).**

- [ ] **Step 3: Snapshot/manual verify on simulator.**

- [ ] **Step 4: Commit** — `feat(ios): show and edit preferred sports on profile`

---

### Task B6: Discover filters (time + skill)

**Files:**
- Create: `ios/PickUpUCF/Models/DiscoverTimeWindow.swift`
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverViewModel.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverView.swift`
- Create: `ios/PickUpUCFTests/DiscoverFilterTests.swift`

**Interfaces:**
- Produces: `SessionRepository.fetchUpcoming(sport:timeWindow:skillLevel:) async throws -> [PickupSession]`

- [ ] **Step 1: DiscoverTimeWindow enum**

```swift
enum DiscoverTimeWindow: String, CaseIterable, Identifiable {
    case next48h
    case today
    case thisWeekend

    var id: String { rawValue }
    var displayName: String { /* ... */ }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        // today: same day as now
        // thisWeekend: next Sat/Sun in America/New_York
        // next48h: existing 48h window
    }
}
```

- [ ] **Step 2: Repository** — extend query with optional `.eq("skill_level", …)` server-side; apply time window via `starts_at` bounds.

- [ ] **Step 3: DiscoverView** — add filter row below sport chips (menu or segmented for time + skill).

- [ ] **Step 4: Unit tests** — `DiscoverFilterTests.testTodayExcludesTomorrow`, `testWeekendIncludesSaturday`.

- [ ] **Step 5: SQL test** — `phase_b_discover.sql` inserts sessions at various times, asserts query helper returns correct ids.

- [ ] **Step 6: Run full test suite.**

- [ ] **Step 7: Commit** — `feat: Discover time and skill filters with tests`

---

### Task B7: Share link hardening

**Files:**
- Create: `ios/PickUpUCFTests/SessionShareLinkTests.swift`
- Modify: `ios/PickUpUCF/Core/DeepLinkRouter.swift` (only if cold-start gap found)

- [ ] **Step 1: Unit tests**

```swift
final class SessionShareLinkTests: XCTestCase {
    func testURLFormat() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(
            SessionShareLink.url(for: id).absoluteString,
            "pickupucf://session/00000000-0000-0000-0000-000000000001"
        )
    }

    func testDeepLinkRouterParsesSessionURL() {
        let url = SessionShareLink.url(for: UUID())
        if case .session = DeepLinkRouter.destination(from: url) {
            // pass
        } else {
            XCTFail("Expected session destination")
        }
    }
}
```

- [ ] **Step 2: Manual test** — share to Notes, tap link, app opens session (authenticated + unauthenticated queue).

- [ ] **Step 3: Commit** — `test(ios): SessionShareLink and deep link coverage`

---

## Phase B Gate Checklist

Run before starting Phase C:

```bash
# Automated
cd supabase && supabase db reset && supabase db push && psql "$DATABASE_URL" -f tests/run_all.sql
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16'
```

- [ ] All SQL tests pass
- [ ] All iOS unit tests pass
- [ ] Onboarding shows once for new user
- [ ] Pickleball session create + discover filter works
- [ ] Share deep link opens session from cold start

**Phase B complete.** Proceed to [Phase C plan](./2026-07-18-phase-c-platform-features.md).
