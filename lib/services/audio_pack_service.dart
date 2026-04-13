import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/audio_pack_data.dart';
import '../data/cultural_content_data.dart';
import '../models/audio_pack.dart';
import '../models/cultural_content.dart';

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
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

  /// Maps a ContentCategory to the matching ContentType for knowledge base lookup
  static ContentType _categoryToContentType(ContentCategory cat) {
    switch (cat) {
      case ContentCategory.history:
        return ContentType.sthalaPuranam;
      case ContentCategory.ritual:
        return ContentType.ritual;
      case ContentCategory.significance:
        return ContentType.significance;
      case ContentCategory.travelTips:
        return ContentType.sthalaPuranam; // fallback
    }
  }

  /// Fetches the text content for a track from the cultural knowledge base.
  /// Falls back to the track title + temple description if no content found.
  static String _getTextForTrack(AudioTrack track, String templeId) {
    final type = _categoryToContentType(track.category);
    final contentList = getContentByType(templeId, type);

    if (contentList.isNotEmpty) {
      return contentList.first.content;
    }

    // Fallback: use track title as minimal content
    return '${track.title}. This audio guide covers information about the temple.';
  }

  Future<void> downloadPack(
    String packId,
    void Function(double) onProgress,
    CancellationToken token,
  ) async {
    final pack = _findPack(packId);
    if (pack == null) return;

    _updatePack(pack.copyWith(
      downloadState: DownloadState.downloading,
      downloadProgress: 0.0,
      clearErrorMessage: true,
    ));

    try {
      final dir = await _getDocsDir();
      final packDir = Directory('${dir.path}/audio_packs/$packId');
      await packDir.create(recursive: true);

      final updatedTracks = List<AudioTrack>.from(pack.tracks);

      for (int i = 0; i < pack.tracks.length; i++) {
        if (token.isCancelled) {
          await packDir.delete(recursive: true);
          _updatePack(_findPack(packId)!.copyWith(
            downloadState: DownloadState.notDownloaded,
            downloadProgress: 0.0,
            clearErrorMessage: true,
          ));
          return;
        }

        final track = pack.tracks[i];

        // Write the actual text content — TTS will read this at playback time
        final text = _getTextForTrack(track, pack.templeId);
        final path = '${packDir.path}/${track.trackId}.txt';
        await File(path).writeAsString(text, encoding: utf8);

        // Small simulated delay so progress bar is visible
        await Future.delayed(const Duration(milliseconds: 300));

        updatedTracks[i] = track.copyWith(localPath: path);

        final progress = (i + 1) / pack.tracks.length;
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
    } catch (_) {}

    final resetTracks = pack.tracks
        .map((t) => AudioTrack(
              trackId: t.trackId,
              title: t.title,
              category: t.category,
              durationSeconds: t.durationSeconds,
              fileSizeBytes: t.fileSizeBytes,
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
    return pack.tracks.every((t) =>
        t.localPath != null && File(t.localPath!).existsSync());
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
        final dir = await _getDocsDir();
        final packDirPath = '${dir.path}/audio_packs/${pack.packId}';

        final allExist = pack.tracks.every((t) {
          final path = t.localPath ?? '$packDirPath/${t.trackId}.txt';
          return File(path).existsSync();
        });

        if (!allExist) {
          _updatePack(pack.copyWith(
            downloadState: DownloadState.failed,
            errorMessage: 'Audio files missing. Tap Retry.',
          ));
        } else {
          final restoredTracks = pack.tracks
              .map((t) => t.copyWith(
                    localPath: t.localPath ?? '$packDirPath/${t.trackId}.txt',
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
