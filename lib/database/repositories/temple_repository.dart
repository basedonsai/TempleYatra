/// TempleRepository — all temple reads/writes go through here.
/// Screens and providers never touch raw SQL.
library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/temple_model.dart';

class TempleRepository {
  const TempleRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Temple>> getAll() async {
    final rows = await (await _db).query('temples', orderBy: 'name ASC');
    return rows.map(_fromRow).toList();
  }

  Future<Temple?> getById(String id) async {
    final rows = await (await _db).query(
      'temples',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<List<Temple>> search(String query) async {
    final q = '%${query.toLowerCase()}%';
    final rows = await (await _db).query(
      'temples',
      where: 'LOWER(name) LIKE ? OR LOWER(address) LIKE ?',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Upsert a temple (used when refreshing from a future remote source).
  Future<void> upsert(Temple t) async {
    await (await _db).insert(
      'temples',
      _toRow(t),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  static Temple _fromRow(Map<String, dynamic> r) {
    return Temple(
      id: r['id'] as String,
      placeId: r['place_id'] as String? ?? '',
      name: r['name'] as String,
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      address: r['address'] as String? ?? '',
      distinctiveFeatures: r['distinctive_features'] as String? ?? '',
      festivals: r['festivals'] as String? ?? '',
      prasadamInfo: r['prasadam_info'] as String? ?? '',
      darshanTimings: r['darshan_timings'] as String? ?? '',
      openingHours: r['opening_hours'] as String?,
      rating: (r['rating'] as num?)?.toDouble(),
      userRatingsTotal: r['user_ratings_total'] as int?,
      phoneNumber: r['phone_number'] as String?,
      website: r['website'] as String?,
      estimatedVisitDurationMinutes: r['estimated_visit_minutes'] as int?,
      primaryLanguage: r['primary_language'] as String?,
      region: r['region'] as String?,
      deityInfo: r['deity_info'] as String?,
      sthalaPuranam: r['sthala_puranam'] as String?,
      sthalaPuranamEnglish: r['sthala_puranam_en'] as String?,
      sthalaPuranamHindi: r['sthala_puranam_hi'] as String?,
      sthalaPuranamTamil: r['sthala_puranam_ta'] as String?,
      sthalaPuranamTelugu: r['sthala_puranam_te'] as String?,
      rituals: r['rituals'] as String?,
      ritualsEnglish: r['rituals_en'] as String?,
      mantras: r['mantras'] as String?,
      significance: r['significance'] as String?,
      bestTimeToVisit: r['best_time_to_visit'] as String?,
      dressCode: r['dress_code'] as String?,
      templeHistory: r['temple_history'] as String?,
      architectureInfo: r['architecture_info'] as String?,
    );
  }

  static Map<String, dynamic> _toRow(Temple t) => {
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
        'updated_at': DateTime.now().toIso8601String(),
      };
}
