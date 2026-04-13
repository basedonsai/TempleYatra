library;

import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../models/audio_pack.dart';

class AudioPackRepository {
  const AudioPackRepository();

  Future<Database> get _db => AppDatabase.instance.db;

  // ── Reads ─────────────────────────────────────────────────────────────────

  Future<List<AudioPack>> getAll() async {
    final db = await _db;
    final packRows = await db.query('audio_packs');
    return Future.wait(packRows.map((r) => _packFromRow(db, r)));
  }

  Future<AudioPack?> getByPackId(String packId) async {
    final db = await _db;
    final rows = await db.query(
      'audio_packs',
      where: 'pack_id = ?',
      whereArgs: [packId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _packFromRow(db, rows.first);
  }

  Future<AudioPack?> getForTemple(String templeId) async {
    final db = await _db;
    final rows = await db.query(
      'audio_packs',
      where: 'temple_id = ?',
      whereArgs: [templeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _packFromRow(db, rows.first);
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Persist download state + progress + error for a pack.
  Future<void> updateDownloadState({
    required String packId,
    required DownloadState state,
    double progress = 0.0,
    String? errorMessage,
  }) async {
    await (await _db).update(
      'audio_packs',
      {
        'download_state': state.name,
        'download_progress': progress,
        'error_message': errorMessage,
      },
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
  }

  /// Persist the local file path for a downloaded track.
  Future<void> updateTrackLocalPath({
    required String trackId,
    required String? localPath,
  }) async {
    await (await _db).update(
      'audio_tracks',
      {'local_path': localPath},
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  /// Reset all tracks' local paths for a pack (used on delete).
  Future<void> clearTrackPaths(String packId) async {
    await (await _db).update(
      'audio_tracks',
      {'local_path': null},
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  Future<AudioPack> _packFromRow(Database db, Map<String, dynamic> r) async {
    final trackRows = await db.query(
      'audio_tracks',
      where: 'pack_id = ?',
      whereArgs: [r['pack_id']],
      orderBy: 'sort_order ASC',
    );
    return AudioPack(
      packId: r['pack_id'] as String,
      templeId: r['temple_id'] as String,
      title: r['title'] as String,
      description: r['description'] as String? ?? '',
      totalSizeBytes: r['total_size_bytes'] as int? ?? 0,
      downloadState: DownloadState.values.firstWhere(
        (e) => e.name == r['download_state'],
        orElse: () => DownloadState.notDownloaded,
      ),
      downloadProgress: (r['download_progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: r['error_message'] as String?,
      tracks: trackRows.map(_trackFromRow).toList(),
    );
  }

  static AudioTrack _trackFromRow(Map<String, dynamic> r) {
    return AudioTrack(
      trackId: r['track_id'] as String,
      title: r['title'] as String,
      category: ContentCategory.values.firstWhere(
        (e) => e.name == r['category'],
        orElse: () => ContentCategory.history,
      ),
      durationSeconds: r['duration_seconds'] as int? ?? 0,
      fileSizeBytes: r['file_size_bytes'] as int? ?? 0,
      localPath: r['local_path'] as String?,
    );
  }
}
