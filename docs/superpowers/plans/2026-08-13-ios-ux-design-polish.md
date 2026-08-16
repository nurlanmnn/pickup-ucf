# iOS UX & Design Polish — Implementation Plan

> **For agentic workers:** Attach this file at the start of any chat to continue work without re-exploring the codebase. **One phase (or one task group) per chat session recommended.** Mark checkboxes as you complete work.

**Goal:** Make PickUp UCF feel polished, smooth, and easy to stay in — especially the **Create Session** flow, which is the main pain point. Prioritize: easy cancel/dismiss, keyboard handling, clear validation, smart defaults, and distinctive UCF-branded UI (not generic iOS Settings forms).

**Platform:** Native SwiftUI iOS app (`ios/PickUpUCF/`). Not web.

**Status:** Phase 1–4 complete. **Phase 5 in progress — P5-0 + P5-1 done.** Last updated: 2026-08-16.

---

## How to use this doc in a new chat

Paste or attach this file and say something like:

> Continue the iOS UX polish plan. Do **Phase 1, Task P1-3** (or whatever is next unchecked). Read the relevant files listed in that task, implement, update checkboxes in this plan, and run tests.

**Rules for agents:**
- Read task files **before** editing; match existing patterns in `DesignSystem/`.
- Keep diffs focused — don't refactor unrelated code.
- After each task: update `[ ]` → `[x]` in this file.
- `EditSessionView` mirrors `CreateSessionView` — apply parallel fixes where noted.
- Do **not** commit unless the user asks.

---

## Progress tracker

| Phase | Summary | Status |
|-------|---------|--------|
| **P1** | Quick UX fixes (validation, keyboard, defaults, discard guard) | ✅ Complete |
| **P2** | Create Session 3-step redesign | ✅ Complete |
| **P3** | App-wide polish (Discover, detail, sheets, haptics) | ✅ Complete |
| **P4** | Delight / optional extras | ✅ Complete |
| **P5** | Visual identity — escape generic SwiftUI look | 🔄 In progress (P5-0 + P5-1 done) |

---

## Current state (baseline)

### App shell
- **4-tab** `TabView`: Discover, My Games, Create (fake tab → sheet), Profile
- **Entry:** `ios/PickUpUCF/Features/Main/MainTabView.swift`
- Create opens `CreateSessionView` in a sheet via `showCreate`
- Post-create: dismiss sheet → My Games tab → push session detail

### Design system (reuse these — do not reinvent)
| Token / component | Path |
|-------------------|------|
| Colors | `ios/PickUpUCF/DesignSystem/Colors.swift` |
| Typography | `ios/PickUpUCF/DesignSystem/Typography.swift` |
| Spacing | `ios/PickUpUCF/DesignSystem/Spacing.swift` |
| PrimaryButton | `ios/PickUpUCF/DesignSystem/Components/PrimaryButton.swift` |
| SecondaryButton | `ios/PickUpUCF/DesignSystem/Components/SecondaryButton.swift` |
| SportPickerGrid / SportPickerChip | `ios/PickUpUCF/DesignSystem/Components/SportPickerGrid.swift` |
| SkillPill | `ios/PickUpUCF/DesignSystem/Components/SkillPill.swift` |
| StepperNumberFieldRow | `ios/PickUpUCF/DesignSystem/Components/StepperNumberFieldRow.swift` |
| CustomLocationPickerRow | `ios/PickUpUCF/DesignSystem/Components/CustomLocationPickerRow.swift` |
| EmptyStateView | `ios/PickUpUCF/DesignSystem/Components/EmptyStateView.swift` |
| FormKeyboardToolbar | `ios/PickUpUCF/DesignSystem/Keyboard/FormKeyboardToolbar.swift` |
| KeyboardDismissModifier | `ios/PickUpUCF/DesignSystem/Keyboard/KeyboardDismissModifier.swift` |
| InlineFeedbackSection | `ios/PickUpUCF/DesignSystem/Components/InlineFeedbackSection.swift` |

**Brand:** UCF gold `#FFC904`, warm off-white / near-black adaptive backgrounds, SF Rounded via `AppFont`.

### Create Session — known pain points (from code review)

| Issue | Location | Detail |
|-------|----------|--------|
| Monolithic form | `CreateSessionView.swift` | 6 sections on one scroll — high cognitive load |
| Bad default venue | `CreateSessionViewModel.swift` L11 | `venuePickerOptionId = "__custom__"` forces map picker |
| Submit ignores `canSubmit` | `CreateSessionView.swift` L147 | Button only checks `!isLoading`; VM has `canSubmit` |
| Hidden defaults | VM L15-19 | Duration/capacity text empty but values 90/10 |
| Errors at top only | `InlineFeedbackSection` at form top | Long form → user misses errors |
| Sport = menu picker | Create + Edit views | Onboarding uses nicer `SportPickerGrid` |
| Keyboard: Done only | `CreateSessionView.swift` L162-170 | Auth forms use full Prev/Next/Done toolbar |
| No discard guard | Close button | Accidental dismiss loses all input |
| Nested sheet | `CustomLocationPickerRow.swift` | Create sheet → map picker sheet |
| Map picker no keyboard UX | `MapLocationPickerView.swift` | Search field has no toolbar / dismiss helper |
| Duplicated create/edit | `EditSessionView.swift` | ~90% same as create (no recurrence) |

### Create flow entry points
1. Create tab → sheet (`MainTabView.swift`)
2. Discover empty state CTA → `appState.requestCreateSession(prefill:)` (`DiscoverView.swift`)
3. Session detail "Run it back" → `CreateSessionPrefill(from: session)` (`SessionDetailView.swift`)

### Related models / VM
- `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift`
- `ios/PickUpUCF/Models/CreateSessionPrefill.swift`
- `ios/PickUpUCF/Features/EditSession/EditSessionViewModel.swift`
- Tests: `ios/PickUpUCFTests/CreateSessionPrefillTests.swift`, `EmptyStateCTATests.swift`

---

## Design direction

**Aesthetic:** Campus-night energy — warm surfaces, gold accents, sport-colored chips. Intentional motion between steps. Not generic purple-gradient or plain iOS `Form`.

**UX principles (non-negotiable):**
1. **Always easy to leave** — visible Close/Cancel + discard confirmation when dirty
2. **Keyboard never fights the user** — Prev/Next/Done, tap-outside dismiss, interactive scroll dismiss
3. **Validation inline, near the field** — not only at top of a long scroll
4. **Defaults visible and sensible** — first official venue, last-used sport, ~2h from now
5. **Progressive disclosure** — 3 steps for create; "Repeat weekly" under "More options"
6. **Success feedback** — haptic + brief confirmation before navigate away

---

## Phase 1 — Quick UX fixes

**Goal:** Same single-form layout, but dramatically better feel. Low risk, ship first.

### P1-1: Fix submit button + show visible defaults

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift`
- Modify: `ios/PickUpUCF/Features/EditSession/EditSessionView.swift` (already uses `canSubmit` — verify)

- [x] **Step 1:** Change `PrimaryButton` `isEnabled` to `vm.canSubmit && !vm.isLoading` in CreateSessionView
- [x] **Step 2:** Initialize `durationText = "90"` and `capacityText = "10"` in VM init (or on appear) so placeholders match actual values
- [x] **Step 3:** Update footer copy — remove confusing "when fields are empty" message; say "Tap to change defaults"
- [x] **Step 4:** Manual test: Create button disabled until location chosen

---

### P1-2: Smart venue default

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift`
- Modify: `ios/PickUpUCF/Features/EditSession/EditSessionViewModel.swift` (if same pattern)

- [x] **Step 1:** In `loadVenues()`, after fetch: if no `pendingVenueId` and current picker is custom tag, set `venuePickerOptionId` to **first venue's id** (when venues non-empty)
- [x] **Step 2:** Only fall back to custom when user explicitly picks "Custom location" or prefill requires it
- [x] **Step 3:** Test Discover CTA prefill still resolves venue after async load
- [x] **Step 4:** Test "Run it back" with custom location still works

---

### P1-3: Full keyboard toolbar on create/edit

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift`
- Modify: `ios/PickUpUCF/Features/EditSession/EditSessionView.swift`
- Reference: `ios/PickUpUCF/Features/Auth/SignInView.swift` (existing pattern)

- [x] **Step 1:** Define ordered focus fields enum: `customSportName`, `duration`, `capacity`, `notes` (skip when hidden)
- [x] **Step 2:** Replace inline Done-only toolbar with `FormKeyboardToolbar(canGoPrevious:canGoNext:onPrevious:onNext:onDone:)`
- [x] **Step 3:** Wire `@FocusState` for all text fields (not just numeric)
- [x] **Step 4:** Add `.dismissKeyboardOnBackgroundTap()` on form scroll content
- [x] **Step 5:** Mirror changes in EditSessionView

---

### P1-4: Map picker keyboard UX

**Files:**
- Modify: `ios/PickUpUCF/Features/Location/MapLocationPickerView.swift`

- [x] **Step 1:** Add `@FocusState private var searchFocused: Bool`
- [x] **Step 2:** Add keyboard toolbar with Done → dismiss search
- [x] **Step 3:** Add `.scrollDismissesKeyboard(.interactively)` if applicable
- [x] **Step 4:** Optional: clear button in search field

---

### P1-5: Unsaved-changes discard guard

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift`
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift`
- Modify: `ios/PickUpUCF/Features/EditSession/EditSessionView.swift` + ViewModel

- [x] **Step 1:** Add `var isDirty: Bool` to VM — true after any user edit (not initial prefill)
- [x] **Step 2:** On Close tap: if `isDirty && !didCreate`, show `.confirmationDialog("Discard this game?", ...)` with Discard / Keep editing
- [x] **Step 3:** Allow swipe-to-dismiss on sheet only when not dirty (`.interactiveDismissDisabled(vm.isDirty)`)
- [x] **Step 4:** Same pattern for EditSession ("Discard changes?")

---

### P1-6: Inline field-level errors

**Files:**
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionViewModel.swift`
- Modify: `ios/PickUpUCF/Features/CreateSession/CreateSessionView.swift`
- Create (optional): `ios/PickUpUCF/DesignSystem/Components/FieldErrorLabel.swift`

- [x] **Step 1:** Add per-field error helpers, e.g. `locationError`, `sportNameError`, `scheduleError`
- [x] **Step 2:** Show small red helper text under Sport (other), Where, and When sections when invalid **after** user attempts Next/Create or leaves field
- [x] **Step 3:** Keep `InlineFeedbackSection` for API/network errors only
- [x] **Step 4:** Scroll to first invalid section on failed submit (optional `ScrollViewReader`)

---

### P1 verification checklist

- [x] Create tab → fill partial form → Close → discard dialog appears
- [x] Create button disabled until venue or custom pin set
- [x] Duration/capacity show 90 and 10 by default
- [x] Keyboard Prev/Next moves between fields on create form
- [x] Map search keyboard has Done
- [x] Edit session gets same keyboard + discard behavior

---

## Phase 2 — Create Session 3-step redesign

**Goal:** Replace monolithic `Form` with a guided 3-step flow inside the same sheet. Biggest UX win.

### Architecture

```
CreateSessionView (container)
├── @State currentStep: CreateSessionStep  (.sportAndTime | .location | .details)
├── progress indicator (3 dots or segmented)
├── step content (@ViewBuilder switch)
├── bottom bar: Back (step 2+) | Next / Create session
└── toolbar: Close (with P1-5 discard guard)
```

**New files to create:**
- `ios/PickUpUCF/Features/CreateSession/CreateSessionStep.swift` — enum + step validation
- `ios/PickUpUCF/Features/CreateSession/Steps/CreateSessionSportTimeStep.swift`
- `ios/PickUpUCF/Features/CreateSession/Steps/CreateSessionLocationStep.swift`
- `ios/PickUpUCF/Features/CreateSession/Steps/CreateSessionDetailsStep.swift`
- `ios/PickUpUCF/DesignSystem/Components/CreateFlowProgressBar.swift` (optional)
- `ios/PickUpUCF/DesignSystem/Components/QuickTimeChip.swift` (optional)

**Modify:**
- `CreateSessionView.swift` — becomes step container (remove giant Form)
- `CreateSessionViewModel.swift` — add `canAdvance(from step:)` per step
- `ios/project.yml` — register new Swift files if using XcodeGen

---

### P2-1: Step 1 — Sport & Time

**UI spec:**
- `SportPickerGrid` for sport (single-select: tapping sets sport, deselect others)
- If `.other` → text field below grid
- **Quick time chips** row: "In 2 hours", "Tonight 6 PM", "Tomorrow 9 AM" — set `startsAt`
- Compact `DatePicker` below chips (graphical or compact style)
- Duration: keep `StepperNumberFieldRow` or replace with `- 90 min +` stepper control

- [x] **Step 1:** Create `CreateSessionSportTimeStep.swift`
- [x] **Step 2:** Single-select wrapper around `SportPickerGrid` (or new `SportPickerSingleSelect`)
- [x] **Step 3:** Implement quick time chip logic (clamp to 48h window)
- [x] **Step 4:** Step validation: sport valid (+ custom name if other), startsAt in range, duration in range
- [x] **Step 5:** Animate step transition (`.transition(.asymmetric(...))`)

---

### P2-2: Step 2 — Location

**UI spec:**
- Horizontal **venue chips** or vertical venue cards (name + optional subtitle)
- "Custom location" card at end → expands inline map preview OR pushes map picker
- Prefer **reducing nested sheets**: embed `MapLocationPickerView` inline in step 2 when custom selected, or use half-height detent
- Show selected location summary with map thumbnail (`SessionLocationMap` if reusable)

- [x] **Step 1:** Create `CreateSessionLocationStep.swift`
- [x] **Step 2:** Venue list UI (not `Picker(.menu)`)
- [x] **Step 3:** Inline custom location flow (minimize sheet-on-sheet)
- [x] **Step 4:** Step validation: `selectedVenueId != nil || customLocationSelection != nil`
- [x] **Step 5:** Default first venue (P1-2) pre-selected visually

---

### P2-3: Step 3 — Details & Create

**UI spec:**
- Capacity stepper (visible default 10)
- Skill level as **horizontal pills** using `SkillPill` (not menu picker)
- Notes: optional, 2-4 lines
- **"More options"** disclosure: Repeat weekly + weeks stepper
- Primary CTA: "Create session" (full width, gold)
- Show summary line: "{Sport} · {Venue} · {Formatted time}"

- [x] **Step 1:** Create `CreateSessionDetailsStep.swift`
- [x] **Step 2:** Skill pill selector
- [x] **Step 3:** Collapsible "More options" for recurrence
- [x] **Step 4:** Summary header above CTA
- [x] **Step 5:** Success state: checkmark overlay 0.5s + haptic → call `onCreated` → dismiss

---

### P2-4: Wire container + navigation

- [x] **Step 1:** Refactor `CreateSessionView` to step container with `currentStep` state
- [x] **Step 2:** Bottom bar: Back (steps 2-3), Next (steps 1-2), Create (step 3)
- [x] **Step 3:** Disable Next until `vm.canAdvance(from: currentStep)`
- [x] **Step 4:** Progress indicator at top
- [x] **Step 5:** Preserve `init(prefill:)` and `.task { loadVenues }` behavior
- [x] **Step 6:** Update `#Preview` blocks

---

### P2-5: Tests + cleanup

- [x] **Step 1:** Add unit tests for step validation on VM
- [x] **Step 2:** Verify all 3 entry points (tab, Discover CTA, Run it back)
- [ ] **Step 3:** Consider extracting shared field groups for EditSession (future — don't block P2)

---

## Phase 3 — App-wide polish

**Goal:** Consistent smoothness across the rest of the app.

### P3-1: Sheet & modal consistency

**Files:** `MainTabView.swift`, `SessionDetailView.swift`, `CustomLocationPickerRow.swift`, report/attendance sheets

- [x] Add `.presentationDragIndicator(.visible)` on all large sheets
- [x] Consistent `.presentationCornerRadius(20)` where supported
- [x] Standardize Cancel label: "Close" for create/edit, "Cancel" for pickers

---

### P3-2: Discover polish

**Files:** `DiscoverView.swift`, `SessionCard.swift`, `DiscoverViewModel.swift`

- [x] Staggered fade-in for session cards on load (animation per index, cap delay)
- [x] Sport chip selection spring animation
- [x] Live "Starts in Xm" on cards (may exist — verify and polish)
- [x] Pull-to-refresh haptic (`UIImpactFeedbackGenerator`)

---

### P3-3: Session detail polish

**Files:** `SessionDetailView.swift`

- [x] Sticky bottom CTA for Join/Leave/Full
- [x] Inline map expand/collapse
- [x] "Run it back" button styling consistent with Primary/Secondary system

---

### P3-4: Keyboard audit (remaining screens)

| Screen | File | Action |
|--------|------|--------|
| Chat | `ChatView.swift` | Verify composer focus + dismiss |
| Profile edit | `EditUsernameView.swift`, `ChangePasswordView.swift` | Already good — verify |
| Verify email OTP | `VerifyEmailView.swift` | Add Done on numberPad |
| Report sheet | `ReportSheet` (find path) | Add if text fields |

- [x] Audit each screen listed above
- [x] Document any exceptions in this plan

**P3-4 audit notes:**
- Chat: composer already used `@FocusState` + `.scrollDismissesKeyboard(.interactively)`. Added `FormKeyboardToolbar` Done + tap-outside dismiss. Single-field composer, so Prev/Next stay disabled.
- Edit username / Change password: already had full toolbar + tap-outside dismiss. No code change.
- Verify email: numberPad now has Done via `FormKeyboardToolbar`.
- Report sheet (`Features/SessionDetail/ReportSheet.swift`): added focus, Done toolbar, interactive scroll dismiss, tap-outside dismiss. Cancel label kept (picker/action sheet, not create/edit).
- Attendance sheet: no text fields. Close label kept (form-style sheet).

---

### P3-5: Haptics on primary actions

- [x] Join session — light impact
- [x] Leave session — light impact
- [x] Filter toggle — selection changed
- [x] Tab switch to Create — soft impact (optional)

---

## Phase 4 — Delight (optional)

- [x] Quick-create preset from Discover empty state (one-tap sport + default venue + time)
- [x] Remember last sport/venue in `UserDefaults` for create prefill
- [x] Create tab icon subtle bounce on tap
- [x] Sport-specific empty state icons/animation
- [x] Live Activity widget visual polish (`ios/PickUpUCFWidget/`, `LiveActivity/`)

**P4 notes:**
- Discover empty CTA now prefills sport + selected/first official venue + start in 2 hours. When All / My Sports is selected, sport chips under the empty state open the same preset for basketball/soccer/volleyball/flag football (or preferred sports).
- Last-used sport/venue is saved after a successful create (`CreateSessionDefaultsStorage`). Tab-open Create applies it; explicit prefills (Discover CTA, Run it back) still win.
- Create tab bounce: SF Symbol bounce plus a spring scale on the UITabBar item (tab items often ignore SwiftUI `symbolEffect`).
- Empty states bounce the sport SF Symbol when the Discover sport filter changes.
- Live Activity lock screen / Dynamic Island use UCF gold, sport-specific glyphs, and a Starts in / Live caption. `GameLiveActivityAttributes` now includes `sportSystemImage`.

---

## Shared extraction (do when touching both Create + Edit)

Consider after P2 is stable:

| Extracted component | Used by |
|---------------------|---------|
| `SessionSportSection` | Create step 1, Edit |
| `SessionScheduleSection` | Create step 1, Edit |
| `SessionLocationSection` | Create step 2, Edit |
| `SessionDetailsSection` | Create step 3, Edit |

**Edit session** can stay single-page form longer — host editing is less frequent than creating. Unify when create redesign is proven.

---

## File map (quick reference)

```
ios/PickUpUCF/
├── App/                         PickUpUCFApp.swift, RootView.swift
├── DesignSystem/
│   ├── Colors.swift, Typography.swift, Spacing.swift
│   ├── Components/              Buttons, cards, pickers, banners
│   └── Keyboard/                FormKeyboardToolbar, KeyboardDismissModifier
├── Features/
│   ├── Main/MainTabView.swift           ← create sheet host
│   ├── CreateSession/                   ← PRIMARY FOCUS
│   │   ├── CreateSessionView.swift
│   │   └── CreateSessionViewModel.swift
│   ├── EditSession/                     ← mirror fixes
│   ├── Discover/DiscoverView.swift
│   ├── SessionDetail/SessionDetailView.swift
│   └── Location/MapLocationPickerView.swift
└── Models/CreateSessionPrefill.swift
```

---

## Testing commands

```bash
# From repo root — run iOS unit tests (adjust scheme if needed)
cd ios && xcodebuild test -scheme PickUpUCF -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# Regenerate Xcode project after adding files via project.yml
cd ios && xcodegen generate
```

**Key test files:**
- `ios/PickUpUCFTests/CreateSessionPrefillTests.swift`
- `ios/PickUpUCFTests/EmptyStateCTATests.swift`
- `ios/PickUpUCFTests/CreateSessionDefaultsStorageTests.swift`
- `ios/PickUpUCFTests/SessionDateFormatterTests.swift`

---

## Suggested session order

| Chat session | Work |
|--------------|------|
| 1 | P1-1 through P1-3 (button, defaults, keyboard) |
| 2 | P1-4 through P1-6 (map keyboard, discard guard, inline errors) |
| 3 | P2-1 (step 1 sport/time UI) |
| 4 | P2-2 (step 2 location UI) |
| 5 | P2-3 + P2-4 (step 3 + wire container) |
| 6 | P2-5 + P3-1 (tests + sheets) |
| 7+ | P3-2 through P4 as needed |
| 8 | P5-0 + P5-1 (tokens + poster session cards) |
| 9 | P5-2 (Discover filter sheet + hero) |
| 10 | P5-3 (custom tab bar) |
| 11 | P5-4 + P5-5 (profile + settings) |
| 12 | P5-6 through P5-8 (polish + motion) |

---

## Notes / decisions log

| Date | Decision |
|------|----------|
| 2026-08-13 | Plan created. Create Session is top priority. 3-step flow over wizard with 5+ steps. Keep UCF gold brand; use existing DesignSystem components. |
| 2026-08-13 | Phase 1 & 2 implemented: 3-step create flow, keyboard/discard/validation fixes, inline map picker, unit tests in `CreateSessionStepValidationTests.swift`. |
| 2026-08-14 | Phase 3 implemented: shared `appSheetChrome()` (drag indicator + 20pt corners), Discover stagger/chip spring/live countdown, sticky session-detail CTA + expandable map, keyboard Done on OTP/chat/report, light join/leave + selection filter haptics. |
| 2026-08-16 | Phase 4 implemented: Discover quick-create presets (sport + venue + 2h), last-used sport/venue UserDefaults, Create tab bounce, sport-specific empty-state icons, Live Activity gold + sport glyph polish. |
| 2026-08-16 | Phase 5 planned: "Night Court" visual identity — poster cards, filter sheet, custom tab bar, profile hero, settings icon rows. User feedback: P1–4 complete but UI still too generic/default. |
| 2026-08-16 | P5-0 + P5-1 implemented: semantic tokens (elevatedSurface, mutedSurface, goldGlow, sportGradient), AppTheme, AppScreenBackground (gold radial glow), AppCardStyle (shadow/inner-glow), Typography now fully `.rounded`. SessionCard redesigned as poster: 4px sport strip, watermark icon, gold time badge, CapacityIndicator dots, sport-tinted join button shadow. AppScreenBackground applied to Discover, My Games, Profile. |

---

## Phase 5 — Visual Identity: "Night Court"

**Goal:** Phases 1–4 fixed UX but the app still reads as default SwiftUI (screenshots confirm: wall of gold pills, white bordered cards, plain `List` profile/settings). Phase 5 gives PickUp UCF a **memorable campus-night personality** by extending what already works on `WelcomeView` (dark gradient, gold glow, sport accents) into the logged-in experience.

**Why it still feels generic (diagnosis from current UI):**

| Screen | Problem |
|--------|---------|
| Discover | 3 rows of identical gold capsule chips eat 40% of viewport before any content |
| Session cards | Horizontal list-row layout + hairline border + circle icon = every sports app template |
| My Games | Same cards; uppercase gray labels; no visual hierarchy between upcoming vs past |
| Profile | Bare `List` + 72pt SF Symbol; stats as plain caption lines |
| Settings | Stock grouped `List` — indistinguishable from iOS Settings |
| Global | `AppFont` uses `.default` design everywhere except `largeTitle`; flat off-white bg; gold overused as fill |

**Creative direction — one sentence:** *Under-the-lights campus energy — dark warm surfaces, gold as accent not wallpaper, sport color as hero, cards that feel like game posters not spreadsheet rows.*

Reference mood: Welcome screen (`WelcomeView.swift` gradients) applied selectively to main tabs, not a full dark-mode-only app.

---

### P5-0: Design tokens foundation

**New / modify files:**
- Modify: `ios/PickUpUCF/DesignSystem/Colors.swift`
- Modify: `ios/PickUpUCF/DesignSystem/Typography.swift`
- Create: `ios/PickUpUCF/DesignSystem/AppTheme.swift`
- Create: `ios/PickUpUCF/DesignSystem/Modifiers/AppScreenBackground.swift`
- Create: `ios/PickUpUCF/DesignSystem/Modifiers/AppCardStyle.swift`

- [x] **P5-0a:** Add semantic tokens: `elevatedSurface`, `mutedSurface`, `goldGlow`, `sportGradient(_:)`, `heroText`
- [x] **P5-0b:** Typography — use `.rounded` for `title`, `headline`, `caption`; add `display()` for screen heroes (34pt rounded bold)
- [x] **P5-0c:** `AppScreenBackground` — warm off-white (light) / near-black + subtle top gold radial glow (both schemes); optional 3% noise overlay via `Canvas` or asset
- [x] **P5-0d:** `AppCardStyle` — replace hairline border with soft shadow (light) / subtle inner glow (dark); 20pt continuous radius
- [x] **P5-0e:** Apply `AppScreenBackground` to Discover, My Games, Profile root views

**Light mode palette shift (keep accessibility):**
```
Background: warm cream (existing)
Surface:    pure white with shadow, not border
Gold:       accents + CTAs only — NOT every chip fill
Sport:      hero color per card (left stripe or gradient header)
Text:       near-black primary, 55% secondary
```

---

### P5-1: Session card redesign → "Game Poster Card"

**Replace** horizontal `HStack` row layout in `SessionCard.swift`.

**New layout (vertical poster):**
```
┌─────────────────────────────────────┐
│ ▓▓▓ sport gradient strip (4px)      │
│  🏀 (large)          ┌──────────┐   │
│                      │ IN 2 HR  │   │  ← gold badge, live countdown
│  Soccer              └──────────┘   │
│  RWC Courts                         │
│  Today · 6:00 PM                    │
│  ○○○○○○○○░░  1/14        [Join]   │  ← capacity dots or mini ring
└─────────────────────────────────────┘
```

- [x] **P5-1a:** Create `CapacityIndicator.swift` — row of filled/empty dots or `Gauge` arc
- [x] **P5-1b:** Rewrite `SessionCard` as `VStack` with sport gradient top edge + watermark icon (15% opacity, trailing)
- [x] **P5-1c:** Prominent relative-time badge (`IN 2 HR`, `STARTING SOON`) — gold capsule, semibold rounded
- [x] **P5-1d:** Join button: full-width on narrow cards OR keep trailing pill but with sport-tinted shadow on press
- [x] **P5-1e:** Press state: scale 0.97 + shadow deepen (already has scale — enhance)
- [x] **P5-1f:** Update loading skeleton to match new card height (~140pt)

---

### P5-2: Discover — reduce filter noise, add hero header

**Problem:** 3 chip rows + segmented control + large nav title = cluttered, generic.

**New structure:**
```
┌ Discover ──────────────────── [filter icon] ┐
│  "12 games near campus"     ← live count subtitle │
│  [collapsed active filters as small pills]        │
│  ─────────────────────────────────────────────    │
│  [Game Poster Cards…]                             │
└───────────────────────────────────────────────────┘
```

- [ ] **P5-2a:** Create `DiscoverFilterSheet.swift` — bottom sheet with sport grid, time, skill, venue (move filters out of main scroll)
- [ ] **P5-2b:** Replace inline 3 chip rows with: (1) hero subtitle showing result count, (2) horizontal row of **active filter pills** only (with × to clear), (3) toolbar filter button
- [ ] **P5-2c:** Inline large title: `"Discover"` as `AppFont.display()` in scroll content, `.navigationBarHidden(true)` or transparent toolbar
- [ ] **P5-2d:** Redesign `SportChip` → `FilterChip`: unselected = surface + subtle border; selected = sport accent fill OR gold fill (not all gold)
- [ ] **P5-2e:** List/Map toggle: custom pill toggle with icons (not raw `.segmented`)
- [ ] **P5-2f:** Empty state: larger sport icon with gold glow ring (match Welcome sport row style)

---

### P5-3: Custom tab bar + elevated Create

**Problem:** Fake Create tab + default `TabView` = generic; Create is just another tab icon.

- [ ] **P5-3a:** Create `AppTabBar.swift` — custom bottom bar overlay (or `TabView` with hidden labels + custom overlay)
- [ ] **P5-3b:** Center **Create** as elevated gold FAB (56pt circle, `plus`, shadow/glow) — breaks tab row visually
- [ ] **P5-3c:** Active tab: gold icon + label; inactive: secondary gray; subtle spring on switch
- [ ] **P5-3d:** Optional: mini sport pulse animation on Create FAB when Discover empty state nudges hosting
- [ ] **P5-3e:** Wire in `MainTabView.swift`; remove fake `Color.clear` tab hack

---

### P5-4: Profile → identity hero

**Problem:** Centered SF Symbol on empty `List` — no personality, no reason to visit.

**New layout:**
```
┌─────────────────────────────────────┐
│  ░░ gold radial mesh background ░░ │
│         (avatar ring)               │
│           Cavidd                    │
│         @username                   │
│  ┌────────┐ ┌────────┐ ┌────────┐  │
│  │   0    │ │   0    │ │  🎾   │  │
│  │ games  │ │ streak │ │ sports│  │
│  └────────┘ └────────┘ └────────┘  │
│  [Settings card row with chevron]   │
└─────────────────────────────────────┘
```

- [ ] **P5-4a:** Replace `List` with `ScrollView` + `AppScreenBackground`
- [ ] **P5-4b:** Create `ProfileHeroHeader.swift` — gradient header band, avatar with gold ring stroke
- [ ] **P5-4c:** Create `StatTile.swift` — 3-up grid for games / streak / top sport icon
- [ ] **P5-4d:** Settings entry as elevated card row (icon + title + chevron), not bare `NavigationLink` in List
- [ ] **P5-4e:** Show preferred sports as small `SportPickerChip`-style read-only row under stats

---

### P5-5: Settings → icon cards (not iOS Settings clone)

- [ ] **P5-5a:** Create `SettingsRow.swift` — leading colored icon circle + title + chevron
- [ ] **P5-5b:** Replace `List` sections with `VStack` of grouped cards (`AppCardStyle`)
- [ ] **P5-5c:** Icon colors: account=blue, notifications=orange, privacy=purple, destructive=red
- [ ] **P5-5d:** Section headers as `AppFont.caption` uppercase on background, not inset grouped style

---

### P5-6: My Games — timeline feel

- [ ] **P5-6a:** Upcoming: first card gets `featured` variant (slightly larger, gold left border, "NEXT UP" label)
- [ ] **P5-6b:** Past section: cards at 85% opacity + desaturated sport colors
- [ ] **P5-6c:** Replace uppercase "UPCOMING" with inline title + count badge: `Upcoming · 1`
- [ ] **P5-6d:** Collapsible past header: chevron rotation animation + surface card background

---

### P5-7: Create flow visual polish (already functional from P2)

- [ ] **P5-7a:** Step container: apply `AppScreenBackground` + sport-colored step accent (step 1=sport color, 2=blue map, 3=gold)
- [ ] **P5-7b:** `CreateFlowProgressBar` → segmented gold bar with spring fill (not just dots)
- [ ] **P5-7c:** Success overlay: gold checkmark burst + confetti dots (simple `Canvas` particles, 0.8s)

---

### P5-8: Motion & micro-delight

- [ ] **P5-8a:** Join success: sport-colored flash on card border (0.3s)
- [ ] **P5-8b:** Filter sheet: `.presentationDetents([.medium, .large])` with spring
- [ ] **P5-8c:** Tab switch: cross-fade content (optional, low priority)
- [ ] **P5-8d:** Pull-to-refresh: gold spinner tint

---

### P5 verification checklist

- [ ] Discover shows game cards above the fold on iPhone 16 (filters collapsed to sheet)
- [ ] No screen uses 3+ rows of gold-filled chips
- [ ] Session cards visually distinct from Apple Reminders / generic list apps
- [ ] Profile has stat tiles + gradient header — not empty List
- [ ] Settings rows have icons — not plain text list
- [ ] Welcome screen aesthetic (gold glow, dark warmth) visible in at least Discover hero + Profile header
- [ ] Light and dark mode both tested
- [ ] VoiceOver labels preserved on redesigned components

---

### P5 suggested session order

| Session | Tasks | Impact |
|---------|-------|--------|
| 1 | P5-0 + P5-1 | Foundation + new session cards — biggest visual change |
| 2 | P5-2 | Discover filter sheet + hero — fixes screenshot clutter |
| 3 | P5-3 | Custom tab bar + FAB Create |
| 4 | P5-4 + P5-5 | Profile + Settings identity |
| 5 | P5-6 + P5-7 + P5-8 | My Games, Create polish, motion |

---

### P5 component inventory (new files)

| File | Purpose |
|------|---------|
| `DesignSystem/AppTheme.swift` | Semantic colors, gradients |
| `DesignSystem/Modifiers/AppScreenBackground.swift` | Shared screen backdrop |
| `DesignSystem/Modifiers/AppCardStyle.swift` | Shadow/glow card modifier |
| `DesignSystem/Components/CapacityIndicator.swift` | Player count visual |
| `DesignSystem/Components/StatTile.swift` | Profile stat grid cell |
| `DesignSystem/Components/SettingsRow.swift` | Icon settings row |
| `DesignSystem/Components/FilterChip.swift` | Non-gold filter pills |
| `DesignSystem/Components/AppTabBar.swift` | Custom tab bar + FAB |
| `Features/Discover/DiscoverFilterSheet.swift` | Consolidated filters |
| `Features/Profile/ProfileHeroHeader.swift` | Profile gradient header |

---

## Out of scope (for this plan)

- Backend / API changes
- Android / web
- Bundled custom fonts (Phase 5 uses SF Rounded everywhere — revisit only if user requests)
- Full Edit Session redesign (follows after Create is done)
