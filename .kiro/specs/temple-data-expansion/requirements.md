# Requirements Document

## Introduction

The Temple Yatra app currently ships with 10 hardcoded temples covering Hyderabad and Telangana. This feature expands temple coverage significantly by importing and normalizing data from the `rishabhmodi03/hindu-temples` GitHub dataset, seeds the expanded set into SQLite, and ensures all existing screens and providers work correctly with the larger dataset. No backend is introduced; SQLite remains the local source of truth. No existing working features are redesigned.

The work is organized into six checkpoints:
1. Audit hardcoded data reads
2. Build the import/normalization pipeline
3. Update SQLite seeding
4. Wire UI to database-backed providers (remove any remaining direct reads)
5. Make the app more dynamic and robust with the expanded dataset
6. Minimal focused tests

---

## Glossary

- **Temple_Dataset**: The read-only external source at `https://github.com/rishabhmodi03/hindu-temples`, containing `data/deities.json` and `data/states.json`.
- **Canonical_Temple_Id**: A snake_case string derived from the temple name — lowercase, spaces and special characters replaced with underscores, diacritics stripped. Example: "Birla Mandir, Hyderabad" → `birla_mandir_hyderabad`.
- **Importer**: The Dart class (`TempleDataImporter`) responsible for reading the Temple_Dataset JSON files and producing normalized `Temple` objects.
- **Seeder**: `DatabaseSeeder` in `lib/database/database_seeder.dart` — inserts seed data into SQLite on first launch per seed version.
- **Seed_Version**: An integer tracked in the `seeded_versions` SQLite table. Each new batch of seed data uses a new version number so seeding is idempotent.
- **Temple_Repository**: `TempleRepository` in `lib/database/repositories/temple_repository.dart` — the only class that issues SQL against the `temples` table.
- **allTemplesDbProvider**: `FutureProvider<List<Temple>>` in `lib/database/db_providers.dart` — the canonical runtime source of all temples for UI screens.
- **templeFestivalsDbProvider**: `FutureProvider.family<List<FestivalEvent>, String>` — the canonical runtime source of festivals per temple.
- **Festival_Seed**: Festival entries in `lib/data/festival_data.dart` that are inserted into the `festivals` SQLite table by the Seeder.
- **templeId**: The `id` field on the `Temple` model and the `temple_id` foreign key in `festivals`, `audio_packs`, and `community_stories` tables.

---

## Requirements

### Requirement 1: Hardcoded Data Audit

**User Story:** As a developer, I want a complete audit of every place where hardcoded temple or festival lists are read directly in UI or service code, so that I know exactly what needs to be migrated to provider-backed reads.

#### Acceptance Criteria

1. THE Importer SHALL produce a written list of every Dart file that imports `lib/data/temples_data.dart`, `lib/data/festival_data.dart`, or `lib/data/audio_pack_data.dart` outside of `database_seeder.dart`.
2. WHEN a screen or service imports a hardcoded data file directly, THE Importer SHALL flag it as a migration target.
3. THE Importer SHALL confirm that `allTemplesDbProvider`, `templeFestivalsDbProvider`, and `upcomingFestivalsDbProvider` are the only runtime data paths used by screens after migration.
4. IF a hardcoded import is found in a screen file, THEN THE Seeder SHALL NOT be modified until the screen import is removed first.

---

### Requirement 2: Import and Normalization Pipeline

**User Story:** As a developer, I want a Dart-based import pipeline that reads the Temple_Dataset JSON files and produces normalized `Temple` objects, so that I can expand temple coverage without manual data entry.

#### Acceptance Criteria

1. THE Importer SHALL read `data/deities.json` and `data/states.json` from the Temple_Dataset as static assets bundled with the app (placed in `assets/temple_dataset/`).
2. WHEN a temple entry is read from the Temple_Dataset, THE Importer SHALL produce a `Temple` object with all required fields populated: `id`, `name`, `latitude`, `longitude`, `address`, `distinctiveFeatures`, `darshanTimings`, `prasadamInfo`, `festivals` (text), `region`, `deityInfo`.
3. WHEN a required field is missing in the source data, THE Importer SHALL substitute a safe fallback value (empty string for text fields, `0.0` for coordinates that are genuinely unknown, `'6:00 AM - 8:00 PM'` for missing darshan timings).
4. THE Importer SHALL derive the `Canonical_Temple_Id` for each temple using the normalization rule: lowercase the name, replace all non-alphanumeric characters with underscores, collapse consecutive underscores to one, strip leading/trailing underscores.
5. WHEN two temples produce the same `Canonical_Temple_Id`, THE Importer SHALL keep the entry with more non-null fields and discard the duplicate.
6. THE Importer SHALL preserve all 10 existing temples by their current `templeId` values — existing ids SHALL NOT be changed.
7. THE Importer SHALL NOT depend on any Python scripts at runtime; it SHALL read the JSON files directly in Dart.
8. WHEN the Temple_Dataset contains a temple already present in the existing seed (matched by `Canonical_Temple_Id`), THE Importer SHALL merge additional fields from the dataset into the existing entry without overwriting non-null fields already present.

---

### Requirement 3: SQLite Seeding

**User Story:** As a developer, I want the expanded temple dataset seeded into SQLite idempotently, so that existing user data is preserved and the app works correctly on first launch and on updates.

#### Acceptance Criteria

1. THE Seeder SHALL insert expanded temple data under a new `Seed_Version` (version 3) so that devices already seeded at version 1 or 2 receive the new temples without re-running earlier seeds.
2. WHEN the Seeder runs for version 3, THE Seeder SHALL use `ConflictAlgorithm.ignore` for temple rows so that any user-modified temple data is not overwritten.
3. WHEN the Seeder runs for version 3 a second time on the same device, THE Seeder SHALL insert zero new rows (idempotent).
4. THE Seeder SHALL also insert `Festival_Seed` entries for all newly added temples under the same version 3 transaction.
5. WHEN seeding completes, THE Seeder SHALL call `AppDatabase.markSeeded(3)` to record the version.
6. THE Seeder SHALL NOT modify the `community_stories`, `user_profiles`, `itinerary_drafts`, or `audio_packs` tables during version 3 seeding.
7. WHILE the Seeder is running, THE AppDatabase SHALL hold a single transaction so that a partial failure leaves the database unchanged.

---

### Requirement 4: UI Provider Wiring

**User Story:** As a developer, I want all screens to read temple and festival data exclusively from Riverpod providers backed by SQLite, so that the expanded dataset is automatically reflected everywhere without per-screen changes.

#### Acceptance Criteria

1. THE Temple_Repository SHALL be the only class that issues SQL against the `temples` table; no screen or service SHALL import `lib/data/temples_data.dart` for runtime display.
2. WHEN `TempleListScreen` renders, THE allTemplesDbProvider SHALL supply the full list of temples including all newly seeded entries.
3. WHEN `YatraPlannerScreen` renders the temple selector, THE allTemplesDbProvider SHALL supply all temples so the user can select from the expanded set.
4. WHEN `CommunityScreen` renders the temple filter dropdown, THE allTemplesDbProvider SHALL supply all temples including newly seeded ones.
5. WHEN `HomeScreen` renders the Featured Yatras section, THE allTemplesDbProvider SHALL supply temples from SQLite, not from the hardcoded list.
6. WHEN `AllFestivalsScreen` renders, THE upcomingFestivalsDbProvider SHALL return festivals for all temples including newly seeded ones.
7. WHEN `TempleCalendarScreen` is opened for any temple in the expanded set, THE templeFestivalsDbProvider SHALL return that temple's festivals from SQLite.
8. IF `allTemplesDbProvider` is in the loading state, THEN THE screen SHALL show a `CircularProgressIndicator` rather than an empty list.
9. IF `allTemplesDbProvider` returns an error, THEN THE screen SHALL show an error message with a retry option.

---

### Requirement 5: Dynamic and Robust Behavior

**User Story:** As a user, I want the app to work correctly for all temples in the expanded dataset, so that festival calendars, community grouping, itinerary planning, and route planning are not limited to the original 10 temples.

#### Acceptance Criteria

1. WHEN `TempleCalendarScreen` is opened for any temple that has festival rows in SQLite, THE screen SHALL display those festivals and SHALL NOT show "No upcoming festivals scheduled" while the data is loading.
2. WHEN `computeCrowdLevel` is called for any `templeId` in the expanded set, THE crowd_engine SHALL return a valid `CrowdLevel` based on that temple's festival data from SQLite.
3. WHEN a user selects a temple filter in `CommunityScreen`, THE feed SHALL show only posts whose `templeId` matches the selected temple, for any temple in the expanded set.
4. WHEN `ItineraryGenerator` generates a day plan with N > 1 temples from the expanded set, THE arrival time for temple i SHALL equal `departureTime[i-1] + travelTime[i]` for all i in [1, N-1].
5. WHEN `RoutePlannerScreen` renders the statistics row, THE row SHALL distribute space evenly across all screen widths without overflow.
6. WHEN `_PostCard` renders the author row on a screen narrower than 360 dp, THE row SHALL NOT throw a RenderFlex overflow error.
7. WHEN `TempleDetailScreen` renders a festival row with a long festival name, THE festival name SHALL be ellipsized rather than overflowing.
8. WHEN `_updateUserPosition` receives a GPS update and `_isReRoutingInProgress` is false, THE route planner SHALL call `_checkRouteDeviation` to detect off-route movement without waiting for the periodic timer.
9. WHEN `_checkRouteDeviation` determines movement is less than 50 m, THE `_lastCheckedPosition` SHALL NOT be updated, so cumulative movement is measured from the last full check.

---

### Requirement 6: Minimal Focused Tests

**User Story:** As a developer, I want a small set of focused tests that verify the importer, seeder idempotency, and repository round-trips, so that I can confirm correctness without a large test suite.

#### Acceptance Criteria

1. THE Importer SHALL have a unit test that verifies `Canonical_Temple_Id` normalization: given a temple name with spaces, diacritics, and special characters, the output id is valid snake_case with no consecutive underscores.
2. THE Importer SHALL have a property test that verifies: for any temple produced by the Importer, all required fields (`id`, `name`, `latitude`, `longitude`, `darshanTimings`) are non-null and non-empty.
3. THE Seeder SHALL have an integration test that verifies: running `seedIfNeeded()` twice on a fresh in-memory database produces the same row count in the `temples` table as running it once (idempotency).
4. THE Temple_Repository SHALL have a round-trip test: insert a `Temple` via `upsert`, retrieve it via `getById`, and verify all fields match.
5. THE ItineraryGenerator SHALL have a unit test that verifies: for a 3-temple day, all arrival and departure times are strictly monotonically increasing.
6. WHEN the importer test runs, THE test SHALL NOT make any network calls; it SHALL read from the bundled asset files only.
