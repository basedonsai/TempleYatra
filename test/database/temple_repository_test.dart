// Feature: temple-data-expansion, Property 4: Temple repository round-trip
//
// Validates: Requirements 6.4
//
// Insert a Temple via upsert, retrieve it via getById, and verify all
// non-null fields equal the original.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yatra_app/database/app_database.dart';
import 'package:yatra_app/database/repositories/temple_repository.dart';
import 'package:yatra_app/models/temple_model.dart';

void main() {
  setUpAll(() {
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

  // Feature: temple-data-expansion, Property 4: Temple repository round-trip
  group('Property 4 — TempleRepository round-trip', () {
    Temple _makeTemple(String suffix) {
      return Temple(
        id: 'test_temple_$suffix',
        placeId: 'place_$suffix',
        name: 'Test Temple $suffix',
        latitude: 17.0 + double.parse('0.$suffix'.substring(0, 4)),
        longitude: 78.0 + double.parse('0.$suffix'.substring(0, 4)),
        address: 'Test Address $suffix, Hyderabad',
        distinctiveFeatures: 'Distinctive features for $suffix',
        festivals: 'Festival A, Festival B',
        prasadamInfo: 'Prasadam info for $suffix',
        darshanTimings: '6:00 AM - 8:00 PM',
        region: 'Telangana',
        deityInfo: 'Lord Vishnu',
        openingHours: '6:00 AM - 8:00 PM',
        rating: 4.5,
        userRatingsTotal: 1000,
        sthalaPuranamEnglish: 'History of $suffix',
        significance: 'Significance of $suffix',
        bestTimeToVisit: 'Morning',
        dressCode: 'Traditional attire',
      );
    }

    test('upsert then getById returns temple with all fields matching', () async {
      final repo = const TempleRepository();
      final original = _makeTemple('001');

      await repo.upsert(original);
      final retrieved = await repo.getById(original.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(original.id));
      expect(retrieved.name, equals(original.name));
      expect(retrieved.placeId, equals(original.placeId));
      expect(retrieved.latitude, equals(original.latitude));
      expect(retrieved.longitude, equals(original.longitude));
      expect(retrieved.address, equals(original.address));
      expect(retrieved.distinctiveFeatures, equals(original.distinctiveFeatures));
      expect(retrieved.festivals, equals(original.festivals));
      expect(retrieved.prasadamInfo, equals(original.prasadamInfo));
      expect(retrieved.darshanTimings, equals(original.darshanTimings));
      expect(retrieved.region, equals(original.region));
      expect(retrieved.deityInfo, equals(original.deityInfo));
      expect(retrieved.openingHours, equals(original.openingHours));
      expect(retrieved.rating, equals(original.rating));
      expect(retrieved.userRatingsTotal, equals(original.userRatingsTotal));
      expect(retrieved.sthalaPuranamEnglish, equals(original.sthalaPuranamEnglish));
      expect(retrieved.significance, equals(original.significance));
      expect(retrieved.bestTimeToVisit, equals(original.bestTimeToVisit));
      expect(retrieved.dressCode, equals(original.dressCode));
    });

    test('upsert replaces existing temple on conflict', () async {
      final repo = const TempleRepository();
      final original = _makeTemple('002');
      await repo.upsert(original);

      final updated = Temple(
        id: original.id,
        placeId: original.placeId,
        name: 'Updated Temple 002',
        latitude: original.latitude,
        longitude: original.longitude,
        address: 'Updated Address',
        distinctiveFeatures: original.distinctiveFeatures,
        festivals: original.festivals,
        prasadamInfo: original.prasadamInfo,
        darshanTimings: original.darshanTimings,
      );
      await repo.upsert(updated);

      final retrieved = await repo.getById(original.id);
      expect(retrieved!.name, equals('Updated Temple 002'));
      expect(retrieved.address, equals('Updated Address'));
    });

    test('100 random temples round-trip correctly (property test)', () async {
      final repo = const TempleRepository();
      final rng = Random(99);

      for (int i = 0; i < 100; i++) {
        final id = 'prop_temple_${i.toString().padLeft(3, '0')}';
        final lat = 10.0 + rng.nextDouble() * 20;
        final lng = 70.0 + rng.nextDouble() * 20;

        final temple = Temple(
          id: id,
          placeId: 'place_$id',
          name: 'Property Temple $i',
          latitude: lat,
          longitude: lng,
          address: 'Address $i',
          distinctiveFeatures: 'Features $i',
          festivals: 'Festival $i',
          prasadamInfo: 'Prasadam $i',
          darshanTimings: '6:00 AM - 8:00 PM',
        );

        await repo.upsert(temple);
        final retrieved = await repo.getById(id);

        expect(retrieved, isNotNull, reason: 'Temple $id should be retrievable');
        expect(retrieved!.id, equals(id));
        expect(retrieved.name, equals('Property Temple $i'));
        expect(retrieved.latitude, closeTo(lat, 0.0001));
        expect(retrieved.longitude, closeTo(lng, 0.0001));
        expect(retrieved.darshanTimings, equals('6:00 AM - 8:00 PM'));
      }
    });
  });
}
