/// Smoke tests for the SQLite layer.
///
/// Run with: flutter test test/database/db_test.dart
///
/// These tests use sqflite_common_ffi so they run on desktop/CI without
/// a device. Each test gets a fresh in-memory database.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yatra_app/database/app_database.dart';
import 'package:yatra_app/database/database_seeder.dart';
import 'package:yatra_app/database/repositories/temple_repository.dart';
import 'package:yatra_app/database/repositories/festival_repository.dart';
import 'package:yatra_app/database/repositories/audio_pack_repository.dart';
import 'package:yatra_app/database/repositories/settings_repository.dart';
import 'package:yatra_app/database/repositories/community_repository.dart';
import 'package:yatra_app/database/repositories/itinerary_draft_repository.dart';
import 'package:yatra_app/models/audio_pack.dart';
import 'package:yatra_app/models/user_profile.dart';

void main() {
  setUpAll(() {
    // Use in-memory SQLite for tests — no device needed
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Each test gets a clean database
    await AppDatabase.instance.deleteDatabase();
    await AppDatabase.instance.db; // re-create tables
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  // ── Seeder ────────────────────────────────────────────────────────────────

  group('DatabaseSeeder', () {
    test('seeds temples on first call', () async {
      await DatabaseSeeder.seedIfNeeded();
      final temples = await const TempleRepository().getAll();
      expect(temples, isNotEmpty);
      expect(temples.any((t) => t.id == 'chilkur_balaji'), isTrue);
    });

    test('is idempotent — second call does not duplicate', () async {
      await DatabaseSeeder.seedIfNeeded();
      await DatabaseSeeder.seedIfNeeded(); // second call
      final temples = await const TempleRepository().getAll();
      final chilkur = temples.where((t) => t.id == 'chilkur_balaji').toList();
      expect(chilkur.length, 1);
    });

    test('seeds festivals', () async {
      await DatabaseSeeder.seedIfNeeded();
      final festivals = await const FestivalRepository().getAll();
      expect(festivals, isNotEmpty);
    });

    test('seeds audio packs with tracks', () async {
      await DatabaseSeeder.seedIfNeeded();
      final packs = await const AudioPackRepository().getAll();
      expect(packs, isNotEmpty);
      expect(packs.first.tracks, isNotEmpty);
    });
  });

  // ── TempleRepository ──────────────────────────────────────────────────────

  group('TempleRepository', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('getAll returns all seeded temples', () async {
      final temples = await const TempleRepository().getAll();
      expect(temples.length, greaterThanOrEqualTo(10));
    });

    test('getById returns correct temple', () async {
      final t = await const TempleRepository().getById('srisailam');
      expect(t, isNotNull);
      expect(t!.name, contains('Mallikarjuna'));
    });

    test('getById returns null for unknown id', () async {
      final t = await const TempleRepository().getById('does_not_exist');
      expect(t, isNull);
    });

    test('search finds by name', () async {
      final results = await const TempleRepository().search('birla');
      expect(results.any((t) => t.id == 'birla_mandir_hyderabad'), isTrue);
    });

    test('search returns all when query is empty', () async {
      final all = await const TempleRepository().getAll();
      final searched = await const TempleRepository().search('');
      expect(searched.length, all.length);
    });
  });

  // ── FestivalRepository ────────────────────────────────────────────────────

  group('FestivalRepository', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('getForTemple returns only that temple\'s festivals', () async {
      final events = await const FestivalRepository().getForTemple('srisailam');
      expect(events, isNotEmpty);
      expect(events.every((e) => e.templeId == 'srisailam'), isTrue);
    });

    test('getUpcoming returns events sorted by date', () async {
      final events = await const FestivalRepository().getUpcoming(limit: 5);
      for (int i = 1; i < events.length; i++) {
        expect(events[i].date.isAfter(events[i - 1].date) ||
               events[i].date.isAtSameMomentAs(events[i - 1].date), isTrue);
      }
    });
  });

  // ── AudioPackRepository ───────────────────────────────────────────────────

  group('AudioPackRepository', () {
    setUp(() => DatabaseSeeder.seedIfNeeded());

    test('getForTemple returns pack for chilkur', () async {
      final pack = await const AudioPackRepository().getForTemple('chilkur_balaji');
      expect(pack, isNotNull);
      expect(pack!.packId, 'pack_chilkur_balaji');
      expect(pack.tracks.length, 4);
    });

    test('updateDownloadState persists correctly', () async {
      final repo = const AudioPackRepository();
      await repo.updateDownloadState(
        packId: 'pack_chilkur_balaji',
        state: DownloadState.downloaded,
        progress: 1.0,
      );
      final pack = await repo.getByPackId('pack_chilkur_balaji');
      expect(pack!.downloadState, DownloadState.downloaded);
      expect(pack.downloadProgress, 1.0);
    });

    test('updateTrackLocalPath persists path', () async {
      final repo = const AudioPackRepository();
      await repo.updateTrackLocalPath(
        trackId: 'chilkur_balaji_history_01',
        localPath: '/data/user/0/audio_packs/chilkur_balaji_history_01.txt',
      );
      final pack = await repo.getByPackId('pack_chilkur_balaji');
      final track = pack!.tracks.firstWhere((t) => t.trackId == 'chilkur_balaji_history_01');
      expect(track.localPath, isNotNull);
    });
  });

  // ── SettingsRepository ────────────────────────────────────────────────────

  group('SettingsRepository', () {
    test('hasOnboarded defaults to false', () async {
      final v = await const SettingsRepository().hasOnboarded;
      expect(v, isFalse);
    });

    test('setHasOnboarded persists true', () async {
      final repo = const SettingsRepository();
      await repo.setHasOnboarded(true);
      expect(await repo.hasOnboarded, isTrue);
    });

    test('set/get round-trips arbitrary string', () async {
      final repo = const SettingsRepository();
      await repo.set('test_key', 'hello');
      expect(await repo.get('test_key'), 'hello');
    });
  });

  // ── CommunityRepository ───────────────────────────────────────────────────

  group('CommunityRepository', () {
    test('submitPost and getFeed round-trip', () async {
      final repo = const CommunityRepository();
      await repo.submitPost(
        title: 'My Visit',
        body: 'It was wonderful.',
        category: 'Temple Visit',
        templeId: 'chilkur_balaji',
        templeName: 'Chilkur Balaji Temple',
        authorId: 'test_user',
        authorRole: UserRole.pilgrim,
      );
      final all = await repo.getFeed();
      expect(all.any((s) => s.title == 'My Visit'), isTrue);
    });

    test('toggleLike increments like count', () async {
      final repo = const CommunityRepository();
      final id = await repo.submitPost(
        title: 'T',
        body: 'B',
        category: 'Temple Visit',
        templeId: 'srisailam',
        templeName: 'Srisailam',
        authorId: 'A',
        authorRole: UserRole.pilgrim,
      );
      await repo.toggleLike(id, false); // like it
      final all = await repo.getFeed();
      final s = all.firstWhere((s) => s.id == id);
      expect(s.likedByMe, isTrue);
      expect(s.likeCount, 1);
    });
  });

  // ── ItineraryDraftRepository ──────────────────────────────────────────────

  group('ItineraryDraftRepository', () {
    test('save and getById round-trip', () async {
      final repo = const ItineraryDraftRepository();
      final draft = ItineraryDraft(
        title: 'Weekend Yatra',
        templeIds: ['chilkur_balaji', 'birla_mandir_hyderabad'],
        numberOfDays: 1,
        maxBudget: 2000,
        travelMode: 'car',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final id = await repo.save(draft);
      final loaded = await repo.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Weekend Yatra');
      expect(loaded.templeIds, ['chilkur_balaji', 'birla_mandir_hyderabad']);
    });

    test('delete removes the draft', () async {
      final repo = const ItineraryDraftRepository();
      final id = await repo.save(ItineraryDraft(
        title: 'To Delete',
        templeIds: ['srisailam'],
        numberOfDays: 2,
        maxBudget: 0,
        travelMode: 'bus',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
    });
  });
}
