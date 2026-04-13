library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class ItineraryDraft {
  final int? id;
  final String title;
  final List<String> templeIds;
  final DateTime? startDate;
  final int numberOfDays;
  final double maxBudget;
  final String travelMode;
  final Map<String, dynamic>? generatedJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItineraryDraft({
    this.id,
    required this.title,
    required this.templeIds,
    this.startDate,
    required this.numberOfDays,
    required this.maxBudget,
    required this.travelMode,
    this.generatedJson,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ItineraryDraftRepository {
  const ItineraryDraftRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<ItineraryDraft>> getAll() async {
    final rows = await (await _db).query(
      'itinerary_drafts',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<ItineraryDraft?> getById(int id) async {
    final rows = await (await _db).query(
      'itinerary_drafts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<int> save(ItineraryDraft draft) async {
    final row = _toRow(draft);
    if (draft.id == null) {
      return (await _db).insert('itinerary_drafts', row);
    } else {
      await (await _db).update(
        'itinerary_drafts',
        row,
        where: 'id = ?',
        whereArgs: [draft.id],
      );
      return draft.id!;
    }
  }

  Future<void> delete(int id) async {
    await (await _db).delete(
      'itinerary_drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static ItineraryDraft _fromRow(Map<String, dynamic> r) {
    final templeIdsRaw = r['temple_ids'] as String? ?? '[]';
    final generatedRaw = r['generated_json'] as String?;
    return ItineraryDraft(
      id: r['id'] as int?,
      title: r['title'] as String? ?? 'My Yatra',
      templeIds: List<String>.from(jsonDecode(templeIdsRaw) as List),
      startDate: r['start_date'] != null
          ? DateTime.tryParse(r['start_date'] as String)
          : null,
      numberOfDays: r['number_of_days'] as int? ?? 1,
      maxBudget: (r['max_budget'] as num?)?.toDouble() ?? 0,
      travelMode: r['travel_mode'] as String? ?? 'car',
      generatedJson: generatedRaw != null
          ? jsonDecode(generatedRaw) as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  static Map<String, dynamic> _toRow(ItineraryDraft d) {
    final now = DateTime.now().toIso8601String();
    return {
      if (d.id != null) 'id': d.id,
      'title': d.title,
      'temple_ids': jsonEncode(d.templeIds),
      'start_date': d.startDate?.toIso8601String(),
      'number_of_days': d.numberOfDays,
      'max_budget': d.maxBudget,
      'travel_mode': d.travelMode,
      'generated_json':
          d.generatedJson != null ? jsonEncode(d.generatedJson) : null,
      'created_at': d.createdAt.toIso8601String(),
      'updated_at': now,
    };
  }
}
