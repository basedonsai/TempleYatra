# Requirements Document

## Introduction

The Temple Yatra app has a complete SQLite infrastructure (Phase 1) with repositories for temples, festivals, audio packs, settings, community stories, and itinerary drafts. However, most UI screens still read data directly from hardcoded Dart lists in `lib/data/` instead of going through the repository/provider layer. This feature migrates all remaining screens to read from SQLite via Riverpod providers, while keeping the hardcoded lists as seed-only sources and preserving all existing UI behavior.

**Screens currently using hardcoded lists:**
- `home_screen.dart` — imports `allTemples` directly for Featured Yatras section and festival navigation
- `temple_list_screen.dart` — imports `allTemples` directly for the full temple list
- `yatra_planner_screen.dart` — imports `allTemples` directly as `_availableTemples`
- `map_screen.dart` — imports `allTemples` directly for markers and bottom sheet
- `offline_pack_manager_screen.dart` — imports `allTemples` to resolve temple name on Play button
- `temple_calendar_screen.dart` — imports `allFestivalEvents` directly for crowd computation
- `providers/festival_provider.dart` — reads `allFestivalEvents` directly instead of SQLite

**Screens already migrated (no changes needed):**
- `community_screen.dart` — uses `communityFeedProvider`
- `temple_detail_screen.dart` — receives `Temple` object via constructor; uses `templeFestivalsProvider`
- `profile_screen.dart`, `profile_setup_screen.dart` — use `currentUserProvider`

## Glossary

- **App**: The Temple Yatra Flutter + Riverpod mobile application
- **SQLite_Layer**: The sqflite-backed database accessed through repository classes
- **Hardcoded_List**: A Dart `const` or `final` list defined in `lib/data/` (e.g. `allTemples`, `allFestivalEvents`, `allAudioPacks`)
- **Repository**: A class in `lib/database/repositories/` that reads/writes a single entity type from SQLite
- **Provider**: A Riverpod provider defined in `lib/database/db_providers.dart` that exposes repository data to the UI
- **Seed_Source**: A hardcoded list used exclusively by `DatabaseSeeder` to populate SQLite on first launch
- **TempleRepository**: Repository for the `temples` table; exposes `getAll()`, `getById()`, `search()`
- **FestivalRepository**: Repository for the `festivals` table; exposes `getForTemple()`, `getUpcoming()`
- **AudioPackRepository**: Repository for the `audio_packs` and `audio_tracks` tables
- **allTemplesDbProvider**: `FutureProvider<List<Temple>>` backed by `TempleRepository.getAll()`
- **templeFestivalsDbProvider**: `FutureProvider.family<List<FestivalEvent>, String>` backed by `FestivalRepository.getForTemple()`
- **upcomingFestivalsDbProvider**: `FutureProvider.family<List<FestivalEvent>, int>` backed by `FestivalRepository.getUpcoming()`
- **festivalProvider**: Legacy `Provider<List<FestivalEvent>>` in `lib/providers/festival_provider.dart` — to be re-backed by SQLite
- **templeFestivalsProvider**: Legacy `Provider.family` in `lib/providers/festival_provider.dart` — to be re-backed by SQLite
- **DatabaseSeeder**: Class that seeds all hardcoded data into SQLite on first launch; idempotent
- **CrowdEngine**: Stateless service that computes crowd level from a temple id, date, and festival list

---

## Requirements

### Requirement 1: Temple Data Source Migration

**User Story:** As a developer, I want all temple-listing screens to read from SQLite via `allTemplesDbProvider`, so that the UI always reflects the database state and hardcoded lists are no longer imported by screens.

#### Acceptance Criteria

1. THE `temple_list_screen.dart` SHALL import `allTemplesDbProvider` from `db_providers.dart` and remove its import of `allTemples` from `temples_data.dart`.
2. WHEN `allTemplesDbProvider` is in the loading state, THE `TempleListScreen` SHALL display a `CircularProgressIndicator` in place of the temple list.
3. WHEN `allTemplesDbProvider` resolves with data, THE `TempleListScreen` SHALL display the same temple cards as before, with search and filter behavior unchanged.
4. IF `allTemplesDbProvider` resolves with an error, THEN THE `TempleListScreen` SHALL display an error message to the user.
5. THE `home_screen.dart` SHALL import `allTemplesDbProvider` and remove its import of `allTemples` from `temples_data.dart`.
6. WHEN `allTemplesDbProvider` resolves with data, THE `HomeScreen` SHALL render the Featured Yatras horizontal list using the database-sourced temple list.
7. WHEN `allTemplesDbProvider` is loading in `HomeScreen`, THE Featured Yatras section SHALL display a loading placeholder instead of crashing.
8. THE `yatra_planner_screen.dart` SHALL read available temples from `allTemplesDbProvider` and remove its direct reference to `allTemples`.
9. WHEN `allTemplesDbProvider` resolves, THE `YatraPlannerScreen` SHALL populate the temple selection chips with the database-sourced list.
10. THE `map_screen.dart` SHALL read temple data from `allTemplesDbProvider` and remove its import of `allTemples` from `temples_data.dart`.
11. WHEN `allTemplesDbProvider` resolves in `MapScreen`, THE map markers and bottom-sheet temple list SHALL reflect the database-sourced temple list.

### Requirement 2: Festival Data Source Migration

**User Story:** As a developer, I want all festival-related providers and screens to read from SQLite via `templeFestivalsDbProvider` and `upcomingFestivalsDbProvider`, so that festival data is consistent with the database.

#### Acceptance Criteria

1. THE `festivalProvider` in `festival_provider.dart` SHALL be re-implemented to delegate to `templeFestivalsDbProvider` or `upcomingFestivalsDbProvider` from `db_providers.dart`, removing its direct dependency on `allFestivalEvents` from `festival_data.dart`.
2. THE `templeFestivalsProvider` in `festival_provider.dart` SHALL delegate to `templeFestivalsDbProvider` so that all existing call sites (`temple_detail_screen`, `route_planner_screen`, `yatra_planner_screen`) continue to work without modification.
3. THE `temple_calendar_screen.dart` SHALL remove its direct import of `allFestivalEvents` from `festival_data.dart` and use only the provider-sourced festival list for crowd computation.
4. WHEN `templeFestivalsProvider` is called with a `templeId`, THE `TempleCalendarScreen` SHALL display the same upcoming festival list as before.
5. THE `HomeScreen` festivals section SHALL read upcoming festivals from `upcomingFestivalsDbProvider` instead of `festivalProvider` backed by hardcoded data.
6. WHEN `upcomingFestivalsDbProvider` resolves, THE `HomeScreen` SHALL display the next 3 upcoming festivals sorted by date, identical in appearance to the current behavior.
7. IF `upcomingFestivalsDbProvider` resolves with an empty list, THEN THE `HomeScreen` SHALL display the existing "No upcoming festivals found." message.

### Requirement 3: Audio Pack Temple Name Resolution

**User Story:** As a developer, I want the `OfflinePackManagerScreen` to resolve temple names from SQLite instead of importing `allTemples` directly, so that the audio pack UI is consistent with the database.

#### Acceptance Criteria

1. THE `offline_pack_manager_screen.dart` SHALL remove its import of `allTemples` from `temples_data.dart`.
2. WHEN the Play button is tapped on a downloaded audio pack, THE `OfflinePackManagerScreen` SHALL resolve the `Temple` object by reading from `allTemplesDbProvider` (or `templeByIdDbProvider`) instead of calling `allTemples.firstWhere(...)`.
3. IF no matching temple is found in the database for a given `templeId`, THEN THE `OfflinePackManagerScreen` SHALL navigate to `StorytellingScreen` using only the `templeId` string, without crashing.
4. THE existing download, cancel, delete, and retry controls in `OfflinePackManagerScreen` SHALL remain functionally unchanged after the migration.

### Requirement 4: Seed Lists Remain Seed-Only

**User Story:** As a developer, I want the hardcoded data lists in `lib/data/` to be used exclusively by `DatabaseSeeder`, so that no screen or provider imports them directly.

#### Acceptance Criteria

1. THE `temples_data.dart` file SHALL be imported only by `DatabaseSeeder` and test files after the migration is complete.
2. THE `festival_data.dart` file SHALL be imported only by `DatabaseSeeder` and test files after the migration is complete.
3. THE `audio_pack_data.dart` file SHALL be imported only by `DatabaseSeeder`, `AudioPackService`, and test files after the migration is complete.
4. THE `DatabaseSeeder` SHALL remain the sole writer of seed data to SQLite, with no changes to its seeding logic or idempotency guarantees.

### Requirement 5: Behavioral Preservation

**User Story:** As a pilgrim user, I want all screens to look and behave exactly as before the migration, so that the SQLite wiring is invisible to me.

#### Acceptance Criteria

1. THE `App` SHALL preserve all existing navigation flows between screens after the migration.
2. WHEN a screen previously displayed N temples from the hardcoded list, THE same screen SHALL display the same N temples after migration (because the seeder populates SQLite with the same data).
3. THE crowd level indicators on temple cards, the yatra planner, and the route planner SHALL continue to compute correctly using festival data sourced from SQLite.
4. THE search and filter functionality in `TempleListScreen` SHALL operate on the database-sourced list with the same results as before.
5. THE `TempleDetailScreen` SHALL continue to receive a `Temple` object via its constructor and SHALL NOT be modified as part of this migration.
6. WHEN the app is launched for the first time after the migration, THE `DatabaseSeeder` SHALL seed all temple, festival, and audio pack data before any screen attempts to read from SQLite.

### Requirement 6: Focused Tests for Migrated Screens

**User Story:** As a developer, I want focused tests that verify the migrated screens read from the repository layer, so that regressions are caught early.

#### Acceptance Criteria

1. THE test suite SHALL include a test that verifies `TempleRepository.getAll()` returns the same temples that were seeded by `DatabaseSeeder`.
2. THE test suite SHALL include a test that verifies `FestivalRepository.getForTemple(templeId)` returns the correct festivals for a given temple after seeding.
3. THE test suite SHALL include a test that verifies `FestivalRepository.getUpcoming(limit)` returns festivals sorted by date with the correct count.
4. FOR ALL temples seeded by `DatabaseSeeder`, reading back via `TempleRepository.getAll()` SHALL return a list of equal length (round-trip property).
5. FOR ALL festivals seeded by `DatabaseSeeder`, reading back via `FestivalRepository.getForTemple(templeId)` SHALL return only festivals matching that `templeId` (filter correctness property).
6. WHEN `FestivalRepository.getUpcoming(3)` is called, THE result SHALL contain at most 3 items and each item's date SHALL be on or after today (metamorphic property).
