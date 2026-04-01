/// AppDatabase — single source of truth for all local SQLite storage.
///
/// Design rules:
/// - All DDL lives here. No CREATE TABLE anywhere else.
/// - Schema version bumps add a new migration entry; old data is preserved.
/// - Seeding runs once per schema version via the `seeded_versions` table.
/// - Repositories call [AppDatabase.db] — they never open their own connection.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _schemaVersion = 2;
  static const String _dbName = 'temple_yatra.db';

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  // ── Open / create ─────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Foreign keys must be enabled before onCreate/onUpgrade run
        await db.rawQuery('PRAGMA foreign_keys=ON');
      },
    );
  }

  // ── Schema ────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _createAllTables(db);
      return;
    }
    if (oldVersion < 2) {
      await _migrateV1toV2(db);
    }
  }

  Future<void> _migrateV1toV2(Database db) async {
    final batch = db.batch();

    // New table: user_profiles
    batch.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id           TEXT    PRIMARY KEY,
        display_name TEXT    NOT NULL,
        avatar_seed  INTEGER NOT NULL DEFAULT 0,
        role         TEXT    NOT NULL DEFAULT 'guest',
        is_demo      INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Extend community_stories
    batch.execute(
      "ALTER TABLE community_stories ADD COLUMN author_id   TEXT",
    );
    batch.execute(
      "ALTER TABLE community_stories ADD COLUMN author_role TEXT NOT NULL DEFAULT 'pilgrim'",
    );
    batch.execute(
      "ALTER TABLE community_stories ADD COLUMN is_pinned   INTEGER NOT NULL DEFAULT 0",
    );
    batch.execute(
      "ALTER TABLE community_stories ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local'",
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stories_feed ON community_stories(is_pinned DESC, created_at DESC)',
    );

    await batch.commit(noResult: true);
    debugPrint('[AppDatabase] Migrated v1 → v2');
  }

  Future<void> _createAllTables(Database db) async {
    final batch = db.batch();

    // ── Seed tracking ──────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS seeded_versions (
        version   INTEGER PRIMARY KEY,
        seeded_at TEXT    NOT NULL
      )
    ''');

    // ── Temples ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS temples (
        id                          TEXT    PRIMARY KEY,
        place_id                    TEXT    NOT NULL DEFAULT '',
        name                        TEXT    NOT NULL,
        latitude                    REAL    NOT NULL,
        longitude                   REAL    NOT NULL,
        address                     TEXT    NOT NULL DEFAULT '',
        distinctive_features        TEXT    NOT NULL DEFAULT '',
        festivals                   TEXT    NOT NULL DEFAULT '',
        prasadam_info               TEXT    NOT NULL DEFAULT '',
        darshan_timings             TEXT    NOT NULL DEFAULT '',
        opening_hours               TEXT,
        rating                      REAL,
        user_ratings_total          INTEGER,
        phone_number                TEXT,
        website                     TEXT,
        estimated_visit_minutes     INTEGER,
        primary_language            TEXT,
        region                      TEXT,
        deity_info                  TEXT,
        sthala_puranam              TEXT,
        sthala_puranam_en           TEXT,
        sthala_puranam_hi           TEXT,
        sthala_puranam_ta           TEXT,
        sthala_puranam_te           TEXT,
        rituals                     TEXT,
        rituals_en                  TEXT,
        mantras                     TEXT,
        significance                TEXT,
        best_time_to_visit          TEXT,
        dress_code                  TEXT,
        temple_history              TEXT,
        architecture_info           TEXT,
        updated_at                  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Festivals ──────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS festivals (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        temple_id   TEXT    NOT NULL REFERENCES temples(id) ON DELETE CASCADE,
        name        TEXT    NOT NULL,
        date        TEXT    NOT NULL,
        crowd_hint  TEXT    NOT NULL DEFAULT 'high'
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_festivals_temple ON festivals(temple_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_festivals_date ON festivals(date)',
    );

    // ── Audio packs ────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS audio_packs (
        pack_id          TEXT    PRIMARY KEY,
        temple_id        TEXT    NOT NULL REFERENCES temples(id) ON DELETE CASCADE,
        title            TEXT    NOT NULL,
        description      TEXT    NOT NULL DEFAULT '',
        total_size_bytes INTEGER NOT NULL DEFAULT 0,
        download_state   TEXT    NOT NULL DEFAULT 'notDownloaded',
        download_progress REAL   NOT NULL DEFAULT 0.0,
        error_message    TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS audio_tracks (
        track_id         TEXT    PRIMARY KEY,
        pack_id          TEXT    NOT NULL REFERENCES audio_packs(pack_id) ON DELETE CASCADE,
        title            TEXT    NOT NULL,
        category         TEXT    NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        file_size_bytes  INTEGER NOT NULL DEFAULT 0,
        local_path       TEXT,
        sort_order       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tracks_pack ON audio_tracks(pack_id)',
    );

    // ── App settings (key-value) ───────────────────────────────────────────
    // Replaces SharedPreferences for app-level flags (onboarding, etc.)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key        TEXT PRIMARY KEY,
        value      TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Community stories ──────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS community_stories (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        temple_id   TEXT    NOT NULL,
        temple_name TEXT    NOT NULL DEFAULT '',
        author      TEXT    NOT NULL DEFAULT 'You',
        author_id   TEXT,
        author_role TEXT    NOT NULL DEFAULT 'pilgrim',
        title       TEXT    NOT NULL,
        body        TEXT    NOT NULL,
        category    TEXT    NOT NULL DEFAULT 'Temple Visit',
        status      TEXT    NOT NULL DEFAULT 'pending',
        is_pinned   INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT    NOT NULL DEFAULT 'local',
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        like_count  INTEGER NOT NULL DEFAULT 0,
        liked       INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stories_temple ON community_stories(temple_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_stories_feed ON community_stories(is_pinned DESC, created_at DESC)',
    );

    // ── User profiles ──────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id           TEXT    PRIMARY KEY,
        display_name TEXT    NOT NULL,
        avatar_seed  INTEGER NOT NULL DEFAULT 0,
        role         TEXT    NOT NULL DEFAULT 'guest',
        is_demo      INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── Itinerary drafts ───────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS itinerary_drafts (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        title           TEXT    NOT NULL DEFAULT 'My Yatra',
        temple_ids      TEXT    NOT NULL,
        start_date      TEXT,
        number_of_days  INTEGER NOT NULL DEFAULT 1,
        max_budget      REAL    NOT NULL DEFAULT 0,
        travel_mode     TEXT    NOT NULL DEFAULT 'car',
        generated_json  TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await batch.commit(noResult: true);
    debugPrint('[AppDatabase] All tables created at schema v$_schemaVersion');
  }

  // ── Seed tracking ─────────────────────────────────────────────────────────

  /// Returns true if seed data for [version] has already been inserted.
  Future<bool> isSeeded(int version) async {
    final d = await db;
    final rows = await d.query(
      'seeded_versions',
      where: 'version = ?',
      whereArgs: [version],
    );
    return rows.isNotEmpty;
  }

  /// Marks [version] as seeded. Call after a successful seed transaction.
  Future<void> markSeeded(int version) async {
    final d = await db;
    await d.insert(
      'seeded_versions',
      {'version': version, 'seeded_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Closes the database. Mainly useful in tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Deletes the database file. Use only in tests or "reset app" flows.
  Future<void> deleteDatabase() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await databaseFactory.deleteDatabase(path);
    _db = null;
  }
}
