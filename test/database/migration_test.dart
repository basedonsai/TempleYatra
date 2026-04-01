/// Migration tests for the SQLite UI Migration spec.
///
/// Run with: flutter test test/database/migration_test.dart
///
/// Tests verify that TempleRepository and FestivalRepository behave correctly
/// for the migrated screens. Uses sqflite_common_ffi for in-memory SQLite.
library;

// Feature: sqlite-ui-migration
// Property 1: Temple seeding round-trip
// Property 2: Festival filter correctness
// Property 3: Upcoming festivals metamorphic

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yatra_app/database/app_database.dart';
import 'package:yatra_app/database/repositories/temple_repository.dart';
import 'package:yatra_app/database/repositories/festival_repository.dart';
import 'package:yatra_app/models/temple_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Temple _makeTemple(String id) => Temple(
      id: id,
      name: 'Temple $id',
      placeId: 'place_$id',
      latitude: 17.0 + id.hashCode % 10 * 0.1,
      longitude: 78.0 + id.hashCode % 10 * 0.1,
      address: 'Address $id',
      distinctiveFeatures: '',
      festivals: '',
      prasadamInfo: '',
      darshanTimings: '6am-8pm',
    );

Future<void> _insertFestival(
  String templeId,
  String name,
  DateTime date,
) async {
  final db = await AppDatabase.instance.db;
  await db.insert('festivals', {
    'temple_id': templeId,
    'name': name,
    'date': date.toIso8601String().substring(0, 10),
    'crowd_hint': 'high',
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.deleteDatabase();
    await AppDatabase.instance.db; // re-create tables
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  // ── 11.1 Unit tests for edge cases ────────────────────────────────────────
  // Requirements: 6.1, 6.2, 6.3

  group('Edge cases', () {
    test('empty DB → getAll() returns []', () async {
      final temples = await const TempleRepository().getAll();
      expect(temples, isEmpty);
    });

    test('seed one temple → getById(id) returns that temple', () async {
      final temple = _makeTemple('test_temple_1');
      await const TempleRepository().upsert(temple);

      final result = await const TempleRepository().getById('test_temple_1');
      expect(result, isNotNull);
      expect(result!.id, 'test_temple_1');
      expect(result.name, 'Temple test_temple_1');
    });

    test('getForTemple("nonexistent_id") → returns []', () async {
      final result =
          await const FestivalRepository().getForTemple('nonexistent_id');
      expect(result, isEmpty);
    });

    test('getUpcoming(0) → returns []', () async {
      // Seed a future festival
      await const TempleRepository().upsert(_makeTemple('t1'));
      await _insertFestival(
          't1', 'Future Fest', DateTime.now().add(const Duration(days: 10)));

      final result = await const FestivalRepository().getUpcoming(limit: 0);
      expect(result, isEmpty);
    });

    test('getUpcoming(3) with only 1 future festival → returns list of length 1',
        () async {
      await const TempleRepository().upsert(_makeTemple('t1'));

      // 2 past festivals
      await _insertFestival(
          't1', 'Past 1', DateTime.now().subtract(const Duration(days: 5)));
      await _insertFestival(
          't1', 'Past 2', DateTime.now().subtract(const Duration(days: 2)));
      // 1 future festival
      await _insertFestival(
          't1', 'Future 1', DateTime.now().add(const Duration(days: 7)));

      final result = await const FestivalRepository().getUpcoming(limit: 3);
      expect(result.length, 1);
      expect(result.first.name, 'Future 1');
    });
  });

  // ── 11.2 Property 1: Temple Seeding Round-Trip ────────────────────────────
  // Validates: Requirements 6.1, 6.4

  group('Property 1: Temple Seeding Round-Trip', () {
    test('for any N temples seeded, getAll() returns length == N and IDs match',
        () async {
      final rng = Random(42);

      for (int iteration = 0; iteration < 100; iteration++) {
        // Fresh DB for each iteration
        await AppDatabase.instance.deleteDatabase();
        await AppDatabase.instance.db;

        final n = rng.nextInt(20); // 0..19 temples
        final ids = List.generate(n, (i) => 'temple_${iteration}_$i');

        for (final id in ids) {
          await const TempleRepository().upsert(_makeTemple(id));
        }

        final all = await const TempleRepository().getAll();
        expect(
          all.length,
          n,
          reason: 'iteration $iteration: expected $n temples, got ${all.length}',
        );

        final returnedIds = all.map((t) => t.id).toSet();
        for (final id in ids) {
          expect(
            returnedIds.contains(id),
            isTrue,
            reason: 'iteration $iteration: id $id not found in results',
          );
        }
      }
    });
  });

  // ── 11.3 Property 2: Festival Filter Correctness ─────────────────────────
  // Validates: Requirements 6.2, 6.5

  group('Property 2: Festival Filter Correctness', () {
    test(
        'getForTemple(templeId) returns only festivals where festival.templeId == templeId',
        () async {
      final rng = Random(99);

      for (int iteration = 0; iteration < 100; iteration++) {
        // Fresh DB for each iteration
        await AppDatabase.instance.deleteDatabase();
        await AppDatabase.instance.db;

        // 2-4 temples
        final numTemples = 2 + rng.nextInt(3);
        final templeIds =
            List.generate(numTemples, (i) => 'temple_${iteration}_$i');

        for (final id in templeIds) {
          await const TempleRepository().upsert(_makeTemple(id));
        }

        // Seed 0-5 festivals per temple
        for (final tid in templeIds) {
          final count = rng.nextInt(6);
          for (int f = 0; f < count; f++) {
            final daysOffset = rng.nextInt(200) - 100;
            await _insertFestival(
              tid,
              'Fest_${tid}_$f',
              DateTime.now().add(Duration(days: daysOffset)),
            );
          }
        }

        // Pick a random templeId to query
        final queryId = templeIds[rng.nextInt(templeIds.length)];
        final results =
            await const FestivalRepository().getForTemple(queryId);

        for (final festival in results) {
          expect(
            festival.templeId,
            queryId,
            reason:
                'iteration $iteration: expected templeId=$queryId, got ${festival.templeId}',
          );
        }
      }
    });
  });

  // ── 11.4 Property 3: Upcoming Festivals Metamorphic ──────────────────────
  // Validates: Requirements 6.3, 6.6

  group('Property 3: Upcoming Festivals Metamorphic', () {
    test(
        'getUpcoming(N).length <= N, all dates >= today, list sorted ascending',
        () async {
      final rng = Random(7);
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);

      for (int iteration = 0; iteration < 100; iteration++) {
        // Fresh DB for each iteration
        await AppDatabase.instance.deleteDatabase();
        await AppDatabase.instance.db;

        await const TempleRepository().upsert(_makeTemple('t'));

        // Seed a mix of past and future festivals (0-10 total)
        final total = rng.nextInt(11);
        for (int f = 0; f < total; f++) {
          // Roughly half past, half future
          final daysOffset = rng.nextInt(60) - 30;
          await _insertFestival(
            't',
            'Fest_$f',
            today.add(Duration(days: daysOffset)),
          );
        }

        // Random limit 0-8
        final limit = rng.nextInt(9);
        final results =
            await const FestivalRepository().getUpcoming(limit: limit);

        // length <= limit
        expect(
          results.length,
          lessThanOrEqualTo(limit),
          reason: 'iteration $iteration: length ${results.length} > limit $limit',
        );

        // all dates >= today
        for (final festival in results) {
          final dateStr = festival.date.toIso8601String().substring(0, 10);
          expect(
            dateStr.compareTo(todayStr) >= 0,
            isTrue,
            reason:
                'iteration $iteration: festival date $dateStr is before today $todayStr',
          );
        }

        // sorted ascending
        for (int i = 1; i < results.length; i++) {
          expect(
            results[i].date.isAfter(results[i - 1].date) ||
                results[i].date.isAtSameMomentAs(results[i - 1].date),
            isTrue,
            reason:
                'iteration $iteration: list not sorted at index $i',
          );
        }
      }
    });
  });
}
