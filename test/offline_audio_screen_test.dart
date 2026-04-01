import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yatra_app/models/audio_pack.dart';
import 'package:yatra_app/providers/audio_pack_provider.dart';
import 'package:yatra_app/screens/offline_pack_manager_screen.dart';
import 'package:yatra_app/services/audio_pack_service.dart';

// ---------------------------------------------------------------------------
// Test data — 3 packs covering all three states under test.
// ---------------------------------------------------------------------------

const _testTracks = <AudioTrack>[
  AudioTrack(
    trackId: 'test_track_01',
    title: 'Test Track',
    category: ContentCategory.history,
    durationSeconds: 120,
    fileSizeBytes: 1_000_000,
  ),
];

final _testPacks = <AudioPack>[
  const AudioPack(
    packId: 'pack_test_not_downloaded',
    templeId: 'test_temple_a',
    title: 'Test Pack A',
    description: 'A pack that has not been downloaded.',
    totalSizeBytes: 5_000_000,
    tracks: _testTracks,
    downloadState: DownloadState.notDownloaded,
  ),
  const AudioPack(
    packId: 'pack_test_downloading',
    templeId: 'test_temple_b',
    title: 'Test Pack B',
    description: 'A pack currently downloading.',
    totalSizeBytes: 5_000_000,
    tracks: _testTracks,
    downloadState: DownloadState.downloading,
    downloadProgress: 0.45,
  ),
  const AudioPack(
    packId: 'pack_test_downloaded',
    templeId: 'test_temple_c',
    title: 'Test Pack C',
    description: 'A pack that has been downloaded.',
    totalSizeBytes: 5_000_000,
    tracks: _testTracks,
    downloadState: DownloadState.downloaded,
  ),
];

// ---------------------------------------------------------------------------
// Fake notifier — returns fixed test data without touching real services.
// ---------------------------------------------------------------------------

class _FakeAudioPackNotifier extends AudioPackNotifier {
  @override
  Future<List<AudioPack>> build() async => _testPacks;
}

// ---------------------------------------------------------------------------
// Minimal stub service that only needs to answer getTotalUsedStorageBytes.
// ---------------------------------------------------------------------------

class _StubAudioPackService extends AudioPackService {
  _StubAudioPackService(SharedPreferences prefs)
      : super(
          prefs: prefs,
          getDocsDir: () async => Directory.systemTemp,
        );

  @override
  int getTotalUsedStorageBytes() {
    // One pack is downloaded (5 MB).
    return 5_000_000;
  }
}

// ---------------------------------------------------------------------------
// Tests — Validates: Requirements NFR 4.2
// ---------------------------------------------------------------------------

void main() {
  testWidgets('OfflinePackManagerScreen smoke test', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final stubService = _StubAudioPackService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPackProvider.overrideWith(_FakeAudioPackNotifier.new),
          audioPackServiceProvider.overrideWithValue(stubService),
        ],
        child: const MaterialApp(home: OfflinePackManagerScreen()),
      ),
    );

    // Let async notifier resolve.
    await tester.pumpAndSettle();

    // Storage summary card is visible.
    // The card renders e.g. "4.8 MB used  |  1 pack downloaded"
    expect(find.textContaining('MB used'), findsOneWidget);
    expect(find.textContaining('pack'), findsWidgets);
    expect(find.textContaining('downloaded'), findsWidgets);

    // "Download" button visible for the notDownloaded pack.
    expect(find.text('Download'), findsOneWidget);

    // LinearProgressIndicator visible for the downloading pack.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // "Delete" button visible for the downloaded pack.
    expect(find.text('Delete'), findsOneWidget);
  });
}
