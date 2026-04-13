library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/festival_event.dart';

class FestivalRepository {
  const FestivalRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<FestivalEvent>> getAll() async {
    final rows = await (await _db).query('festivals', orderBy: 'date ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<FestivalEvent>> getForTemple(String templeId) async {
    final rows = await (await _db).query(
      'festivals',
      where: 'temple_id = ?',
      whereArgs: [templeId],
      orderBy: 'date ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<FestivalEvent>> getUpcoming({int limit = 10}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await (await _db).query(
      'festivals',
      where: "date >= ?",
      whereArgs: [today],
      orderBy: 'date ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  static FestivalEvent _fromRow(Map<String, dynamic> r) {
    return FestivalEvent(
      templeId: r['temple_id'] as String,
      name: r['name'] as String,
      date: DateTime.parse(r['date'] as String),
      crowdHint: _parseCrowdLevel(r['crowd_hint'] as String? ?? 'high'),
    );
  }

  static CrowdLevel _parseCrowdLevel(String s) {
    return CrowdLevel.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CrowdLevel.high,
    );
  }
}
