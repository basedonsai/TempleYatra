import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// audio_pack_data.dart is used by AudioPackService internally (allAudioPacks).
import '../models/audio_pack.dart';
import '../services/audio_pack_service.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// Provides a [SharedPreferences] instance. Must be overridden in tests or
/// initialized before use via [sharedPreferencesProvider.overrideWithValue].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden before use. '
    'Call SharedPreferences.getInstance() in main() and override this provider.',
  ),
);

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Constructs [AudioPackService] with real [SharedPreferences] and
/// [getApplicationDocumentsDirectory]. State restoration happens lazily
/// inside [AudioPackNotifier.build].
final audioPackServiceProvider = Provider<AudioPackService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AudioPackService(
    prefs: prefs,
    getDocsDir: () async {
      final dir = await getApplicationDocumentsDirectory();
      return Directory(dir.path);
    },
  );
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AudioPackNotifier extends AsyncNotifier<List<AudioPack>> {
  /// Active cancellation tokens keyed by packId.
  final Map<String, CancellationToken> _tokens = {};

  @override
  Future<List<AudioPack>> build() async {
    final service = ref.read(audioPackServiceProvider);
    await service.restoreStates();
    return service.packs;
  }

  AudioPackService get _service => ref.read(audioPackServiceProvider);

  // -------------------------------------------------------------------------
  // Download
  // -------------------------------------------------------------------------

  Future<void> download(String packId) async {
    final service = _service;

    // Guard: already downloaded
    final current = service.packs.firstWhere(
      (p) => p.packId == packId,
      orElse: () => throw StateError('Pack $packId not found'),
    );
    if (current.downloadState == DownloadState.downloaded) return;

    final token = CancellationToken();
    _tokens[packId] = token;

    // Kick off download; update state on every progress tick.
    await service.downloadPack(
      packId,
      (progress) {
        // Update state with current progress so UI sees live updates.
        final updated = service.packs;
        state = AsyncData(updated);
      },
      token,
    );

    _tokens.remove(packId);
    await service.persistStates();
    state = AsyncData(service.packs);
  }

  // -------------------------------------------------------------------------
  // Cancel
  // -------------------------------------------------------------------------

  Future<void> cancelDownload(String packId) async {
    final token = _tokens[packId];
    if (token != null) {
      token.cancel();
      _tokens.remove(packId);
    }
    // State will be updated by the download loop when it detects cancellation.
    // Persist after a short yield to let the download coroutine finish.
    await Future<void>.delayed(Duration.zero);
    await _service.persistStates();
    state = AsyncData(_service.packs);
  }

  // -------------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------------

  Future<void> deletePack(String packId) async {
    await _service.deletePack(packId);
    await _service.persistStates();
    state = AsyncData(_service.packs);
  }

  // -------------------------------------------------------------------------
  // Retry
  // -------------------------------------------------------------------------

  Future<void> retryDownload(String packId) async {
    // Reset to notDownloaded first, then re-download.
    await _service.deletePack(packId);
    await _service.persistStates();
    state = AsyncData(_service.packs);
    await download(packId);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The primary provider for the list of [AudioPack] objects.
final audioPackProvider =
    AsyncNotifierProvider<AudioPackNotifier, List<AudioPack>>(
  AudioPackNotifier.new,
);

/// Selects the single [AudioPack] for a given [templeId], or `null` if none.
final packForTempleProvider = Provider.family<AudioPack?, String>(
  (ref, templeId) {
    final asyncPacks = ref.watch(audioPackProvider);
    return asyncPacks.whenOrNull(
      data: (packs) {
        try {
          return packs.firstWhere((p) => p.templeId == templeId);
        } catch (_) {
          return null;
        }
      },
    );
  },
);
