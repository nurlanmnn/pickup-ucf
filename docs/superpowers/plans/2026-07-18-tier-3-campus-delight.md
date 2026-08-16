# Tier 3 — Campus Delight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:executing-plans`. **Prerequisite:** Tier 2 gate passed ([master roadmap](./2026-07-18-post-mvp-tiers-master-roadmap.md)).

**Goal:** Discover map view, venue filter, Live Activity countdown, empty-state host nudges — fully tested.

**Spec:** [2026-07-18-post-mvp-tiers-design.md](../specs/2026-07-18-post-mvp-tiers-design.md)

**Note:** Tier 3 is mostly iOS. No required backend migrations unless you add server-side `venue_id` filter (optional optimization in T3-2).

---

## Task order

| Task | Summary | Backend | iOS |
|------|---------|---------|-----|
| T3-1 | Venue filter | optional | ✓ |
| T3-2 | Discover map view | | ✓ |
| T3-3 | Empty-state host nudges | | ✓ |
| T3-4 | Live Activity for next game | | ✓ |

---

### Task T3-1: Venue filter (iOS)

**Files:**
- Modify: `ios/PickUpUCF/Repositories/SessionRepository.swift` — optional `venueId: UUID?` on `fetchUpcoming` (client filter acceptable v1)
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverViewModel.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverView.swift`
- Create: `ios/PickUpUCFTests/VenueFilterTests.swift`

- [ ] **Step 1:** Load venues via existing `fetchVenues()` once.

- [ ] **Step 2:** Horizontal scroll venue chips: "All venues" + each official venue name.

- [ ] **Step 3:** Filter sessions where `session.venueId == selected` (custom-location sessions excluded when venue filter active — document in UI hint).

- [ ] **Step 4:** Unit test — 3 sessions, 1 at IM Fields → venue filter returns 1.

- [ ] **Step 5: Commit** — `feat(ios): Discover venue filter`

**Optional server optimization:** add `.eq("venue_id", value:)` in repository when `venueId != nil`.

---

### Task T3-2: Discover map view (iOS)

**Files:**
- Create: `ios/PickUpUCF/Features/Discover/DiscoverMapView.swift`
- Create: `ios/PickUpUCF/Models/SessionMapAnnotation.swift`
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverView.swift` — Picker List/Map
- Create: `ios/PickUpUCFTests/SessionMapAnnotationTests.swift`

- [ ] **Step 1:** `SessionMapAnnotation` — id, coordinate from `venue` or `customLat/customLng`; skip if nil.

- [ ] **Step 2:** Map with `Annotation` per session; cluster not required v1.

- [ ] **Step 3:** Tap annotation → append session id to navigation path (same as list).

- [ ] **Step 4:** Default map region centered on UCF (~28.6024, -81.2001) with reasonable span.

- [ ] **Step 5:** Unit test — coordinate resolution from venue vs custom.

- [ ] **Step 6: Commit** — `feat(ios): Discover map view`

---

### Task T3-3: Empty-state host nudges (iOS)

**Files:**
- Modify: `ios/PickUpUCF/Features/Discover/DiscoverView.swift`
- Modify: `ios/PickUpUCF/Features/Main/MainTabView.swift` — support opening create with prefill from Discover
- Reuse: `CreateSessionPrefill` from Tier 2 (sport only minimum)

- [ ] **Step 1:** When `discoverList` empty and not loading, show EmptyStateView with CTA.

- [ ] **Step 2:** CTA title from active filter — e.g. "Host basketball game" if basketball chip selected; "Host a game" if my sports / all.

- [ ] **Step 3:** CTA opens create sheet with `CreateSessionPrefill(sport: selectedSport)`.

- [ ] **Step 4:** Unit test — CTA title helper for filter combinations.

- [ ] **Step 5: Commit** — `feat(ios): empty Discover host nudge`

---

### Task T3-4: Live Activity (iOS)

**Files:**
- Create: `ios/PickUpUCF/LiveActivity/GameLiveActivityAttributes.swift`
- Create: `ios/PickUpUCF/LiveActivity/GameLiveActivityManager.swift`
- Create: `ios/PickUpUCFWidget/` widget extension OR in-app ActivityKit target (see Apple docs)
- Modify: `ios/project.yml` — widget extension target if needed
- Modify: `ios/PickUpUCF/Features/SessionDetail/SessionDetailViewModel.swift` — start activity on join
- Modify: `ios/PickUpUCF/Features/MyGames/MyGamesViewModel.swift` — refresh activity on load

- [ ] **Step 1:** Define `ActivityAttributes` with sport name, location, startsAt.

- [ ] **Step 2:** Start activity when user joins session starting within 24h; end after startsAt + 15m.

- [ ] **Step 3:** Guard with `@available(iOS 16.2, *)` / ActivityKit availability.

- [ ] **Step 4:** Only one active Live Activity per user (replace if joining another game).

- [ ] **Step 5:** Manual test on device — join game → lock screen shows countdown.

- [ ] **Step 6: Commit** — `feat(ios): Live Activity for upcoming games`

**Complexity note:** Live Activity requires a Widget Extension target in XcodeGen. Task T3-4 is the largest Tier 3 task — consider splitting into T3-4a (target setup) and T3-4b (manager + join hook) if context is tight.

---

## Tier 3 Gate Checklist

```bash
cd ios && xcodegen generate && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 17'
```

- [ ] Venue filter tests pass
- [ ] Map annotation tests pass
- [ ] Empty state CTA tests pass
- [ ] Manual: map pins, venue chips, host nudge, Live Activity on device

---

## After all tiers

- UI polish pass (design system consistency)
- App Store checklist (privacy policy, screenshots, production APNs)
- Update README with new features and notification preference docs

See [shipping-and-launch skill](../../../.agents/skills/shipping-and-launch/SKILL.md) for launch checklist.
