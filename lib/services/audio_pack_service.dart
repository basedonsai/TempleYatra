import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/audio_pack_data.dart';
import '../models/audio_pack.dart';

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class AudioPackService {
  final SharedPreferences _prefs;
  final Future<Directory> Function() _getDocsDir;

  List<AudioPack> _packs;

  static const String _prefsKey = 'audio_pack_states';

  AudioPackService({
    required SharedPreferences prefs,
    required Future<Directory> Function() getDocsDir,
  })  : _prefs = prefs,
        _getDocsDir = getDocsDir,
        _packs = List<AudioPack>.from(allAudioPacks);

  List<AudioPack> get packs => List.unmodifiable(_packs);

  AudioPack? _findPack(String packId) {
    try {
      return _packs.firstWhere((p) => p.packId == packId);
    } catch (_) {
      return null;
    }
  }

  void _updatePack(AudioPack updated) {
    _packs = _packs.map((p) => p.packId == updated.packId ? updated : p).toList();
  }

  Future<void> downloadPack(
    String packId,
    void Function(double) onProgress,
    CancellationToken token,
  ) async {
    final pack = _findPack(packId);
    if (pack == null) return;

    // Transition to downloading
    _updatePack(pack.copyWith(
      downloadState: DownloadState.downloading,
      downloadProgress: 0.0,
      clearErrorMessage: true,
    ));

    try {
      final dir = await _getDocsDir();
      final packDir = Directory('${dir.path}/audio_packs/$packId');
      await packDir.create(recursive: true);

      int completedBytes = 0;
      final updatedTracks = List<AudioTrack>.from(pack.tracks);

      for (int i = 0; i < pack.tracks.length; i++) {
        final track = pack.tracks[i];

        if (token.isCancelled) {
          await packDir.delete(recursive: true);
          _updatePack(_findPack(packId)!.copyWith(
            downloadState: DownloadState.notDownloaded,
            downloadProgress: 0.0,
            clearErrorMessage: true,
          ));
          return;
        }

        final delayMs = track.fileSizeBytes ~/ 50000;
        await Future.delayed(Duration(milliseconds: delayMs));

        final path = '${packDir.path}/${track.trackId}.aac';
        await File(path).writeAsBytes(Uint8List(512));

        updatedTracks[i] = track.copyWith(localPath: path);
        completedBytes += track.fileSizeBytes;
        final progress = completedBytes / pack.totalSizeBytes;
        _updatePack(_findPack(packId)!.copyWith(downloadProgress: progress));
        onProgress(progress);
      }

      onProgress(1.0);

      _updatePack(_findPack(packId)!.copyWith(
        downloadState: DownloadState.downloaded,
        downloadProgress: 1.0,
        tracks: updatedTracks,
        clearErrorMessage: true,
      ));
    } on IOException catch (_) {
      final current = _findPack(packId);
      if (current != null) {
        _updatePack(current.copyWith(
          downloadState: DownloadState.failed,
          errorMessage: 'Download failed. Tap Retry.',
        ));
      }
      rethrow;
    } catch (e) {
      final current = _findPack(packId);
      if (current != null) {
        _updatePack(current.copyWith(
          downloadState: DownloadState.failed,
          errorMessage: 'Download failed. Tap Retry.',
        ));
      }
      rethrow;
    }
  }

  Future<void> deletePack(String packId) async {
    final pack = _findPack(packId);
    if (pack == null) return;
    if (pack.downloadState == DownloadState.notDownloaded) return;

    try {
      final dir = await _getDocsDir();
      final packDir = Directory('${dir.path}/audio_packs/$packId');
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore errors during deletion
    }

    // Reset tracks' localPath (copyWith can't set to null, so reconstruct)
    final resetTracks = pack.tracks
        .map((t) => AudioTrack(
              trackId: t.trackId,
              title: t.title,
              category: t.category,
              durationSeconds: t.durationSeconds,
              fileSizeBytes: t.fileSizeBytes,
              // localPath intentionally omitted (null)
            ))
        .toList();
    _updatePack(pack.copyWith(
      downloadState: DownloadState.notDownloaded,
      tracks: resetTracks,
    ));
  }

  bool isAvailableOffline(String packId) {
    final pack = _findPack(packId);
    if (pack == null) return false;
    if (pack.downloadState != DownloadState.downloaded) return false;

    return pack.tracks.every((t) {
      if (t.localPath == null) return false;
      return File(t.localPath!).existsSync();
    });
  }

  int getTotalUsedStorageBytes() {
    return _packs
        .where((p) => p.downloadState == DownloadState.downloaded)
        .fold(0, (sum, p) => sum + p.totalSizeBytes);
  }

  Future<void> persistStates() async {
    final map = {for (final p in _packs) p.packId: p.downloadState.name};
    await _prefs.setString(_prefsKey, jsonEncode(map));
  }

  Future<void> restoreStates() async {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return;

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final stateMap = decoded.map((k, v) => MapEntry(
          k,
          DownloadState.values.firstWhere(
            (e) => e.name == v,
            orElse: () => DownloadState.notDownloaded,
          ),
        ));

    for (final pack in List<AudioPack>.from(_packs)) {
      final persisted = stateMap[pack.packId];
      if (persisted == null) continue;

      if (persisted == DownloadState.downloaded) {
        // Verify all files exist by reconstructing expected paths
        final dir = await _getDocsDir();
        final packDirPath = '${dir.path}/audio_packs/${pack.packId}';

        final allExist = pack.tracks.every((t) {
          // Use stored localPath if available, otherwise reconstruct expected path
          final path = t.localPath ?? '$packDirPath/${t.trackId}.aac';
          return File(path).existsSync();
        });

        if (!allExist) {
          _updatePack(pack.copyWith(
            downloadState: DownloadState.failed,
            errorMessage: 'Audio files missing. Tap Retry.',
          ));
        } else {
          // Restore localPaths on tracks
          final restoredTracks = pack.tracks
              .map((t) => t.copyWith(
                    localPath: t.localPath ?? '$packDirPath/${t.trackId}.aac',
                  ))
              .toList();
          _updatePack(pack.copyWith(
            downloadState: DownloadState.downloaded,
            tracks: restoredTracks,
          ));
        }
      } else {
        _updatePack(pack.copyWith(downloadState: persisted));
      }
    }
  }
}
