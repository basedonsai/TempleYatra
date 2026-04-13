# Implementation Plan: SQLite UI Migration

## Overview

Migrate seven screens and one provider file from hardcoded `lib/data/` imports to SQLite-backed Riverpod providers. Each task is scoped to a single file so the build stays green after every step.

## Tasks

- [x] 1. Migrate festival_provider.dart to SQLite-backed sync wrappers
  - [x] 1.1 Re-implement `festivalProvider` using the sync wrapper pattern
    - Watch `upcomingFestivalsDbProvider(9999)` and unwrap with `.when(data: (d) => d, loading: () => [], error: (_, __) => [])`
    - Remove direct reference to `allFestivalEvents`
    - _Requirements: 2.1_
  - [x] 1.2 Re-implement `templeFestivalsProvider` to delegate to `templeFestivalsDbProvider`
    - Watch `templeFestivalsDbProvider(templeId)` and unwrap with `.when`
    - Remove direct reference to `allFestivalEvents`
    - _Requirements: 2.2_
  - [x] 1.3 Remove `import '../data/festival_data.dart'` from `festival_provider.dart`
    - _Requirements: 4.2_

- [x] 2. Migrate temple_calendar_screen.dart
  - [x] 2.1 Replace `allFestivalEvents` with `allEvents` in `computeCrowdLevel` call
    - `allEvents` is already watched via `templeFestivalsProvider(temple.id)` — just update the argument
    - _Requirements: 2.3, 2.4_
  - [x] 2.2 Remove `import '../data/festival_data.dart'` from `temple_calendar_screen.dart`
    - _Requirements: 4.2_

- [x] 3. Checkpoint — ensure app compiles and festival data flows correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Migrate temple_list_screen.dart
  - [x] 4.1 Convert `StatefulWidget` → `ConsumerStatefulWidget` and `State` → `ConsumerState`
    - Add `WidgetRef ref` access via `ConsumerState`
    - _Requirements: 1.1_
  - [x] 4.2 Watch `allTemplesDbProvider` in `build` and handle loading/error states
    - Return `CircularProgressIndicator` while loading
    - Return an error message widget on error
    - _Requirements: 1.2, 1.4_
  - [x] 4.3 Update `_getFilteredTemples` to accept `List<Temple> source` parameter
    - Pass the resolved list from the provider instead of reading `allTemples` directly
    - _Requirements: 1.3, 5.4_
  - [x] 4.4 Remove `import '../data/temples_data.dart'` from `temple_list_screen.dart`
    - _Requirements: 4.1_

- [x] 5. Migrate home_screen.dart
  - [x] 5.1 Watch `allTemplesDbProvider` in `build` and update `_buildFeaturedSection`
    - Use `.when(data:, loading:, error:)` — show `CircularProgressIndicator` while loading
    - _Requirements: 1.5, 1.6, 1.7_
  - [x] 5.2 Watch `upcomingFestivalsDbProvider(3)` directly in `_buildFestivalsSection`
    - Replace `festivalProvider` usage; remove manual `.take(3)` / sort (repository handles ordering)
    - Handle empty list with existing "No upcoming festivals found." message
    - _Requirements: 2.5, 2.6, 2.7_
  - [x] 5.3 Fix `allTemples.first` references with null-safe guard
    - Use `allTemplesDbProvider.value?.first` (or equivalent `.when` data branch) to avoid null crash
    - _Requirements: 1.6, 5.1_
  - [x] 5.4 Remove `import '../data/temples_data.dart'` from `home_screen.dart`
    - _Requirements: 4.1_

- [x] 6. Checkpoint — ensure app compiles and home + temple list screens render correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Migrate yatra_planner_screen.dart
  - [x] 7.1 Remove `final List<Temple> _availableTemples = allTemples` instance field
    - _Requirements: 1.8_
  - [x] 7.2 Watch `allTemplesDbProvider` in `build` and use `.when` for the chip `Wrap` section
    - Show `CircularProgressIndicator` while loading; pass resolved list to chip builder on data
    - _Requirements: 1.9_
  - [x] 7.3 Update `_selectAllTemples`, `_clearSelection`, `_selectTopRated` to receive the list as a parameter or read from local state
    - _Requirements: 1.9, 5.3_
  - [x] 7.4 Remove `import '../data/temples_data.dart'` from `yatra_planner_screen.dart`
    - _Requirements: 4.1_

- [x] 8. Migrate map_screen.dart
  - [x] 8.1 Convert `StatefulWidget` → `ConsumerStatefulWidget` and `State` → `ConsumerState`
    - _Requirements: 1.10_
  - [x] 8.2 Add `bool _markersLoaded = false` flag and remove `_loadTempleMarkers()` call from `initState`
    - _Requirements: 1.10_
  - [x] 8.3 Watch `allTemplesDbProvider` in `build`; on first data arrival call `_loadTempleMarkersFromList(temples)` via `addPostFrameCallback`
    - Guard with `_markersLoaded` flag to prevent repeated calls
    - _Requirements: 1.10, 1.11_
  - [x] 8.4 Update bottom sheet and `_fitAllTemples` to use the resolved `List<Temple>` from the provider
    - Show `CircularProgressIndicator` in bottom sheet while loading
    - _Requirements: 1.11, 5.1_
  - [x] 8.5 Remove `import '../data/temples_data.dart'` from `map_screen.dart`
    - _Requirements: 4.1_

- [x] 9. Migrate offline_pack_manager_screen.dart
  - [x] 9.1 Watch `allTemplesDbProvider` in `_AudioPackCard.build`
    - Use `templesAsync.valueOrNull ?? []` to get the resolved list
    - _Requirements: 3.1, 3.2_
  - [x] 9.2 Replace `allTemples.firstWhere(...)` with a null-safe lookup on the resolved list
    - Use `.where((t) => t.id == pack.templeId).firstOrNull`
    - If temple is `null`, navigate to `StorytellingScreen` with `templeId` only — no crash
    - _Requirements: 3.2, 3.3_
  - [x] 9.3 Verify download, cancel, delete, and retry controls are unaffected
    - _Requirements: 3.4_
  - [x] 9.4 Remove `import '../data/temples_data.dart'` from `offline_pack_manager_screen.dart`
    - _Requirements: 4.1_

- [x] 10. Checkpoint — full app compiles; all screens render without importing lib/data directly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Write migration tests in test/database/migration_test.dart
  - [x] 11.1 Write unit tests for edge cases
    - Seed empty DB → `getAll()` returns `[]`
    - Seed one temple → `getById(id)` returns that temple
    - `getForTemple("nonexistent_id")` → returns `[]`
    - `getUpcoming(0)` → returns `[]`
    - `getUpcoming(3)` with only 1 future festival seeded → returns list of length 1
    - _Requirements: 6.1, 6.2, 6.3_
  - [x] 11.2 Write property test for Property 1: Temple seeding round-trip
    - **Property 1: Temple Seeding Round-Trip**
    - For any N randomly generated temples, seed them into an in-memory DB, call `getAll()`, assert length == N and all IDs match
    - Use `:memory:` SQLite database; run ≥ 100 iterations
    - **Validates: Requirements 6.1, 6.4**
  - [x] 11.3 Write property test for Property 2: Festival filter correctness
    - **Property 2: Festival Filter Correctness**
    - For any `templeId` and any set of seeded festivals, assert `getForTemple(templeId)` returns only festivals where `festival.templeId == templeId`
    - Use `:memory:` SQLite database; run ≥ 100 iterations
    - **Validates: Requirements 6.2, 6.5**
  - [x] 11.4 Write property test for Property 3: Upcoming festivals metamorphic
    - **Property 3: Upcoming Festivals Metamorphic**
    - For any limit N ≥ 0 and any mix of past/future festivals, assert `getUpcoming(N).length <= N`, all dates ≥ today, list sorted ascending
    - Use `:memory:` SQLite database; run ≥ 100 iterations
    - **Validates: Requirements 6.3, 6.6**

- [x] 12. Final checkpoint — all tests pass, no screen imports from lib/data/ except DatabaseSeeder
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure the build stays green after each screen migration
- Property tests use an in-memory SQLite database (`:memory:`) to avoid test pollution
- Unit tests and property tests are complementary — both are included
