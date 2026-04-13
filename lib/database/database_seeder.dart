/// DatabaseSeeder — inserts hardcoded data into SQLite on first launch.
///
/// Runs inside a single transaction per seed version so it is atomic.
/// Safe to call on every app start — it checks [AppDatabase.isSeeded] first.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../data/temples_data.dart';
import '../data/festival_data.dart';
import '../data/audio_pack_data.dart';
import '../models/festival_event.dart';
import '../models/audio_pack.dart';

class DatabaseSeeder {
  const DatabaseSeeder._();

  static const int _seedVersion = 1;
  static const int _seedVersion2 = 2;

  /// Entry point. Call once from [main] after [AppDatabase] is ready.
  static Future<void> seedIfNeeded() async {
    final appDb = AppDatabase.instance;

    if (!await appDb.isSeeded(_seedVersion)) {
      debugPrint('[DatabaseSeeder] Seeding v$_seedVersion…');
      final db = await appDb.db;
      await db.transaction((txn) async {
        await _seedTemples(txn);
        await _seedFestivals(txn);
        await _seedAudioPacks(txn);
      });
      await appDb.markSeeded(_seedVersion);
      debugPrint('[DatabaseSeeder] Seed v$_seedVersion complete.');
    }

    if (!await appDb.isSeeded(_seedVersion2)) {
      debugPrint('[DatabaseSeeder] Seeding v$_seedVersion2…');
      final db = await appDb.db;
      await db.transaction((txn) async {
        await _seedDemoActors(txn);
        await _seedDemoPosts(txn);
      });
      await appDb.markSeeded(_seedVersion2);
      debugPrint('[DatabaseSeeder] Seed v$_seedVersion2 complete.');
    }
  }

  // ── Temples ───────────────────────────────────────────────────────────────

  static Future<void> _seedTemples(Transaction txn) async {
    final batch = txn.batch();
    for (final t in allTemples) {
      batch.insert(
        'temples',
        {
          'id': t.id,
          'place_id': t.placeId,
          'name': t.name,
          'latitude': t.latitude,
          'longitude': t.longitude,
          'address': t.address,
          'distinctive_features': t.distinctiveFeatures,
          'festivals': t.festivals,
          'prasadam_info': t.prasadamInfo,
          'darshan_timings': t.darshanTimings,
          'opening_hours': t.openingHours,
          'rating': t.rating,
          'user_ratings_total': t.userRatingsTotal,
          'phone_number': t.phoneNumber,
          'website': t.website,
          'estimated_visit_minutes': t.estimatedVisitDurationMinutes,
          'primary_language': t.primaryLanguage,
          'region': t.region,
          'deity_info': t.deityInfo,
          'sthala_puranam': t.sthalaPuranam,
          'sthala_puranam_en': t.sthalaPuranamEnglish,
          'sthala_puranam_hi': t.sthalaPuranamHindi,
          'sthala_puranam_ta': t.sthalaPuranamTamil,
          'sthala_puranam_te': t.sthalaPuranamTelugu,
          'rituals': t.rituals,
          'rituals_en': t.ritualsEnglish,
          'mantras': t.mantras,
          'significance': t.significance,
          'best_time_to_visit': t.bestTimeToVisit,
          'dress_code': t.dressCode,
          'temple_history': t.templeHistory,
          'architecture_info': t.architectureInfo,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Festivals ─────────────────────────────────────────────────────────────

  static Future<void> _seedFestivals(Transaction txn) async {
    final batch = txn.batch();
    for (final f in allFestivalEvents) {
      batch.insert(
        'festivals',
        {
          'temple_id': f.templeId,
          'name': f.name,
          'date': f.date.toIso8601String(),
          'crowd_hint': _crowdLevelToString(f.crowdHint),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Audio packs ───────────────────────────────────────────────────────────

  static Future<void> _seedAudioPacks(Transaction txn) async {
    final batch = txn.batch();
    for (final pack in allAudioPacks) {
      batch.insert(
        'audio_packs',
        {
          'pack_id': pack.packId,
          'temple_id': pack.templeId,
          'title': pack.title,
          'description': pack.description,
          'total_size_bytes': pack.totalSizeBytes,
          'download_state': pack.downloadState.name,
          'download_progress': pack.downloadProgress,
          'error_message': pack.errorMessage,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (int i = 0; i < pack.tracks.length; i++) {
        final track = pack.tracks[i];
        batch.insert(
          'audio_tracks',
          {
            'track_id': track.trackId,
            'pack_id': pack.packId,
            'title': track.title,
            'category': track.category.name,
            'duration_seconds': track.durationSeconds,
            'file_size_bytes': track.fileSizeBytes,
            'local_path': track.localPath,
            'sort_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _crowdLevelToString(CrowdLevel level) => level.name;

  // ── Demo actors ───────────────────────────────────────────────────────────

  static const _demoActors = [
    {'id': 'demo_admin_01',   'display_name': 'Swami Raghavendra', 'role': 'admin',   'avatar_seed': 0},
    {'id': 'demo_local_01',   'display_name': 'Lakshmi Devi',      'role': 'local',   'avatar_seed': 3},
    {'id': 'demo_local_02',   'display_name': 'Venkat Rao',        'role': 'local',   'avatar_seed': 7},
    {'id': 'demo_pilgrim_01', 'display_name': 'Priya Sharma',      'role': 'pilgrim', 'avatar_seed': 2},
    {'id': 'demo_pilgrim_02', 'display_name': 'Amit Patel',        'role': 'pilgrim', 'avatar_seed': 5},
    {'id': 'demo_pilgrim_03', 'display_name': 'Sneha Reddy',       'role': 'pilgrim', 'avatar_seed': 8},
  ];

  static Future<void> _seedDemoActors(Transaction txn) async {
    for (final actor in _demoActors) {
      await txn.insert(
        'user_profiles',
        {
          'id': actor['id'],
          'display_name': actor['display_name'],
          'avatar_seed': actor['avatar_seed'],
          'role': actor['role'],
          'is_demo': 1,
          'created_at': '2026-01-01T00:00:00.000',
          'updated_at': '2026-01-01T00:00:00.000',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ── Demo posts ────────────────────────────────────────────────────────────

  static final _demoPosts = [
    {
      'author_id': 'demo_admin_01',
      'author_role': 'admin',
      'temple_id': 'chilkur_balaji',
      'temple_name': 'Chilkur Balaji Temple',
      'title': 'Welcome to the TempleYatra Community',
      'body': 'Namaste to all pilgrims! This is a space to share your spiritual experiences, travel tips, and temple stories. Please be respectful and authentic. May your yatra be blessed.',
      'category': 'Temple Visit',
      'status': 'published',
      'is_pinned': 1,
      'created_at': '2026-01-01T08:00:00.000',
    },
    {
      'author_id': 'demo_local_01',
      'author_role': 'local',
      'temple_id': 'chilkur_balaji',
      'temple_name': 'Chilkur Balaji Temple',
      'title': 'Best time to visit Chilkur Balaji — local tip',
      'body': 'I live near Chilkur and visit every Friday. The best time is 6–8 AM before the crowds arrive. Avoid Saturdays during Brahmotsavam — the queue can be 4+ hours. The prasadam is free and the priests are very welcoming.',
      'category': 'Local Traditions',
      'status': 'published',
      'is_pinned': 1,
      'created_at': '2026-01-05T07:30:00.000',
    },
    {
      'author_id': 'demo_pilgrim_01',
      'author_role': 'pilgrim',
      'temple_id': 'srisailam',
      'temple_name': 'Sri Mallikarjuna Swamy Temple, Srisailam',
      'title': 'My Mahashivaratri experience at Srisailam',
      'body': 'We drove from Hyderabad at midnight to reach Srisailam by 4 AM for the Bela Prabha darshan. The forest road is beautiful in the dark. The abhishekam during Mahashivaratri is something I will never forget. Highly recommend staying overnight in the forest guesthouse.',
      'category': 'Festival Experience',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-02-28T10:00:00.000',
    },
    {
      'author_id': 'demo_pilgrim_02',
      'author_role': 'pilgrim',
      'temple_id': 'birla_mandir_hyderabad',
      'temple_name': 'Birla Mandir, Hyderabad',
      'title': 'Birla Mandir at sunset — worth every step',
      'body': 'Climbed the steps to Birla Mandir just before sunset. The view of Hussain Sagar from the top is stunning. The white marble glows in the evening light. The museum inside has excellent exhibits on the Bhagavad Gita. Entry is free.',
      'category': 'Temple Visit',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-03-10T17:00:00.000',
    },
    {
      'author_id': 'demo_local_02',
      'author_role': 'local',
      'temple_id': 'peddamma_thalli',
      'temple_name': 'Sri Peddamma Thalli Temple',
      'title': 'Bonalu 2026 — what to expect',
      'body': 'Bonalu at Peddamma Thalli is the biggest festival in Jubilee Hills. Thousands of women carry decorated pots on their heads. The procession starts at 6 AM. Parking is impossible — take the metro to Jubilee Hills Check Post and walk 10 minutes. Bring water, it gets very crowded.',
      'category': 'Festival Experience',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-07-15T09:00:00.000',
    },
    {
      'author_id': 'demo_pilgrim_03',
      'author_role': 'pilgrim',
      'temple_id': 'jagannath_hyderabad',
      'temple_name': 'Jagannath Temple, Hyderabad',
      'title': 'Rath Yatra in Hyderabad — surprisingly authentic',
      'body': 'I was not expecting much from a replica temple but the Rath Yatra here is genuinely moving. The chariot is pulled through the streets with hundreds of devotees. The Mahaprasadam served after the procession is delicious. The Odia community here has kept the traditions very alive.',
      'category': 'Spiritual Journey',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-06-25T11:00:00.000',
    },
    {
      'author_id': 'demo_pilgrim_01',
      'author_role': 'pilgrim',
      'temple_id': 'keesaragutta',
      'temple_name': 'Shri Keesara Sri Venkateswara Swamy Temple',
      'title': 'Hidden gem near Hyderabad',
      'body': 'Most people do not know about Keesaragutta. It is only 35 km from the city but feels completely different — peaceful, green, and uncrowded. The hilltop view is beautiful. Go on a weekday morning for the best experience.',
      'category': 'Temple Visit',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-04-02T08:30:00.000',
    },
    {
      'author_id': 'demo_pilgrim_02',
      'author_role': 'pilgrim',
      'temple_id': 'vijayawada',
      'temple_name': 'Sri Kanaka Durga Temple, Vijayawada',
      'title': 'Navratri at Kanaka Durga — plan ahead',
      'body': 'Navratri at Kanaka Durga draws millions. Book your darshan slot online at least 2 weeks in advance. The special alankaram (decoration) changes every day of Navratri — each day has a different form of the goddess. The evening aarti on the banks of the Krishna is unforgettable.',
      'category': 'Festival Experience',
      'status': 'published',
      'is_pinned': 0,
      'created_at': '2026-10-05T19:00:00.000',
    },
  ];

  static Future<void> _seedDemoPosts(Transaction txn) async {
    for (final post in _demoPosts) {
      await txn.insert(
        'community_stories',
        {
          'author_id': post['author_id'],
          'author_role': post['author_role'],
          'author': post['author_id'], // legacy column
          'temple_id': post['temple_id'],
          'temple_name': post['temple_name'],
          'title': post['title'],
          'body': post['body'],
          'category': post['category'],
          'status': post['status'],
          'is_pinned': post['is_pinned'],
          'sync_status': 'local',
          'created_at': post['created_at'],
          'like_count': 0,
          'liked': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
