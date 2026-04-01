import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yatra_app/data/audio_pack_data.dart';
import 'package:yatra_app/models/audio_pack.dart';
import 'package:yatra_app/services/audio_pack_service.dart';

void main() {
  group('AudioPackService', () {
    _p1Tests();
    _p2Tests();
    _p3Tests();
    _p4Tests();
    _p5Tests();
    _p6Tests();
    _p7Tests();
    _p8Tests();
    _p9Tests();
    _p10Tests();
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh [AudioPackService] backed by a temp directory and empty
/// SharedPreferences.  The caller is responsible for cleaning up [tempDir].
Future<AudioPackService> _makeService(Directory tempDir) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AudioPackService(
    prefs: prefs,
    getDocsDir: () async => tempDir,
  );
}

/// A no-op progress callback used when progress values are not under test.
void _noop(double _) {}


// ---------------------------------------------------------------------------
// P1 — Download State Exhaustiveness
// ---------------------------------------------------------------------------

void _p1Tests() {
  group('Download state exhaustiveness — P1', () {
    // Feature: offline-audio-packs, Property P1: Download State Exhaustiveness —
    // after any operation, pack.downloadState is always one of the four enum values.
    // Validates: Requirements 1.3, 3.1–3.7

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p1_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('initial state of every pack is a valid DownloadState', () {
      for (final pack in service.packs) {
        expect(
          DownloadState.values,
          contains(pack.downloadState),
          reason: 'Pack "${pack.packId}" has an invalid initial downloadState',
        );
      }
    });

    test('state is valid after download completes', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());

      for (final pack in service.packs) {
        expect(
          DownloadState.values,
          contains(pack.downloadState),
          reason: 'Pack "${pack.packId}" has invalid state after download',
        );
      }
    });

    test('state is valid after delete', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.deletePack(packId);

      for (final pack in service.packs) {
        expect(
          DownloadState.values,
          contains(pack.downloadState),
          reason: 'Pack "${pack.packId}" has invalid state after delete',
        );
      }
    });

    test('state is valid after cancellation', () async {
      final packId = allAudioPacks.first.packId;
      final token = CancellationToken();
      token.cancel();
      await service.downloadPack(packId, _noop, token);

      for (final pack in service.packs) {
        expect(
          DownloadState.values,
          contains(pack.downloadState),
          reason: 'Pack "${pack.packId}" has invalid state after cancellation',
        );
      }
    });

    test('DownloadState enum has exactly four values', () {
      expect(DownloadState.values.length, equals(4));
      expect(
        DownloadState.values,
        containsAll([
          DownloadState.notDownloaded,
          DownloadState.downloading,
          DownloadState.downloaded,
          DownloadState.failed,
        ]),
      );
    });
  });
}


// ---------------------------------------------------------------------------
// P2 — Progress Bounds
// ---------------------------------------------------------------------------

void _p2Tests() {
  group('Progress bounds — P2', () {
    // Feature: offline-audio-packs, Property P2: Progress Bounds —
    // all onProgress callbacks during download receive values in [0.0, 1.0].
    // Validates: Requirements 3.2

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p2_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('all progress values are in [0.0, 1.0] for every pack', () async {
      for (final pack in allAudioPacks) {
        final progressValues = <double>[];
        await service.downloadPack(
          pack.packId,
          progressValues.add,
          CancellationToken(),
        );

        expect(
          progressValues,
          isNotEmpty,
          reason: 'Pack "${pack.packId}" emitted no progress values',
        );

        for (final v in progressValues) {
          expect(
            v,
            inInclusiveRange(0.0, 1.0),
            reason:
                'Pack "${pack.packId}" emitted out-of-range progress value $v',
          );
        }
      }
    });

    test('final progress value is exactly 1.0', () async {
      final packId = allAudioPacks.first.packId;
      double lastProgress = -1;
      await service.downloadPack(
        packId,
        (v) => lastProgress = v,
        CancellationToken(),
      );
      expect(lastProgress, equals(1.0));
    });

    test('progress values are non-decreasing', () async {
      final packId = allAudioPacks.first.packId;
      final progressValues = <double>[];
      await service.downloadPack(
        packId,
        progressValues.add,
        CancellationToken(),
      );

      for (int i = 1; i < progressValues.length; i++) {
        expect(
          progressValues[i],
          greaterThanOrEqualTo(progressValues[i - 1]),
          reason:
              'Progress decreased from ${progressValues[i - 1]} to ${progressValues[i]}',
        );
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P3 — Storage Sum Invariant
// ---------------------------------------------------------------------------

void _p3Tests() {
  group('Storage sum invariant — P3', () {
    // Feature: offline-audio-packs, Property P3: Storage Sum Invariant —
    // getTotalUsedStorageBytes() equals sum of totalSizeBytes for downloaded packs
    // (within 1% tolerance).
    // Validates: Requirements 6.5, 6.6

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p3_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('storage is 0 when no packs are downloaded', () {
      expect(service.getTotalUsedStorageBytes(), equals(0));
    });

    test('storage equals totalSizeBytes after downloading one pack', () async {
      final pack = allAudioPacks.first;
      await service.downloadPack(pack.packId, _noop, CancellationToken());

      final reported = service.getTotalUsedStorageBytes();
      final expected = pack.totalSizeBytes;
      final tolerance = (expected * 0.01).ceil();

      expect(
        reported,
        inInclusiveRange(expected - tolerance, expected + tolerance),
        reason: 'Storage $reported is not within 1% of expected $expected',
      );
    });

    test('storage equals sum of totalSizeBytes after downloading all packs',
        () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
      }

      final reported = service.getTotalUsedStorageBytes();
      final expected =
          allAudioPacks.fold<int>(0, (sum, p) => sum + p.totalSizeBytes);
      final tolerance = (expected * 0.01).ceil();

      expect(
        reported,
        inInclusiveRange(expected - tolerance, expected + tolerance),
        reason:
            'Total storage $reported is not within 1% of expected $expected',
      );
    });

    test('storage decreases after deleting a downloaded pack', () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
      }
      final before = service.getTotalUsedStorageBytes();

      final toDelete = allAudioPacks.first;
      await service.deletePack(toDelete.packId);

      final after = service.getTotalUsedStorageBytes();
      expect(after, lessThan(before));

      final expectedAfter = before - toDelete.totalSizeBytes;
      final tolerance = (expectedAfter * 0.01).ceil();
      expect(
        after,
        inInclusiveRange(expectedAfter - tolerance, expectedAfter + tolerance),
      );
    });
  });
}


// ---------------------------------------------------------------------------
// P4 — Download-Delete Round-Trip
// ---------------------------------------------------------------------------

void _p4Tests() {
  group('Download-delete round-trip — P4', () {
    // Feature: offline-audio-packs, Property P4: Download-Delete Round-Trip —
    // download → delete → download yields same final state as single download.
    // Validates: Requirements 4.4, 7.3

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p4_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('download → delete → download results in downloaded state', () async {
      final packId = allAudioPacks.first.packId;

      await service.downloadPack(packId, _noop, CancellationToken());
      expect(
        service.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.downloaded),
      );

      await service.deletePack(packId);
      expect(
        service.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.notDownloaded),
      );

      await service.downloadPack(packId, _noop, CancellationToken());
      final finalState =
          service.packs.firstWhere((p) => p.packId == packId).downloadState;
      expect(finalState, equals(DownloadState.downloaded));
    });

    test('isAvailableOffline is true after round-trip', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.deletePack(packId);
      await service.downloadPack(packId, _noop, CancellationToken());

      expect(service.isAvailableOffline(packId), isTrue);
    });

    test('all track localPaths exist after round-trip', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.deletePack(packId);
      await service.downloadPack(packId, _noop, CancellationToken());

      final pack = service.packs.firstWhere((p) => p.packId == packId);
      for (final track in pack.tracks) {
        expect(track.localPath, isNotNull);
        expect(File(track.localPath!).existsSync(), isTrue);
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P5 — Offline Availability Consistency
// ---------------------------------------------------------------------------

void _p5Tests() {
  group('Offline availability consistency — P5', () {
    // Feature: offline-audio-packs, Property P5: Offline Availability Consistency —
    // isAvailableOffline returns true iff state is downloaded.
    // Validates: Requirements 5.6

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p5_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('isAvailableOffline is false for all packs initially', () {
      for (final pack in service.packs) {
        expect(
          service.isAvailableOffline(pack.packId),
          isFalse,
          reason:
              'Pack "${pack.packId}" should not be available offline initially',
        );
      }
    });

    test('isAvailableOffline is true iff state is downloaded', () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
      }

      for (final pack in service.packs) {
        final isDownloaded = pack.downloadState == DownloadState.downloaded;
        expect(
          service.isAvailableOffline(pack.packId),
          equals(isDownloaded),
          reason:
              'Pack "${pack.packId}" isAvailableOffline mismatch: '
              'state=${pack.downloadState}, isAvailableOffline=${service.isAvailableOffline(pack.packId)}',
        );
      }
    });

    test('isAvailableOffline becomes false after delete', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      expect(service.isAvailableOffline(packId), isTrue);

      await service.deletePack(packId);
      expect(service.isAvailableOffline(packId), isFalse);
    });

    test('isAvailableOffline is false for cancelled download', () async {
      final packId = allAudioPacks.first.packId;
      final token = CancellationToken();
      token.cancel();
      await service.downloadPack(packId, _noop, token);

      expect(service.isAvailableOffline(packId), isFalse);
    });
  });
}


// ---------------------------------------------------------------------------
// P6 — File Existence After Download
// ---------------------------------------------------------------------------

void _p6Tests() {
  group('File existence after download — P6', () {
    // Feature: offline-audio-packs, Property P6: File Existence After Download —
    // after download, all tracks have non-null localPath pointing to existing files.
    // Validates: Requirements 3.4

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p6_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('all tracks have non-null localPath after download', () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
        final downloaded =
            service.packs.firstWhere((p) => p.packId == pack.packId);

        for (final track in downloaded.tracks) {
          expect(
            track.localPath,
            isNotNull,
            reason:
                'Track "${track.trackId}" in pack "${pack.packId}" has null localPath after download',
          );
        }
      }
    });

    test('all localPath files exist on disk after download', () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
        final downloaded =
            service.packs.firstWhere((p) => p.packId == pack.packId);

        for (final track in downloaded.tracks) {
          expect(
            File(track.localPath!).existsSync(),
            isTrue,
            reason:
                'File "${track.localPath}" for track "${track.trackId}" does not exist',
          );
        }
      }
    });

    test('localPaths are cleared after delete', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.deletePack(packId);

      final deleted = service.packs.firstWhere((p) => p.packId == packId);
      for (final track in deleted.tracks) {
        expect(
          track.localPath,
          isNull,
          reason: 'Track "${track.trackId}" still has localPath after delete',
        );
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P7 — State Persistence Round-Trip
// ---------------------------------------------------------------------------

void _p7Tests() {
  group('State persistence round-trip — P7', () {
    // Feature: offline-audio-packs, Property P7: State Persistence Round-Trip —
    // persistStates then restoreStates preserves downloaded state when files exist;
    // sets failed when files are missing.
    // Validates: Requirements 8.1–8.5

    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p7_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('downloaded state is preserved when files exist after restore',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );

      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.persistStates();

      final service2 = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );
      await service2.restoreStates();

      expect(
        service2.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.downloaded),
        reason: 'State should be preserved when files exist',
      );
    });

    test('state becomes failed when files are missing after restore', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );

      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      await service.persistStates();

      final packDir = Directory('${tempDir.path}/audio_packs/$packId');
      if (packDir.existsSync()) {
        packDir.deleteSync(recursive: true);
      }

      final service2 = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );
      await service2.restoreStates();

      expect(
        service2.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.failed),
        reason: 'State should be failed when files are missing',
      );
    });

    test('notDownloaded state is preserved across restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );

      await service.persistStates();

      final service2 = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );
      await service2.restoreStates();

      for (final pack in service2.packs) {
        expect(
          pack.downloadState,
          equals(DownloadState.notDownloaded),
          reason:
              'Pack "${pack.packId}" should remain notDownloaded after restore',
        );
      }
    });

    test('all downloaded packs are preserved when all files exist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );

      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
      }
      await service.persistStates();

      final service2 = AudioPackService(
        prefs: prefs,
        getDocsDir: () async => tempDir,
      );
      await service2.restoreStates();

      for (final pack in service2.packs) {
        expect(
          pack.downloadState,
          equals(DownloadState.downloaded),
          reason:
              'Pack "${pack.packId}" should be downloaded after restore when files exist',
        );
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P8 — Pack Size Consistency
// ---------------------------------------------------------------------------

void _p8Tests() {
  group('Pack size consistency — P8', () {
    // Feature: offline-audio-packs, Property P8: Pack Size Consistency —
    // for every pack in allAudioPacks, totalSizeBytes == sum of all track fileSizeBytes
    // Validates: Requirements 1.6

    test('totalSizeBytes equals sum of track fileSizeBytes for every pack', () {
      for (final pack in allAudioPacks) {
        final computedTotal =
            pack.tracks.map((t) => t.fileSizeBytes).reduce((a, b) => a + b);
        expect(
          pack.totalSizeBytes,
          equals(computedTotal),
          reason:
              'Pack "${pack.packId}" has totalSizeBytes=${pack.totalSizeBytes} '
              'but sum of track sizes is $computedTotal',
        );
      }
    });

    test('totalSizeBytes is greater than zero for every pack', () {
      for (final pack in allAudioPacks) {
        expect(
          pack.totalSizeBytes,
          greaterThan(0),
          reason: 'Pack "${pack.packId}" has non-positive totalSizeBytes',
        );
      }
    });

    test('each track has a positive fileSizeBytes', () {
      for (final pack in allAudioPacks) {
        for (final track in pack.tracks) {
          expect(
            track.fileSizeBytes,
            greaterThan(0),
            reason:
                'Track "${track.trackId}" in pack "${pack.packId}" has non-positive fileSizeBytes',
          );
        }
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P9 — Content Category Completeness
// ---------------------------------------------------------------------------

void _p9Tests() {
  group('Content category completeness — P9', () {
    // Feature: offline-audio-packs, Property P9: Content Category Completeness —
    // for every pack, ContentCategory.values.every((cat) => pack.tracks.any((t) => t.category == cat))
    // Validates: Requirements 1.7

    test('every ContentCategory is represented in every pack', () {
      for (final pack in allAudioPacks) {
        for (final category in ContentCategory.values) {
          final hasCategory = pack.tracks.any((t) => t.category == category);
          expect(
            hasCategory,
            isTrue,
            reason:
                'Pack "${pack.packId}" is missing a track for category '
                '"${category.name}"',
          );
        }
      }
    });

    test('all packs have at least as many tracks as ContentCategory values', () {
      for (final pack in allAudioPacks) {
        expect(
          pack.tracks.length,
          greaterThanOrEqualTo(ContentCategory.values.length),
          reason:
              'Pack "${pack.packId}" has ${pack.tracks.length} tracks but '
              'needs at least ${ContentCategory.values.length}',
        );
      }
    });
  });
}


// ---------------------------------------------------------------------------
// P10 — Deterministic State Transitions
// ---------------------------------------------------------------------------

void _p10Tests() {
  group('Deterministic state transitions — P10', () {
    // Feature: offline-audio-packs, Property P10: Deterministic State Transitions —
    // only valid transitions are notDownloaded→downloading→downloaded and
    // notDownloaded→downloading→failed; no other transitions occur without
    // explicit user action.
    // Validates: Requirements 3.1, 3.4, 3.5, NFR 2.1

    late Directory tempDir;
    late AudioPackService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('audio_pack_test_p10_');
      service = await _makeService(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('initial state is notDownloaded for all packs', () {
      for (final pack in service.packs) {
        expect(
          pack.downloadState,
          equals(DownloadState.notDownloaded),
          reason: 'Pack "${pack.packId}" should start as notDownloaded',
        );
      }
    });

    test(
        'state transitions notDownloaded → downloading → downloaded on success',
        () async {
      final packId = allAudioPacks.first.packId;
      final states = <DownloadState>[];

      states.add(
          service.packs.firstWhere((p) => p.packId == packId).downloadState);

      bool capturedDuringDownload = false;
      await service.downloadPack(packId, (progress) {
        if (!capturedDuringDownload) {
          states.add(service.packs
              .firstWhere((p) => p.packId == packId)
              .downloadState);
          capturedDuringDownload = true;
        }
      }, CancellationToken());

      states.add(
          service.packs.firstWhere((p) => p.packId == packId).downloadState);

      expect(states[0], equals(DownloadState.notDownloaded));
      expect(states[1], equals(DownloadState.downloading));
      expect(states[2], equals(DownloadState.downloaded));
    });

    test(
        'state transitions notDownloaded → downloading → notDownloaded on cancel',
        () async {
      final packId = allAudioPacks.first.packId;
      final token = CancellationToken();
      token.cancel();
      await service.downloadPack(packId, _noop, token);

      final finalState =
          service.packs.firstWhere((p) => p.packId == packId).downloadState;
      expect(finalState, equals(DownloadState.notDownloaded));
    });

    test('downloaded → notDownloaded on delete (no other transition)', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());
      expect(
        service.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.downloaded),
      );

      await service.deletePack(packId);
      expect(
        service.packs.firstWhere((p) => p.packId == packId).downloadState,
        equals(DownloadState.notDownloaded),
      );
    });

    test('other packs are not affected by a single pack download', () async {
      final packId = allAudioPacks.first.packId;
      await service.downloadPack(packId, _noop, CancellationToken());

      for (final pack in service.packs) {
        if (pack.packId == packId) continue;
        expect(
          pack.downloadState,
          equals(DownloadState.notDownloaded),
          reason:
              'Pack "${pack.packId}" should not be affected by downloading "$packId"',
        );
      }
    });

    test('other packs are not affected by a single pack delete', () async {
      for (final pack in allAudioPacks) {
        await service.downloadPack(pack.packId, _noop, CancellationToken());
      }

      final packId = allAudioPacks.first.packId;
      await service.deletePack(packId);

      for (final pack in service.packs) {
        if (pack.packId == packId) continue;
        expect(
          pack.downloadState,
          equals(DownloadState.downloaded),
          reason:
              'Pack "${pack.packId}" should not be affected by deleting "$packId"',
        );
      }
    });

    test('no spontaneous state changes without user action', () async {
      final statesBefore = {
        for (final p in service.packs) p.packId: p.downloadState
      };

      await Future.delayed(const Duration(milliseconds: 50));

      final statesAfter = {
        for (final p in service.packs) p.packId: p.downloadState
      };

      for (final packId in statesBefore.keys) {
        expect(
          statesAfter[packId],
          equals(statesBefore[packId]),
          reason: 'Pack "$packId" changed state without user action',
        );
      }
    });
  });
}
