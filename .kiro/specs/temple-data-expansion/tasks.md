# Implementation Plan: Temple Data Expansion

## Overview

Expand temple coverage from 10 hardcoded entries to the full `rishabhmodi03/hindu-temples` dataset.
Steps: bundle assets → build importer → seed v3 → fix UI robustness → write 6 focused tests.

## Tasks

- [x] 1. Bundle dataset assets and create TempleDataImporter
  - [x] 1.1 Add dataset JSON files and register in pubspec.yaml
    - Copy `deities.json` and `states.json` into `assets/temple_dataset/`
    - Add both paths under `flutter: assets:` in `pubspec.yaml`
    - _Requirements: 2.1_

  - [x] 1.2 Implement `TempleDataImporter` in `lib/data/temple_data_importer.dart`
    - Implement `deriveId(String name)` — lowercase, replace `[^a-z0-9]+` with `_`, collapse `_+`, strip leading/trailing `_`
    - Implement `load({required List<Temple> existingTemples, AssetBundle? bundle})` — reads both asset files via `rootBundle`, normalizes each entry to a `Temple` with fallbacks per Req 2.3, deduplicates by canonical id (keep entry with more non-null fields on collision), merges with existing temples (existing non-null fields win), appends new temples
    - Implement `merge(Temple existing, Temple incoming)` — each field is `existing.field ?? incoming.field`
    - Field mapping: `name`/`temple_name` → `name`; `latitude`/`lat` → `latitude` (fallback `0.0`); `longitude`/`lng` → `longitude` (fallback `0.0`); `address`/`location` → `address`; `deity`/`main_deity` → `deityInfo`; `state` → `region`; `description`/`about` → `distinctiveFeatures`; `timings`/`darshan_timings` → `darshanTimings` (fallback `'6:00 AM - 8:00 PM'`); `prasadam` → `prasadamInfo`; `festivals` → `festivals`; `placeId` = `''`
    - Skip entries with no `name` field
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

  - [x] 1.3 Write property test for `deriveId` (Property 1)
    - `// Feature: temple-data-expansion, Property 1: Canonical id is valid snake_case`
    - File: `test/data/temple_data_importer_test.dart`
    - Generator: random strings from printable ASCII + Unicode letters, length 1–100, ≥ 100 iterations
    - Assert: result matches `[a-z0-9_]+`, no `__`, no leading/trailing `_`, non-empty
    - **Property 1: Canonical id is valid snake_case**
    - **Validates: Requirements 2.4, 6.1**

  - [x] 1.4 Write property test for required fields after import (Property 2)
    - `// Feature: temple-data-expansion, Property 2: All required fields populated`
    - File: `test/data/temple_data_importer_test.dart`
    - Load real asset files; for each produced `Temple` assert `id`, `name`, `darshanTimings` are non-empty strings; `latitude` and `longitude` are non-null doubles
    - **Property 2: All required fields are populated after import**
    - **Validates: Requirements 2.2, 2.3, 6.2**

  - [x] 1.5 Write example test for `load()` asset reads (T6)
    - File: `test/data/temple_data_importer_test.dart`
    - Use `TestWidgetsFlutterBinding.ensureInitialized()`; call `TempleDataImporter.load(existingTemples: allTemples)`; assert all 10 existing temple ids are present in output; assert no `http` package is imported in importer
    - **Validates: Requirements 2.6, 6.6**

- [x] 2. Add seed version 3 to DatabaseSeeder
  - [x] 2.1 Implement `_seedV3Temples` and `_seedV3Festivals` in `lib/database/database_seeder.dart`
    - Add `static const int _seedVersion3 = 3;`
    - In `seedIfNeeded()`, after the v2 block, add a v3 block: call `TempleDataImporter.load(existingTemples: allTemples)`, wrap inserts in a single `db.transaction`, call `appDb.markSeeded(3)` only after the transaction commits
    - `_seedV3Temples`: iterate imported temples, `batch.insert('temples', ..., conflictAlgorithm: ConflictAlgorithm.ignore)` — reuse the same column map as `_seedTemples`
    - `_seedV3Festivals`: for each imported temple with a non-empty `festivals` text field, split by comma, insert one row per festival name with `date: '2026-01-01'` and `crowd_hint: 'high'`, using `ConflictAlgorithm.ignore`
    - Do NOT touch `community_stories`, `user_profiles`, `itinerary_drafts`, `audio_packs`, `audio_tracks`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [x] 2.2 Write seeder idempotency integration test (Property 3)
    - `// Feature: temple-data-expansion, Property 3: Seeder idempotency`
    - File: `test/database/database_seeder_test.dart`
    - Use `sqflite_common_ffi` in-memory DB; call `seedIfNeeded()`, record `temples` row count; call `seedIfNeeded()` again; assert row count is identical
    - **Property 3: Seeder idempotency**
    - **Validates: Requirements 3.3, 6.3**

- [x] 3. Checkpoint — ensure seeding works end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Fix UI robustness issues
  - [x] 4.1 Fix `RoutePlannerScreen` statistics row overflow (Req 5.5)
    - Locate the statistics row widget; wrap children in `Expanded` or use `Flexible` so space is distributed evenly across all screen widths
    - _Requirements: 5.5_

  - [x] 4.2 Fix `_PostCard` author row overflow on narrow screens (Req 5.6)
    - Locate the author row in `_PostCard`; wrap the author name `Text` in `Flexible` or `Expanded` to prevent `RenderFlex` overflow below 360 dp
    - _Requirements: 5.6_

  - [x] 4.3 Fix `TempleDetailScreen` festival name overflow (Req 5.7)
    - Locate the festival name `Text` widget in `TempleDetailScreen`; add `overflow: TextOverflow.ellipsis` and `maxLines: 1` (or appropriate value)
    - _Requirements: 5.7_

  - [x] 4.4 Fix route planner GPS deviation check (Req 5.8, 5.9)
    - In `_updateUserPosition`, after updating position, call `_checkRouteDeviation()` immediately when `_isReRoutingInProgress` is false
    - In `_checkRouteDeviation`, only update `_lastCheckedPosition` when cumulative movement ≥ 50 m
    - _Requirements: 5.8, 5.9_

- [x] 5. Add TempleRepository round-trip test and ItineraryGenerator timing test
  - [x] 5.1 Write `TempleRepository` round-trip test (Property 4)
    - `// Feature: temple-data-expansion, Property 4: Temple repository round-trip`
    - File: `test/database/temple_repository_test.dart`
    - Use `sqflite_common_ffi` in-memory DB; generate a `Temple` with all fields populated; call `upsert(temple)`; call `getById(temple.id)`; assert all non-null fields equal the original
    - **Property 4: Temple repository round-trip**
    - **Validates: Requirements 6.4**

  - [x] 5.2 Write `ItineraryGenerator` monotonic timing test (Property 5)
    - `// Feature: temple-data-expansion, Property 5: Arrival/departure times strictly increasing`
    - File: `test/services/itinerary_generator_test.dart`
    - Generate random lists of 2–8 temple ids from the seeded set with a random start time, ≥ 100 iterations; assert `arrival[i] < departure[i] < arrival[i+1]` for all valid i
    - **Property 5: Itinerary arrival times are monotonically increasing**
    - **Validates: Requirements 5.4, 6.5**

- [x] 6. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests run ≥ 100 iterations each
- `sqflite_common_ffi` is already in `dev_dependencies` — use it for all in-memory DB tests
- The `festivals` table uses an autoincrement PK so `ConflictAlgorithm.ignore` on duplicate inserts is safe
