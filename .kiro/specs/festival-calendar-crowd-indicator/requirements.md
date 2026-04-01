# Requirements Document

## Introduction

The Festival Calendar & Crowd Indicator feature adds structured festival date data and real-time-like crowd level indicators to the Temple Yatra app. Currently, festival information is stored as free-text strings in the `Temple` model. This feature introduces a structured `FestivalEvent` model, a deterministic crowd-level engine (green/yellow/red), and lightweight UI additions — a crowd badge on temple list cards, a crowd status row on the detail screen, and a per-temple festival calendar view. All data is local/mock in Phase 1. The design is intentionally additive: no existing screens are redesigned, only small non-breaking UI elements are inserted.

---

## Glossary

- **Festival_Calendar**: The feature module responsible for storing, querying, and displaying structured festival events per temple.
- **FestivalEvent**: A structured data object representing a single festival occurrence at a temple, containing a name, date, and crowd-level hint.
- **Crowd_Engine**: The pure-function service that computes a `CrowdLevel` for a given temple and date based on festival proximity, day-of-week, and time-of-day rules.
- **CrowdLevel**: An enum with exactly three values — `low`, `moderate`, `high` — representing expected visitor density.
- **Crowd_Badge**: A small colored dot or chip widget (green/yellow/red) rendered non-intrusively on existing temple cards and detail screens.
- **Festival_Data_Source**: The local mock data layer (`lib/data/festival_data.dart`) that provides `List<FestivalEvent>` per temple ID.
- **Temple_Calendar_Screen**: A new screen showing a chronological list of upcoming festivals for a single temple, with crowd indicators per event.
- **Temple**: The existing `Temple` model in `lib/models/temple_model.dart`.
- **TempleCard**: The existing `_TempleCard` widget in `lib/screens/temple_list_screen.dart`.
- **Temple_Detail_Screen**: The existing `lib/screens/temple_detail_screen.dart`.
- **Yatra_Planner_Screen**: The existing `lib/screens/yatra_planner_screen.dart`.
- **Route_Planner_Screen**: The existing `lib/screens/route_planner_screen.dart`.

---

## Requirements

### Requirement 1: Structured Festival Data Model

**User Story:** As a developer, I want a structured `FestivalEvent` model with typed date fields, so that festival data can be queried, sorted, and tested programmatically rather than parsed from free-text strings.

#### Acceptance Criteria

1. THE Festival_Calendar SHALL define a `FestivalEvent` model with at minimum the fields: `templeId` (String), `name` (String), `date` (DateTime), and `crowdHint` (CrowdLevel).
2. THE Festival_Calendar SHALL define `CrowdLevel` as an enum with exactly three values: `low`, `moderate`, `high`.
3. WHEN a `FestivalEvent` is constructed with a `date` value, THE Festival_Calendar SHALL preserve the date without mutation.
4. THE Festival_Data_Source SHALL provide at least one `FestivalEvent` entry for each temple in `allTemples`.
5. THE Festival_Data_Source SHALL store all festival dates as concrete `DateTime` values (year, month, day) with no null dates.
6. IF a `templeId` in `Festival_Data_Source` does not match any `id` in `allTemples`, THEN THE Festival_Data_Source SHALL be considered invalid and a unit test SHALL catch the mismatch.

---

### Requirement 2: Crowd Level Computation

**User Story:** As a devotee, I want to see whether a temple is expected to be crowded on a given date, so that I can plan my visit to avoid long queues.

#### Acceptance Criteria

1. THE Crowd_Engine SHALL accept a `templeId`, a `queryDate` (DateTime), and a list of `FestivalEvent` objects, and SHALL return a `CrowdLevel`.
2. WHEN `queryDate` falls on the same calendar date as a `FestivalEvent` for the given temple, THE Crowd_Engine SHALL return `CrowdLevel.high`.
3. WHEN `queryDate` falls within 2 calendar days before or after a `FestivalEvent` date for the given temple, THE Crowd_Engine SHALL return at least `CrowdLevel.moderate`.
4. WHEN `queryDate` is a Friday, Saturday, or Sunday and no festival proximity rule applies, THE Crowd_Engine SHALL return `CrowdLevel.moderate`.
5. WHEN none of the above conditions apply, THE Crowd_Engine SHALL return `CrowdLevel.low`.
6. THE Crowd_Engine SHALL be a pure function with no side effects — given the same inputs, THE Crowd_Engine SHALL always return the same `CrowdLevel`.
7. IF the list of `FestivalEvent` objects is empty, THEN THE Crowd_Engine SHALL return `CrowdLevel.low` for any `queryDate`.
8. THE Crowd_Engine SHALL evaluate rules in priority order: festival-day (highest) → festival-proximity → weekend → default (lowest), and SHALL return the highest applicable level.

---

### Requirement 3: Crowd Badge on Temple List Cards

**User Story:** As a devotee browsing the temple list, I want to see a small crowd indicator badge on each temple card for today's date, so that I can quickly identify which temples are likely crowded right now.

#### Acceptance Criteria

1. WHEN the Temple_List_Screen renders a TempleCard, THE TempleCard SHALL display a Crowd_Badge showing the `CrowdLevel` for today's date for that temple.
2. THE Crowd_Badge SHALL use green color for `CrowdLevel.low`, yellow/amber for `CrowdLevel.moderate`, and red for `CrowdLevel.high`.
3. THE Crowd_Badge SHALL display a short label: "Low Crowd", "Moderate", or "High Crowd".
4. THE Crowd_Badge SHALL be positioned in the image area of the TempleCard without obscuring the temple name or rating badge.
5. WHILE the existing rating badge is present, THE TempleCard SHALL render both the rating badge and the Crowd_Badge simultaneously without layout overflow.
6. THE Crowd_Badge SHALL NOT require any network call — it SHALL derive its value from the local Festival_Data_Source and Crowd_Engine only.

---

### Requirement 4: Crowd Status on Temple Detail Screen

**User Story:** As a devotee viewing a temple's detail page, I want to see the current crowd level and upcoming festival dates, so that I can decide the best time to visit.

#### Acceptance Criteria

1. WHEN the Temple_Detail_Screen renders, THE Temple_Detail_Screen SHALL display a crowd status row showing the `CrowdLevel` for today's date for that temple.
2. THE crowd status row SHALL include the colored Crowd_Badge and a human-readable label (e.g., "Currently Low Crowd").
3. WHEN the Temple_Detail_Screen renders the Festivals section, THE Temple_Detail_Screen SHALL display the next 3 upcoming `FestivalEvent` entries for that temple in chronological order alongside the existing free-text festivals string.
4. WHEN no upcoming festivals exist within the next 365 days, THE Temple_Detail_Screen SHALL display the message "No upcoming festivals in the next year."
5. THE Temple_Detail_Screen SHALL retain all existing sections (About, Festivals, Darshan Timings, action buttons) without removal or reordering.
6. WHEN the user taps a "View Festival Calendar" button in the Festivals section, THE Temple_Detail_Screen SHALL navigate to the Temple_Calendar_Screen for that temple.

---

### Requirement 5: Temple Festival Calendar Screen

**User Story:** As a devotee, I want to view a full list of upcoming festivals for a specific temple with crowd indicators, so that I can plan my yatra around auspicious dates.

#### Acceptance Criteria

1. THE Temple_Calendar_Screen SHALL display a chronological list of all `FestivalEvent` entries for the given temple with dates in the future (relative to today).
2. WHEN a `FestivalEvent` is displayed, THE Temple_Calendar_Screen SHALL show the festival name, formatted date (e.g., "15 Jan 2026"), and a Crowd_Badge for that festival's date.
3. WHEN the festival list is empty or all events are in the past, THE Temple_Calendar_Screen SHALL display the message "No upcoming festivals scheduled."
4. THE Temple_Calendar_Screen SHALL be navigable via a back button to return to the Temple_Detail_Screen.
5. THE Temple_Calendar_Screen SHALL display the temple name in the AppBar title.
6. WHEN a festival date is today, THE Temple_Calendar_Screen SHALL visually highlight that row (e.g., with a distinct background color).

---

### Requirement 6: Crowd Indicator in Yatra Planner

**User Story:** As a pilgrim planning a yatra, I want to see crowd indicators on temple selection chips, so that I can avoid selecting temples that will be heavily crowded on my travel dates.

#### Acceptance Criteria

1. WHEN the Yatra_Planner_Screen renders temple selection FilterChip widgets, THE Yatra_Planner_Screen SHALL display a Crowd_Badge for each temple based on the selected `_startDate` (or today if no date is selected).
2. WHEN no start date is selected, THE Yatra_Planner_Screen SHALL use today's date for crowd level computation.
3. WHEN the user changes the trip date range, THE Yatra_Planner_Screen SHALL recompute and re-render all crowd badges for the new start date.
4. THE Yatra_Planner_Screen SHALL NOT alter the existing FilterChip selection behavior — crowd badges are display-only additions.

---

### Requirement 7: Crowd Indicator in Route Planner

**User Story:** As a pilgrim reviewing an optimized route, I want to see crowd indicators next to each temple stop, so that I can understand which stops may be congested on my travel day.

#### Acceptance Criteria

1. WHEN the Route_Planner_Screen renders the horizontal temple list, THE Route_Planner_Screen SHALL display a Crowd_Badge for each temple based on the itinerary start date (or today if unavailable).
2. THE Crowd_Badge in the Route_Planner_Screen SHALL be compact (icon-only or small dot) to fit within the existing 100px-wide temple cards.
3. THE Route_Planner_Screen SHALL NOT alter existing route calculation, map rendering, or budget estimation behavior.

---

### Requirement 8: Data Extensibility

**User Story:** As a developer, I want the festival data layer to be easily replaceable with a remote source in a future phase, so that community or admin updates can be incorporated without redesigning the feature.

#### Acceptance Criteria

1. THE Festival_Data_Source SHALL expose festival data through an abstract interface or provider that can be swapped without modifying the Crowd_Engine or UI widgets.
2. THE Festival_Calendar SHALL use Riverpod providers to supply `List<FestivalEvent>` to widgets, so that the data source can be replaced by overriding the provider in tests or future phases.
3. THE Festival_Data_Source SHALL be defined in a dedicated file (`lib/data/festival_data.dart`) separate from `lib/data/temples_data.dart`.

---

## Non-Functional Requirements

### NFR 1: Performance

1. THE Crowd_Engine SHALL compute a `CrowdLevel` in under 5 milliseconds for a list of up to 100 `FestivalEvent` objects on a mid-range Android device.
2. THE Festival_Calendar SHALL NOT perform any I/O operations during crowd level computation — all data SHALL be pre-loaded in memory.

### NFR 2: Correctness

1. THE Crowd_Badge color mapping SHALL be deterministic: `CrowdLevel.low` always maps to green, `CrowdLevel.moderate` always maps to amber/yellow, `CrowdLevel.high` always maps to red.
2. THE Crowd_Engine SHALL never return a value outside the three defined `CrowdLevel` enum values.

### NFR 3: Compatibility

1. THE Festival_Calendar SHALL NOT modify the constructor signature of the existing `Temple` class in a breaking way — new fields SHALL be optional with defaults.
2. THE Festival_Calendar SHALL NOT remove or rename any existing field on the `Temple` model.
3. THE Festival_Calendar SHALL be compatible with Flutter SDK `^3.10.1` and `flutter_riverpod ^2.4.0`.

### NFR 4: Testability

1. THE Crowd_Engine SHALL be implemented as a pure function or stateless class with no Flutter widget dependencies, so that it can be unit-tested without a widget tree.
2. THE Festival_Data_Source SHALL be injectable via Riverpod provider overrides to support widget smoke tests with controlled data.

---

## Edge Cases

1. WHEN a temple has no `FestivalEvent` entries in the Festival_Data_Source, THE Crowd_Engine SHALL return `CrowdLevel.low` for all dates, and the Temple_Calendar_Screen SHALL show "No upcoming festivals scheduled."
2. WHEN two `FestivalEvent` entries for the same temple share the same date, THE Crowd_Engine SHALL treat the date as a festival day and return `CrowdLevel.high` (deduplication is not required).
3. WHEN `queryDate` is in the past, THE Crowd_Engine SHALL still compute and return a valid `CrowdLevel` without throwing an error.
4. WHEN a festival date falls on a weekend, the festival-day rule SHALL take precedence over the weekend rule (priority order from Requirement 2, criterion 8 applies).
5. WHEN the device locale formats dates differently, THE Temple_Calendar_Screen SHALL use the `intl` package (already in `pubspec.yaml`) for consistent date formatting.
6. WHEN `allTemples` is empty (e.g., in a test environment), THE Festival_Data_Source SHALL return an empty list without throwing.

---

## Correctness Properties (for Property-Based Testing)

These properties are suitable for automated or property-based testing of the Crowd_Engine and FestivalEvent model.

### P1: CrowdLevel Exhaustiveness
For any valid inputs `(templeId, queryDate, festivals)`, `Crowd_Engine.compute(templeId, queryDate, festivals)` SHALL return a value that is one of `{CrowdLevel.low, CrowdLevel.moderate, CrowdLevel.high}` — never null, never an unlisted value.

### P2: Festival-Day Dominance (Invariant)
For any `FestivalEvent` `f` where `f.templeId == templeId` and `f.date` is the same calendar day as `queryDate`, `Crowd_Engine.compute(templeId, queryDate, [f])` SHALL return `CrowdLevel.high`. Adding more events to the list SHALL NOT lower the result below `CrowdLevel.high`.

### P3: Empty-List Baseline (Invariant)
For all `templeId` and `queryDate` values, `Crowd_Engine.compute(templeId, queryDate, [])` SHALL equal `CrowdLevel.low`.

### P4: Monotonicity of Festival Proximity
For a fixed `templeId` and `FestivalEvent` `f`, as `queryDate` moves from 3+ days away from `f.date` to 0 days away, the returned `CrowdLevel` SHALL be non-decreasing (i.e., it SHALL never go from `high` to `low` as the date approaches).

### P5: Determinism / Idempotence
For any fixed inputs, calling `Crowd_Engine.compute` twice with the same arguments SHALL return the same `CrowdLevel`. The function is pure and has no observable side effects.

### P6: CrowdLevel Color Mapping Bijectivity
The mapping from `CrowdLevel` to badge color SHALL be a total function: every `CrowdLevel` value maps to exactly one color, and no two `CrowdLevel` values map to the same color.

### P7: FestivalEvent Date Validity
For all `FestivalEvent` objects in `Festival_Data_Source`, `event.date.month` SHALL be in `[1..12]` and `event.date.day` SHALL be in `[1..31]` and the date SHALL be a valid calendar date (no Feb 30, etc.).

### P8: Upcoming Festival Sort Order
For any temple, the list of upcoming festivals returned by the Festival_Calendar SHALL be sorted in ascending order by date — i.e., for any two adjacent events `a` and `b` in the list, `a.date.isBefore(b.date) || a.date.isAtSameMomentAs(b.date)` SHALL hold.

---

## MVP Scope (Phase 1)

The following are in scope for the initial implementation:

- `FestivalEvent` model and `CrowdLevel` enum
- `Festival_Data_Source` with mock data for all 10 existing temples
- `Crowd_Engine` pure function
- Riverpod provider for festival data
- `Crowd_Badge` widget (reusable)
- Crowd badge on `TempleCard` (temple list screen)
- Crowd status row on `Temple_Detail_Screen`
- Upcoming festivals list (next 3) on `Temple_Detail_Screen`
- `Temple_Calendar_Screen` (new screen, full festival list per temple)
- Crowd badge on `Yatra_Planner_Screen` FilterChips
- Crowd badge on `Route_Planner_Screen` temple cards
- Unit tests for `Crowd_Engine` (covering P1–P5)
- Widget smoke test for `Crowd_Badge` rendering

---

## Out of Scope for Phase 1

- Backend API or remote data source for festival data
- User-submitted or community-edited festival entries
- Admin panel for managing festival dates
- Push notifications for upcoming festivals
- Calendar widget (month-grid view) — Phase 1 uses a simple list view only
- Crowd data based on actual footfall or GPS density
- Historical crowd trend charts
- Integration with Google Maps Places "busy times" data
- Localization of festival names (Telugu/Hindi) — Phase 1 uses English names only
- Filtering the temple list by crowd level
- Sorting the temple list by crowd level
- Crowd level for specific time-of-day slots within a day (Phase 1 is date-level only)
