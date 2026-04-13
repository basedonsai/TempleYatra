library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/user_profile.dart';

class UserProfileRepository {
  const UserProfileRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<UserProfile?> getById(String id) async {
    final rows = await (await _db).query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<List<UserProfile>> getAll() async {
    final rows = await (await _db).query('user_profiles');
    return rows.map(_fromRow).toList();
  }

  Future<List<UserProfile>> getDemoActors() async {
    final rows = await (await _db).query(
      'user_profiles',
      where: 'is_demo = 1',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(UserProfile profile) async {
    await (await _db).insert(
      'user_profiles',
      _toRow(profile),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static UserProfile _fromRow(Map<String, dynamic> r) => UserProfile(
        id: r['id'] as String,
        displayName: r['display_name'] as String,
        avatarSeed: r['avatar_seed'] as int? ?? 0,
        role: UserProfile.roleFromString(r['role'] as String? ?? 'guest'),
        isDemo: (r['is_demo'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  static Map<String, dynamic> _toRow(UserProfile p) => {
        'id': p.id,
        'display_name': p.displayName,
        'avatar_seed': p.avatarSeed,
        'role': p.role.name,
        'is_demo': p.isDemo ? 1 : 0,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
}
