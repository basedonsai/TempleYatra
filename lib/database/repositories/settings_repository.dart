library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SettingsRepository {
  const SettingsRepository();

  static const String keyHasOnboarded = 'has_onboarded';

  Future<String?> get(String key) async {
    final rows = await (await AppDatabase.instance.db).query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await (await AppDatabase.instance.db).insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key);
    if (v == null) return defaultValue;
    return v == '1' || v == 'true';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');

  Future<bool> get hasOnboarded => getBool(keyHasOnboarded);
  Future<void> setHasOnboarded(bool v) => setBool(keyHasOnboarded, v);

  static const String keyCurrentUserId = 'current_user_id';
  static const String keyProfileSetupDone = 'profile_setup_done';

  Future<String?> getCurrentUserId() => get(keyCurrentUserId);
  Future<void> setCurrentUserId(String id) => set(keyCurrentUserId, id);
  Future<void> clearCurrentUserId() async {
    await (await AppDatabase.instance.db).delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [keyCurrentUserId],
    );
  }

  Future<bool> get profileSetupDone => getBool(keyProfileSetupDone);
  Future<void> setProfileSetupDone(bool v) => setBool(keyProfileSetupDone, v);
}
