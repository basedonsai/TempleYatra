// Feature: temple-data-expansion, Property 3: Seeder idempotency
//
// Validates: Requirements 3.3, 6.3
//
// Running seedIfNeeded() twice on a fresh in-memory database must produce
// the same row count in the temples table as running it once.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yatra_app/database/app_database.dart';
import 'package:yatra_app/database/database_seeder.dart';
import 'package:yatra_app/database/repositories/temple_repository.dart';

/// Asset bundle that reads files directly from the filesystem (for tests).
class _FileAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return File(key).readAsStringSync();
  }

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.deleteDatabase();
    await AppDatabase.instance.db;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  // Feature: temple-data-expansion, Property 3: Seeder idempotency
  group('Property 3 — DatabaseSeeder idempotency', () {
    test(
      'running seedIfNeeded() twice produces the same temple row count as once',
      () async {
        final bundle = _FileAssetBundle();

        // First seed
        await DatabaseSeeder.seedIfNeeded(bundle: bundle);
        final countAfterFirst =
            (await const TempleRepository().getAll()).length;

        expect(countAfterFirst, greaterThan(0));

        // Second seed — must be a no-op for row count
        await DatabaseSeeder.seedIfNeeded(bundle: bundle);
        final countAfterSecond =
            (await const TempleRepository().getAll()).length;

        expect(
          countAfterSecond,
          equals(countAfterFirst),
          reason:
              'Second call to seedIfNeeded() must not insert duplicate rows. '
              'First count: $countAfterFirst, second count: $countAfterSecond',
        );
      },
    );

    test('v3 temples are present after seeding', () async {
      await DatabaseSeeder.seedIfNeeded(bundle: _FileAssetBundle());
      final temples = await const TempleRepository().getAll();
      // Should have more than the original 10 hardcoded temples
      expect(
        temples.length,
        greaterThan(10),
        reason: 'v3 seeding should add temples beyond the original 10',
      );
    });

    test('existing temple ids are preserved after v3 seed', () async {
      await DatabaseSeeder.seedIfNeeded(bundle: _FileAssetBundle());
      final temples = await const TempleRepository().getAll();
      final ids = temples.map((t) => t.id).toSet();

      const existingIds = [
        'chilkur_balaji',
        'jagannath_hyderabad',
        'peddamma_thalli',
        'birla_mandir_hyderabad',
        'srisailam',
      ];

      for (final id in existingIds) {
        expect(
          ids.contains(id),
          isTrue,
          reason: 'Existing temple "$id" must be preserved after v3 seeding',
        );
      }
    });
  });
}
