# Implementation Plan: Offline Audio Packs

## Overview

Implement downloadable audio packs for temple content with offline playback. The feature is MVP-scoped: no backend, simulated downloads writing placeholder `.aac` files, SharedPreferences persistence, and additive integration into existing screens.

## Tasks

- [x] 1. Define data models
  - [x] 1.1 Create `lib/models/audio_pack.dart` with `DownloadState` enum (`notDownloaded`, `downloading`, `downloaded`, `failed`), `ContentCategory` enum (`history`, `ritual`, `significance`, `travelTips`), `AudioTrack` class (fields: `trackId`, `title`, `category`, `durationSeconds`, `fileSizeBytes`, `localPath`), and `AudioPack` class (fields: `packId`, `templeId`, `title`, `description`, `totalSizeBytes`, `tracks`, `downloadState`)
  - No JSON serialization needed — models are in-memory with SharedPreferences persistence handled by the service
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Create Pack Catalog data
  - [x] 2.1 Create `lib/data/audio_pack_data.dart` with a top-level `List<AudioPack> allAudioPacks` constant containing exactly 3 packs: Chilkur Balaji (`templeId: 'chilkur_balaji'`), Birla Mandir (`templeId: 'birla_mandir'`), and Jagannath Temple (`templeId: 'jagannath_puri'`)
  - Each pack must have at least one `AudioTrack` per `ContentCategory` value (4 tracks minimum per pack)
  - Each pack's `totalSizeBytes` must equal the sum of its tracks' `fileSizeBytes`
  - All `downloadState` values in the catalog must be initialized to `DownloadState.notDownloaded`
  - _Requirements: 1.5, 1.6, 1.7, 9.1_

  - [x] 2.2 Write property test for Pack Catalog structural invariants
    - **Property P8: Pack Size Consistency** — for every pack in `allAudioPacks`, assert `pack.totalSizeBytes == pack.tracks.map((t) => t.fileSizeBytes).reduce((a, b) => a + b)`
    - **Property P9: Content Category Completeness** — for every pack, assert that `ContentCategory.values.every((cat) => pack.tracks.any((t) => t.category == cat))`
    - **Validates: Requirements 1.6, 1.7**

- [x] 3. Implement `AudioPackService`
  - [x] 3.1 Create `lib/services/audio_pack_service.dart` with injectable constructor: `AudioPackService({required SharedPreferences prefs, required Future<Directory> Function() getDocsDir})`
  - Implement `CancellationToken` class with a `cancel()` method and `isCancelled` bool
  - Implement `Future<void> downloadPack(String packId, void Function(double) onProgress, CancellationToken token)`: transitions state to `downloading`, simulates download by writing 512-byte placeholder `.aac` files to `{docsDir}/audio_packs/{packId}/{trackId}.aac` with a timed `Future.delayed` per track, emits progress from 0.0 to 1.0, transitions to `downloaded` on success or `failed` on error/cancellation; on cancellation deletes partial files and sets state to `notDownloaded`
  - Implement `Future<void> deletePack(String packId)`: deletes all files under `{docsDir}/audio_packs/{packId}/`, transitions state to `notDownloaded`; no-op if already deleted
  - Implement `bool isAvailableOffline(String packId)`: returns `true` iff state is `downloaded` AND all track `localPath` files exist
  - Implement `int getTotalUsedStorageBytes()`: sum of `totalSizeBytes` for all packs with state `downloaded`
  - Implement `Future<void> persistStates()`: writes `Map<packId, DownloadState.name>` to SharedPreferences key `'audio_pack_states'`
  - Implement `Future<void> restoreStates()`: reads the map from SharedPreferences; for each pack with persisted state `downloaded`, verifies all files exist — if any missing, sets state to `failed`
  - _Requirements: 3.1–3.7, 4.1–4.5, 5.6, 6.5–6.7, 7.3–7.7, 8.1–8.5, 9.2–9.5_

  - [x] 3.2 Write property tests for `AudioPackService` state machine (P1–P7, P10)
    - **Property P1: Download State Exhaustiveness** — after any operation, `pack.downloadState` is always one of the four enum values
    - **Property P2: Progress Bounds** — all `onProgress` callbacks during download receive values in `[0.0, 1.0]`
    - **Property P3: Storage Sum Invariant** — `getTotalUsedStorageBytes()` equals sum of `totalSizeBytes` for downloaded packs (within 1% tolerance)
    - **Property P4: Download-Delete Round-Trip** — `download → delete → download` yields same final state as single `download`
    - **Property P5: Offline Availability Consistency** — `isAvailableOffline` returns `true` iff state is `downloaded`
    - **Property P6: File Existence After Download** — after download, all tracks have non-null `localPath` pointing to existing files
    - **Property P7: State Persistence Round-Trip** — `persistStates` then `restoreStates` preserves `downloaded` state when files exist; sets `failed` when files are missing
    - **Property P10: Deterministic State Transitions** — only valid transitions are `notDownloaded→downloading→downloaded` and `notDownloaded→downloading→failed`; no other transitions occur without explicit user action
    - Use injectable constructor to inject a temp directory and a mock `SharedPreferences` (use `shared_preferences` test helpers)
    - File: `test/audio_pack_service_test.dart`
    - **Validates: Requirements 3.1–3.7, 4.4, 5.6, 8.1–8.5**

- [x] 4. Implement Riverpod providers
  - [x] 4.1 Create `lib/providers/audio_pack_provider.dart` with:
    - `audioPackServiceProvider`: a `Provider<AudioPackService>` that constructs the service with real `SharedPreferences` and `getApplicationDocumentsDirectory`; call `restoreStates()` in the provider's `create` (use `ref.read` with a `FutureProvider` or initialize lazily)
    - `AudioPackNotifier extends AsyncNotifier<List<AudioPack>>`: holds the mutable list of packs (initialized from `allAudioPacks` with states restored from service); exposes `download(packId)`, `cancelDownload(packId)`, `deletePack(packId)`, `retryDownload(packId)` methods that delegate to `AudioPackService` and call `state = AsyncData(updatedList)` after each mutation
    - `audioPackProvider`: `AsyncNotifierProvider<AudioPackNotifier, List<AudioPack>>`
    - `packForTempleProvider(String templeId)`: a `Provider.family` that selects the single `AudioPack?` for a given `templeId` from `audioPackProvider`
  - _Requirements: 3.1–3.7, 4.1–4.5, 6.3–6.4, 8.2_

- [x] 5. Implement widgets
  - [x] 5.1 Create `lib/widgets/audio_pack_section.dart` — a `ConsumerWidget` that accepts a `Temple` and uses `packForTempleProvider` to render the Audio Pack card: shows pack title, size in MB, and a state-appropriate action button (Download / Cancel + progress bar / Play Offline + Delete / Retry + error text); tapping Download calls `notifier.download(packId)`, Cancel calls `notifier.cancelDownload(packId)`, Delete shows a confirmation dialog then calls `notifier.deletePack(packId)`, Play Offline navigates to `StorytellingScreen`; returns `SizedBox.shrink()` when no pack exists for the temple
  - _Requirements: 10.1–10.5_

  - [x] 5.2 Create `lib/widgets/offline_badge.dart` — a small `ConsumerWidget` that accepts a `packId` and renders a green "Offline Available" chip using `packForTempleProvider`; renders nothing when pack is not downloaded
  - _Requirements: 5.2_

- [x] 6. Implement `OfflineAudioScreen`
  - [x] 6.1 Replace the stub in `lib/screens/offline_pack_manager_screen.dart` with a full `ConsumerWidget` implementation:
    - Storage summary card at top: reads `audioPackProvider` to compute total used MB and downloaded pack count via `audioPackService.getTotalUsedStorageBytes()`
    - `ListView` of all packs from `audioPackProvider`, each rendered as a `Card` showing title, temple name, description, size in MB, and state-appropriate controls (matching Requirement 2.3–2.6)
    - Download progress shown as `LinearProgressIndicator` with percentage text
    - Loading state while `audioPackProvider` is `AsyncLoading`
  - _Requirements: 2.1–2.7, 6.1–6.4_

- [x] 7. Integrate `AudioPackSection` into `TempleDetailScreen`
  - [x] 7.1 Edit `lib/screens/temple_detail_screen.dart`: add `import '../widgets/audio_pack_section.dart'`; insert `AudioPackSection(temple: temple)` and a `SizedBox(height: 14)` spacer between the About section and the Festivals section — no other changes to existing sections
  - Convert `TempleDetailScreen` from `StatelessWidget` to `ConsumerWidget` only if not already done (it already uses `Consumer` inline, so the class itself can stay `StatelessWidget`)
  - _Requirements: 10.1–10.5_

- [x] 8. Integrate offline audio into `StorytellingScreen`
  - [x] 8.1 Edit `lib/screens/storytelling_screen.dart`:
    - Add `import 'package:flutter_riverpod/flutter_riverpod.dart'` and `import '../providers/audio_pack_provider.dart'` and `import '../widgets/offline_badge.dart'`
    - Change `StorytellingScreen` to `ConsumerStatefulWidget` / `_StorytellingScreenState` to `ConsumerState`
    - Add `bool _useOfflineAudio = false` state field
    - In `initState`, after services init, check `ref.read(packForTempleProvider(widget.templeId))` — if pack is downloaded, set `_useOfflineAudio = true`
    - In `_buildOfflineIndicator()`, replace the existing `FutureBuilder` with a `Consumer` that reads `packForTempleProvider` and shows `OfflineBadge` when downloaded
    - In `_togglePlayPause()`, when `_useOfflineAudio` is true and a track `localPath` exists for the current `_selectedContentType` (map `ContentType` → `ContentCategory`: `sthalaPuranam/history→history`, `ritual→ritual`, `significance→significance`; default to first track), use `just_audio`'s `AudioPlayer().setFilePath(localPath)` then `play()` instead of TTS
    - Add a toggle icon button in the AppBar actions (between language selector and offline indicator) that switches `_useOfflineAudio` when a downloaded pack is available; show tooltip "Use Offline Audio" / "Use TTS"
  - _Requirements: 5.1–5.5_

- [x] 9. Add `just_audio` to `pubspec.yaml`
  - [x] 9.1 Edit `pubspec.yaml`: add `just_audio: ^0.9.36` under `dependencies`, after the `flutter_tts` entry
  - _Requirements: 5.3, NFR 3.1_

- [x] 10. Unit tests for `AudioPackService`
  - [x] 10.1 Ensure `test/audio_pack_service_test.dart` (created in task 3.2) covers all 10 properties P1–P10 as individual `test()` cases within a `group('AudioPackService')` block
  - Each test must use the injectable constructor with `path_provider_platform_interface` or a temp directory from `Directory.systemTemp.createTempSync()`
  - Use `SharedPreferences.setMockInitialValues({})` for persistence tests
  - _Requirements: NFR 4.1–4.3_

- [x] 11. Widget smoke test for `OfflineAudioScreen`
  - [x] 11.1 Create `test/offline_audio_screen_test.dart`: pump `ProviderScope(overrides: [audioPackProvider.overrideWith(...)], child: MaterialApp(home: OfflinePackManagerScreen()))`, assert storage summary card is present, assert at least one pack card renders with a "Download" button
  - _Requirements: NFR 4.2_

- [x] 12. Final checkpoint
  - Ensure all non-optional tests pass (`flutter test --run`), ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Task 9 (pubspec.yaml) must be done before task 8 compiles; run `flutter pub get` after editing
- `just_audio` is only used in `StorytellingScreen` for local file playback; TTS path is unchanged
- The existing `OfflinePackManagerScreen` stub is replaced in-place (task 6) — no new file needed
- Property tests (P1–P10) are all in `test/audio_pack_service_test.dart` (tasks 3.2 and 10.1 are the same file)
