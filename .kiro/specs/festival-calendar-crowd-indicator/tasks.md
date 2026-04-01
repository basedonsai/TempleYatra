# Implementation Plan: Festival Calendar & Crowd Indicator

## Overview

Implement the festival calendar and crowd indicator feature as a self-contained, additive module. Tasks follow a strict dependency order: models → data → engine → providers → widgets → screens → integrations → tests. No existing constructors are broken; all screen integrations use inline `Consumer` widgets where the screen is a `StatelessWidget` or `StatefulWidget`, and `ConsumerStatefulWidget` only where `ref` is needed in `build`.

## Tasks

- [x] 1. Create `FestivalEvent` model and `CrowdLevel` enum
  - Create `lib/models/festival_event.dart`
  - Define `enum CrowdLevel { low, moderate, high }` — exactly three values, in this order
  - Define `class FestivalEvent` with `const` constructor and four `final` fields: `templeId` (String), `name` (String), `date` (DateTime), `crowdHint` (CrowdLevel)
  - No Flutter imports — pure Dart only
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Create `festival_data.dart` with mock festival events for all 10 temples
  - Create `lib/data/festival_data.dart`
  - Import `festival_event.dart`
  - Declare `final List<FestivalEvent> allFestivalEvents = [ ... ]` with at least 2 events per temple
  - Use these exact temple IDs (matching `lib/data/temples_data.dart`): `chilkur_balaji`, `jagannath_hyderabad`, `peddamma_thalli`, `birla_mandir_hyderabad`, `laknavaram`, `' Thousand Pillar Temple'`, `keesaragutta`, `vijayawada`, `tadepalli`, `srisailam`
  - All dates as `DateTime(year, month, day)` — no time component, no nulls
  - All `crowdHint` values set to `CrowdLevel.high` (festival days are inherently high-crowd)
  - Add a convenience function `List<FestivalEvent> festivalEventsForTemple(String templeId)` that filters and sorts by date
  - Sample events to include (add at least one more per temple beyond these):
    - chilkur_balaji: Brahmotsavam `DateTime(2026, 2, 14)`, Vaikunta Ekadasi `DateTime(2026, 1, 2)`, Sri Rama Navami `DateTime(2026, 3, 28)`
    - jagannath_hyderabad: Rath Yatra `DateTime(2026, 6, 24)`, Snana Purnima `DateTime(2026, 6, 11)`, Diwali Puja `DateTime(2026, 10, 20)`
    - peddamma_thalli: Bonalu Festival `DateTime(2026, 7, 19)`, Navratri `DateTime(2026, 10, 2)`
    - birla_mandir_hyderabad: Janmashtami `DateTime(2026, 8, 16)`, Vaikunta Ekadasi `DateTime(2026, 1, 2)`
    - laknavaram: Brahmotsavam `DateTime(2026, 3, 20)`, Rama Navami `DateTime(2026, 3, 28)`
    - ' Thousand Pillar Temple': Shivratri `DateTime(2026, 2, 26)`, Sankranti `DateTime(2026, 1, 14)`
    - keesaragutta: Brahmotsavam `DateTime(2026, 3, 15)`, Vaikunta Ekadasi `DateTime(2026, 1, 2)`
    - vijayawada: Brahmotsavam `DateTime(2026, 10, 10)`, Navratri `DateTime(2026, 10, 2)`
    - tadepalli: Shivratri `DateTime(2026, 2, 26)`, Ganesha Chaturthi `DateTime(2026, 8, 27)`
    - srisailam: Mahashivaratri `DateTime(2026, 2, 26)`, Brahmotsavam `DateTime(2026, 9, 5)`
  - _Requirements: 1.4, 1.5, 8.3_

- [x] 3. Implement `CrowdEngine` — pure crowd-level computation function
  - Create `lib/services/crowd_engine.dart`
  - Import only `festival_event.dart` — no Flutter imports
  - Implement top-level function: `CrowdLevel computeCrowdLevel(String templeId, DateTime queryDate, List<FestivalEvent> events)`
  - Algorithm (evaluate rules in priority order, return on first match):
    1. Normalize `queryDate` to midnight: `final qDay = DateTime(queryDate.year, queryDate.month, queryDate.day)`
    2. Filter events to `templeId` only
    3. Rule 1 — Festival Day: if any event's normalized date equals `qDay` → return `CrowdLevel.high`
    4. Rule 2 — Festival Proximity: if any event's normalized date is within ±1 or ±2 days (`(eventDay.difference(qDay)).inDays.abs() <= 2`) → return `CrowdLevel.moderate`
    5. Rule 3 — Weekend: if `queryDate.weekday` is 5 (Friday), 6 (Saturday), or 7 (Sunday) → return `CrowdLevel.moderate`
    6. Rule 4 — Default: return `CrowdLevel.low`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

- [x] 4. Create Riverpod providers for festival data
  - Create `lib/providers/festival_provider.dart`
  - Import `flutter_riverpod`, `festival_event.dart`, and `festival_data.dart`
  - Declare synchronous providers (not `AsyncNotifierProvider`):
    ```dart
    final festivalProvider = Provider<List<FestivalEvent>>((ref) => allFestivalEvents);
    final templeFestivalsProvider = Provider.family<List<FestivalEvent>, String>(
      (ref, templeId) => ref.watch(festivalProvider)
          .where((e) => e.templeId == templeId).toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
    );
    ```
  - _Requirements: 8.1, 8.2_

- [x] 5. Implement `CrowdBadge` widget
  - Create `lib/widgets/crowd_badge.dart`
  - Import `flutter/material.dart` and `festival_event.dart`
  - Define color and label maps as private constants:
    - `CrowdLevel.low` → `Colors.green`, label `'Low Crowd'`
    - `CrowdLevel.moderate` → `Colors.amber`, label `'Moderate'`
    - `CrowdLevel.high` → `Colors.red`, label `'High Crowd'`
  - Constructor: `const CrowdBadge({super.key, required this.level, this.compact = false})`
  - Full mode (`compact: false`): `Row(mainAxisSize: MainAxisSize.min)` containing an 8px circular `Container` (filled with level color) + `SizedBox(width: 4)` + `Text(label)`
  - Compact mode (`compact: true`): the 8px dot only, wrapped in a `Tooltip` whose message is the label string
  - _Requirements: 3.2, 3.3, NFR 2.1_

- [x] 6. Create `TempleCalendarScreen`
  - Create `lib/screens/temple_calendar_screen.dart`
  - Extend `ConsumerWidget`; constructor: `const TempleCalendarScreen({super.key, required this.temple})`
  - Import `intl` package for `DateFormat`; import `festival_provider.dart`, `crowd_engine.dart`, `crowd_badge.dart`
  - In `build`: watch `templeFestivalsProvider(temple.id)`, filter to events where `DateTime(e.date.year, e.date.month, e.date.day) >= DateTime(now.year, now.month, now.day)`, keep sorted ascending
  - AppBar title: `'${temple.name} — Festivals'` with a back arrow
  - Empty state: `Center(child: Text('No upcoming festivals scheduled.'))`
  - Non-empty: `ListView.builder` over upcoming events; each item is a `ListTile` with:
    - `leading`: `CrowdBadge(level: computeCrowdLevel(temple.id, event.date, allEvents))`
    - `title`: `Text(event.name)`
    - `subtitle`: `Text(DateFormat('d MMM yyyy').format(event.date))`
    - `tileColor`: `Colors.orange.shade50` when the event date equals today (midnight-normalized comparison), otherwise null
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 7. Integrate `CrowdBadge` into `TempleListScreen` (`_TempleCard`)
  - Modify `lib/screens/temple_list_screen.dart`
  - Add imports: `flutter_riverpod`, `crowd_badge.dart`, `festival_provider.dart`, `crowd_engine.dart`
  - In `_TempleCard.build`, inside the existing `Stack` in the image area, add a new `Positioned` child after the existing rating badge:
    ```dart
    Positioned(
      top: 12,
      left: 12,
      child: Consumer(
        builder: (context, ref, _) {
          final events = ref.watch(templeFestivalsProvider(temple.id));
          final level = computeCrowdLevel(temple.id, DateTime.now(), events);
          return CrowdBadge(level: level);
        },
      ),
    ),
    ```
  - Do NOT change `_TempleCard` to a `ConsumerWidget` — use inline `Consumer` only
  - The existing rating badge at `top: 12, right: 12` must remain untouched
  - _Requirements: 3.1, 3.4, 3.5, 3.6_

- [x] 8. Integrate crowd status and upcoming festivals into `TempleDetailScreen`
  - Modify `lib/screens/temple_detail_screen.dart`
  - Add imports: `flutter_riverpod`, `intl`, `crowd_badge.dart`, `festival_provider.dart`, `crowd_engine.dart`, `temple_calendar_screen.dart`
  - `TempleDetailScreen` stays a `StatelessWidget` — use inline `Consumer` for both additions
  - Addition A — Crowd status row: insert before the `_buildSection('About', ...)` call (after the `const SizedBox(height: 18)` quick-actions spacer):
    ```dart
    Consumer(builder: (context, ref, _) {
      final events = ref.watch(templeFestivalsProvider(temple.id));
      final level = computeCrowdLevel(temple.id, DateTime.now(), events);
      final label = switch (level) {
        CrowdLevel.low => 'Currently Low Crowd',
        CrowdLevel.moderate => 'Moderate Crowd Expected',
        CrowdLevel.high => 'High Crowd Expected',
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          CrowdBadge(level: level),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      );
    }),
    ```
  - Addition B — Festivals section: replace the existing `_buildSection('Festivals', ...)` children list with:
    - Keep existing `Text(temple.festivals, ...)` as first child (unchanged)
    - Add `const SizedBox(height: 10)`
    - Add a `Consumer` that watches `templeFestivalsProvider(temple.id)`, takes the next 3 upcoming events (date >= today), and renders either `Text('No upcoming festivals in the next year.')` or a `Column` of `Row`s each containing `CrowdBadge(level: computeCrowdLevel(...))`, `SizedBox(width: 8)`, `Text(event.name)`, `Spacer()`, `Text(DateFormat('d MMM yyyy').format(event.date))`
    - Add `const SizedBox(height: 10)`
    - Add `SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TempleCalendarScreen(temple: temple))), icon: const Icon(Icons.calendar_month, size: 18), label: const Text('View Festival Calendar')))`
  - All other sections (About, Darshan Timings, action buttons, FAB) remain untouched
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 9. Integrate `CrowdBadge` into `YatraPlannerScreen`
  - Modify `lib/screens/yatra_planner_screen.dart`
  - Convert `YatraPlannerScreen` from `StatefulWidget` + `State<YatraPlannerScreen>` to `ConsumerStatefulWidget` + `ConsumerState<YatraPlannerScreen>`
    - Change `class YatraPlannerScreen extends StatefulWidget` → `extends ConsumerStatefulWidget`
    - Change `class _YatraPlannerScreenState extends State<YatraPlannerScreen>` → `extends ConsumerState<YatraPlannerScreen>`
    - No other structural changes to the class
  - Add imports: `flutter_riverpod`, `crowd_badge.dart`, `festival_provider.dart`, `crowd_engine.dart`
  - In the `FilterChip` for each temple (inside the `_availableTemples.map(...)` block), replace the existing `avatar: Icon(Icons.temple_hindu, ...)` with:
    ```dart
    avatar: Consumer(builder: (context, ref, _) {
      final events = ref.watch(templeFestivalsProvider(temple.id));
      final level = computeCrowdLevel(
        temple.id,
        _startDate ?? DateTime.now(),
        events,
      );
      return CrowdBadge(level: level, compact: true);
    }),
    ```
  - All `FilterChip` selection behavior (`onSelected`, `selected`, `selectedColor`, `checkmarkColor`) remains unchanged
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 10. Integrate compact `CrowdBadge` into `RoutePlannerScreen`
  - Modify `lib/screens/route_planner_screen.dart`
  - Add imports: `flutter_riverpod`, `crowd_badge.dart`, `festival_provider.dart`, `crowd_engine.dart`
  - Do NOT convert `RoutePlannerScreen` or `_RoutePlannerScreenState` — use inline `Consumer` only
  - In the horizontal `ListView.builder` temple cards (the `Container(width: 100, ...)` items), inside the existing `Column(mainAxisAlignment: MainAxisAlignment.center)`, add after the temple name `Text(...)` and before the `if (index <= _currentWaypointIndex) Icon(...)` check:
    ```dart
    const SizedBox(height: 4),
    Consumer(builder: (context, ref, _) {
      final events = ref.watch(templeFestivalsProvider(temple.id));
      final date = widget.itinerary?.startDate ?? DateTime.now();
      final level = computeCrowdLevel(temple.id, date, events);
      return CrowdBadge(level: level, compact: true);
    }),
    ```
  - `widget.itinerary` is of type `GeneratedItinerary?` which has a `startDate` field — use `widget.itinerary?.startDate ?? DateTime.now()`
  - No changes to route calculation, map rendering, or budget logic
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 11. Write unit tests for `CrowdEngine` (Properties P1–P6, P9)
  - Create `test/crowd_engine_test.dart`
  - Import `package:test/test.dart`, `crowd_engine.dart`, `festival_event.dart`
  - Each test group must include a comment: `// Feature: festival-calendar-crowd-indicator, Property N: <title>`
  - [x] 11.1 Property P1 — Exhaustiveness and purity
    - Call `computeCrowdLevel` with 5+ varied inputs (different templeIds, dates, event lists)
    - Assert result is always one of the three `CrowdLevel` values (never null)
    - Assert calling twice with same args returns equal results
    - _Requirements: 2.1, 2.6, NFR 2.2_
  - [x] 11.2 Property P2 — Festival-Day Dominance
    - For 5+ festival events on known dates, assert `computeCrowdLevel(f.templeId, f.date, [f])` returns `CrowdLevel.high`
    - Assert adding extra unrelated events does not lower the result
    - _Requirements: 2.2, 2.8_
  - [x] 11.3 Property P3 — Empty-List Baseline
    - For 5+ arbitrary (templeId, date) pairs with empty event list, assert result is `CrowdLevel.low`
    - _Requirements: 2.7_
  - [x] 11.4 Property P4 — Festival Proximity yields at least moderate
    - For offsets `[-2, -1, 1, 2]` applied to a festival date, assert result is not `CrowdLevel.low`
    - Use at least 3 different base festival dates
    - _Requirements: 2.3_
  - [x] 11.5 Property P5 — Weekend yields moderate with empty list
    - For Friday (weekday 5), Saturday (6), Sunday (7) dates with empty event list, assert `CrowdLevel.moderate`
    - Use at least 3 different weekend dates
    - _Requirements: 2.4_
  - [x] 11.6 Property P6 — Non-festival weekday yields low
    - For Monday–Thursday dates with empty event list, assert `CrowdLevel.low`
    - Use at least 3 different weekday dates
    - _Requirements: 2.5_
  - [x] 11.7 Property P9 — FestivalEvent date immutability
    - Construct `FestivalEvent` with known `DateTime` values; assert `.date` equals the input (same year, month, day)
    - _Requirements: 1.3_

- [x] 12. Write widget smoke tests for `CrowdBadge` (Property P7)
  - Create `test/crowd_badge_test.dart`
  - Import `package:flutter_test/flutter_test.dart`, `flutter_riverpod`, `crowd_badge.dart`, `festival_event.dart`, `festival_provider.dart`
  - Wrap each test widget in `ProviderScope` + `MaterialApp`
  - Include comment: `// Feature: festival-calendar-crowd-indicator, Property 7: CrowdBadge Content Correctness`
  - [x] 12.1 Full badge rendering for each CrowdLevel
    - Render `CrowdBadge(level: CrowdLevel.low)` — find `Text('Low Crowd')`, find green `Container`
    - Render `CrowdBadge(level: CrowdLevel.moderate)` — find `Text('Moderate')`, find amber `Container`
    - Render `CrowdBadge(level: CrowdLevel.high)` — find `Text('High Crowd')`, find red `Container`
    - _Requirements: 3.2, 3.3, NFR 2.1_
  - [x] 12.2 Compact badge has no text, has tooltip
    - Render `CrowdBadge(level: CrowdLevel.low, compact: true)` — assert no `Text` widget found, assert `Tooltip` widget found
    - _Requirements: 7.2_
  - [x] 12.3 Badge renders inside ProviderScope with overridden festivalProvider
    - Override `festivalProvider` with an empty list; render `CrowdBadge(level: CrowdLevel.low)` — assert no exception thrown
    - _Requirements: NFR 4.2_

- [ ] 13. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- The `' Thousand Pillar Temple'` temple ID has a leading space — match it exactly as it appears in `lib/data/temples_data.dart`
- `RoutePlannerScreen` uses `GeneratedItinerary` (from `lib/services/itinerary_generator.dart`), not `SmartItinerary` — use `widget.itinerary?.startDate`
- All screen integrations use inline `Consumer` widgets; only `YatraPlannerScreen` is converted to `ConsumerStatefulWidget`
- Property tests validate universal correctness; unit tests validate specific examples and edge cases
