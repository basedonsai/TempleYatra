# Design Document: Offline Audio Packs

## Overview

The Offline Audio Packs feature adds downloadable temple audio content to the Temple Yatra app. It is a fully offline, no-backend MVP: pack metadata is hardcoded, and "downloads" are simulated by writing small placeholder `.aac` files to the app's documents directory via `path_provider`. State is persisted in `SharedPreferences`. The feature integrates additively with `StorytellingScreen` (offline badge + local file playback fallback) and `TempleDetailScreen` (new Audio Pack section).

Key constraints:
- No new backend, no HTTP calls
- `path_provider` (already in pubspec) for persistent storage — not `Directory.systemTemp`
- `shared_preferences` (already in pubspec) for state persistence
- `just_audio` added for local file playback (not currently in pubspec)
- All existing screens remain unmodified except for additive enhancements

---

## Architecture

### Data Flow

```
Pack_Catalog (hardcoded data)
        |
        v
AudioPackNotifier (Riverpod StateNotifier)
        |  reads/writes
        v
AudioPackService
   |-- DownloadManager  --> path_provider (app documents dir)
   |       |                  /audio_packs/{packId}/{trackId}.aac
   |       +-- progress stream (StreamController<double>)
   |-- StorageManager   --> sums totalSizeBytes of downloaded packs
   +-- PersistenceManager -> SharedPreferences (JSON map packId->state)
        |
        v
UI Layer
   |-- OfflineAudioScreen  (new)
   |-- TempleDetailScreen  (additive: AudioPackSection widget)
   +-- StorytellingScreen  (additive: offline badge + local player)
```

### State Machine

```
                  +----------------------------------+
                  |                                  |
         tap Download                           tap Retry
                  |                                  |
    +-------------v---------+         +-------------+---------+
    |     notDownloaded     |         |         failed        |
    +-----------------------+         +-----------------------+
                  |                                  ^
         startDownload()                      I/O error or
                  |                          app-kill detected
                  v                                  |
    +-------------------------+                      |
    |       downloading       |----------------------+
    +-------------------------+
         |              |
    completes        tap Cancel
         |              |
         v              v
    +----------+   +------------------------+
    |downloaded|   |  notDownloaded         |
    +----------+   |  (partial files deleted)|
         |         +------------------------+
    tap Delete
         |
         v
    +------------------------+
    |     notDownloaded      |
    |  (all files deleted)   |
    +------------------------+
```

Valid transitions (no others permitted without user action):
- `notDownloaded -> downloading` (user taps Download)
- `downloading -> downloaded` (simulation completes)
- `downloading -> failed` (I/O error)
- `downloading -> notDownloaded` (user taps Cancel)
- `downloaded -> notDownloaded` (user confirms Delete)
- `failed -> notDownloaded` (user taps Retry, resets to allow re-download)

---

## File / Directory Structure

New files to create:

```
lib/
  models/
    audio_pack.dart            # AudioPack, AudioTrack, DownloadState, ContentCategory
  data/
    audio_pack_data.dart       # Pack_Catalog (hardcoded, 3+ temples)
  services/
    audio_pack_service.dart    # AudioPackService (Download + Storage + Persistence)
  providers/
    audio_pack_provider.dart   # AudioPackNotifier + providers
  widgets/
    audio_pack_section.dart    # AudioPackSection widget (TempleDetailScreen)
    offline_badge.dart         # "Offline Available" badge (StorytellingScreen)
  screens/
    offline_audio_screen.dart  # replaces stub offline_pack_manager_screen.dart
test/
  audio_pack_service_test.dart    # unit + property tests (P1-P10)
  offline_audio_screen_test.dart  # widget smoke test
```

Existing files modified (additive only):
- `lib/screens/temple_detail_screen.dart` — insert `AudioPackSection` after About section
- `lib/screens/storytelling_screen.dart` — add offline badge + local player branch
- `pubspec.yaml` — add `just_audio: ^0.9.36` and `shared_preferences: ^2.2.2`

---

## Components and Interfaces

### Models (`lib/models/audio_pack.dart`)

```dart
enum DownloadState { notDownloaded, downloading, downloaded, failed }

enum ContentCategory { history, ritual, significance, travelTips }

class AudioTrack {
  final String trackId;
  final String title;
  final ContentCategory category;
  final int durationSeconds;
  final int fileSizeBytes;
  final String? localPath; // null until downloaded
}

class AudioPack {
  final String packId;
  final String templeId;
  final String title;
  final String description;
  final int totalSizeBytes;       // must equal sum(track.fileSizeBytes)
  final List<AudioTrack> tracks;
  final DownloadState downloadState;
  final double downloadProgress;  // 0.0-1.0, meaningful only when downloading
  final String? errorMessage;     // non-null only when failed

  AudioPack copyWith({...});
}
```

### Pack Catalog (`lib/data/audio_pack_data.dart`)

Hardcoded `List<AudioPack>` with entries for 3 temples. Each pack has 4 tracks (one per `ContentCategory`). `totalSizeBytes` equals the sum of track `fileSizeBytes`. No network calls.

| packId | templeId | title | totalSizeBytes |
|---|---|---|---|
| `chilkur_balaji_pack` | `chilkur_balaji` | Chilkur Balaji Audio Guide | 8,388,608 (8 MB) |
| `birla_mandir_pack` | `birla_mandir_hyderabad` | Birla Mandir Audio Guide | 7,340,032 (7 MB) |
| `jagannath_pack` | `jagannath_hyderabad` | Jagannath Temple Audio Guide | 9,437,184 (9 MB) |

Each pack's tracks (all 4 tracks, 2 MB each):

| trackId | category | durationSeconds | fileSizeBytes |
|---|---|---|---|
| `{packId}_history` | history | 180 | 2,097,152 |
| `{packId}_ritual` | ritual | 150 | 2,097,152 |
| `{packId}_significance` | significance | 120 | 2,097,152 |
| `{packId}_travelTips` | travelTips | 90 | 2,097,152 |

### AudioPackService (`lib/services/audio_pack_service.dart`)

```dart
class AudioPackService {
  // Injectable dependencies for testing
  final SharedPreferences _prefs;
  final Future<Directory> Function() _getDocsDir;

  // Download simulation
  Future<void> startDownload(
    AudioPack pack,
    void Function(double progress) onProgress,
    CancellationToken token,
  );
  Future<void> deletePackFiles(String packId);

  // Availability check
  Future<bool> isAvailableOffline(AudioPack pack);
  Future<String> getTrackPath(String packId, String trackId);

  // Storage calculation
  int getTotalUsedStorageBytes(List<AudioPack> packs);
  int getPackSizeBytes(String packId, List<AudioPack> catalog);

  // Persistence
  Future<void> persistStates(Map<String, DownloadState> states);
  Future<Map<String, DownloadState>> loadPersistedStates();
  Future<Map<String, DownloadState>> verifyAndRestoreStates(
    Map<String, DownloadState> persisted,
    List<AudioPack> catalog,
  );
}
```

#### Download Simulation Algorithm

```
startDownload(pack, onProgress, token):
  1. dir = await getApplicationDocumentsDirectory()
  2. packDir = Directory('${dir.path}/audio_packs/${pack.packId}')
  3. await packDir.create(recursive: true)
  4. completedBytes = 0
  5. for each track in pack.tracks:
       a. if token.isCancelled:
            await packDir.delete(recursive: true)
            return
       b. delayMs = track.fileSizeBytes ~/ 50000  (simulates ~50 KB/ms throughput)
       c. await Future.delayed(Duration(milliseconds: delayMs))
       d. path = '${packDir.path}/${track.trackId}.aac'
       e. await File(path).writeAsBytes(Uint8List(512))  // 512-byte placeholder
       f. completedBytes += track.fileSizeBytes
       g. onProgress(completedBytes / pack.totalSizeBytes)
  6. onProgress(1.0)
  // On IOError: rethrow as AudioPackException
```

#### State Persistence Algorithm

```
persistStates(states):
  json = jsonEncode(states.map((k, v) => MapEntry(k, v.name)))
  await prefs.setString('audio_pack_states', json)

loadPersistedStates():
  raw = prefs.getString('audio_pack_states') ?? '{}'
  map = jsonDecode(raw) as Map<String, dynamic>
  return map.map((k, v) => MapEntry(k,
    DownloadState.values.firstWhere((e) => e.name == v,
      orElse: () => DownloadState.notDownloaded)))

verifyAndRestoreStates(persisted, catalog):
  for each (packId, state) in persisted where state == downloaded:
    pack = catalog.firstWhereOrNull((p) => p.packId == packId)
    if pack == null: persisted[packId] = notDownloaded; continue
    allExist = await isAvailableOffline(pack)
    if !allExist: persisted[packId] = failed
  return persisted
```

### Riverpod Providers (`lib/providers/audio_pack_provider.dart`)

```dart
// Catalog provider — overridable in tests
final audioPackCatalogProvider = Provider<List<AudioPack>>((_) => packCatalog);

// SharedPreferences provider (initialized in main.dart before runApp)
final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

// Service provider
final audioPackServiceProvider = Provider<AudioPackService>((ref) {
  return AudioPackService(prefs: ref.watch(sharedPreferencesProvider));
});

// State notifier
class AudioPackNotifier extends StateNotifier<List<AudioPack>> {
  Future<void> _init();           // load + verify persisted state on startup
  Future<void> download(String packId);
  Future<void> cancel(String packId);
  Future<void> delete(String packId);
  Future<void> retry(String packId); // reset to notDownloaded, then download
  int get totalUsedStorageBytes;
  int get downloadedPackCount;
}

final audioPackProvider =
    StateNotifierProvider<AudioPackNotifier, List<AudioPack>>(...);

// Convenience selector: pack for a specific temple (null if none)
final packForTempleProvider = Provider.family<AudioPack?, String>(
  (ref, templeId) => ref.watch(audioPackProvider)
      .where((p) => p.templeId == templeId)
      .firstOrNull,
);
```

### Widgets

#### `AudioPackSection` (`lib/widgets/audio_pack_section.dart`)

Used inside `TempleDetailScreen`. Renders `SizedBox.shrink()` if no pack exists for the temple.

```
AudioPackSection(templeId: temple.id)
  Consumer -> watches packForTempleProvider(templeId)
    pack == null          -> SizedBox.shrink()
    notDownloaded         -> title + size + Download button
    downloading           -> title + LinearProgressIndicator + "X%" + Cancel
    downloaded            -> title + size + Play Offline + Delete buttons
    failed                -> title + errorMessage + Retry button
```

#### `OfflineBadge` (`lib/widgets/offline_badge.dart`)

Small chip shown in `StorytellingScreen` AppBar when a downloaded pack is available.

```dart
// Renders: Chip(label: 'Offline Available', avatar: Icon(Icons.offline_bolt), ...)
class OfflineBadge extends StatelessWidget { ... }
```

### Screens

#### `OfflineAudioScreen` (`lib/screens/offline_audio_screen.dart`)

Replaces the stub `offline_pack_manager_screen.dart`. Full Riverpod-powered implementation.

```
Scaffold
  AppBar: "Offline Audio Packs"
  Body: Column
    StorageSummaryCard (pinned at top)
      "X.X MB used  |  Y packs downloaded"
    Expanded -> ListView.builder
      AudioPackCard (per pack)
        notDownloaded: pack info + Download button
        downloading:   pack info + LinearProgressIndicator + "45%" + Cancel
        downloaded:    pack info + Play button + Delete button
        failed:        pack info + error text + Retry button
```

---

## Data Models

### AudioPack field constraints

| Field | Type | Constraint |
|---|---|---|
| packId | String | unique across catalog |
| templeId | String | matches a Temple.id in allTemples |
| title | String | non-empty |
| description | String | non-empty |
| totalSizeBytes | int | > 0, == sum(track.fileSizeBytes) |
| tracks | List\<AudioTrack\> | >= 1 per ContentCategory value |
| downloadState | DownloadState | one of 4 enum values, never null |
| downloadProgress | double | in [0.0, 1.0] when downloading |
| errorMessage | String? | non-null only when failed |

### SharedPreferences Schema

Key: `audio_pack_states`
Value: JSON string — `{"chilkur_balaji_pack":"downloaded","birla_mandir_pack":"notDownloaded"}`

Only `DownloadState.name` strings are stored. Unknown values on load default to `notDownloaded`.

### File Storage Layout

```
{getApplicationDocumentsDirectory()}/
  audio_packs/
    chilkur_balaji_pack/
      chilkur_balaji_pack_history.aac      (512-byte placeholder)
      chilkur_balaji_pack_ritual.aac
      chilkur_balaji_pack_significance.aac
      chilkur_balaji_pack_travelTips.aac
    birla_mandir_pack/
      ...
    jagannath_pack/
      ...
```

---

## Integration Spec

### StorytellingScreen Integration

Additive changes only — no existing logic removed.

1. Add `Consumer` around AppBar `actions` to watch `packForTempleProvider(templeId)`.
2. If pack is downloaded: show `OfflineBadge` in AppBar actions.
3. Add `bool _useOfflineAudio = false` state field; show toggle `IconButton` only when pack is downloaded.
4. In `_togglePlayPause()`: if `_useOfflineAudio && pack?.downloadState == downloaded`:
   - Use `just_audio` `AudioPlayer.setFilePath(track.localPath!)` then `play()`.
   - Track selection: map `_selectedContentType` to `ContentCategory` (see table below).
   - Otherwise: existing TTS path unchanged.
5. In `dispose()`: call `_audioPlayer?.dispose()`.

ContentCategory to ContentType mapping:

| ContentCategory | ContentType |
|---|---|
| history | ContentType.history |
| ritual | ContentType.ritual |
| significance | ContentType.significance |
| travelTips | ContentType.sthalaPuranam |

### TempleDetailScreen Integration

Insert `AudioPackSection(templeId: temple.id)` as a new child in the `Column` inside `SliverToBoxAdapter`, after the "About" `_buildSection` and before the "Festivals" `_buildSection`. No other changes.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Download State Exhaustiveness

*For any* `AudioPack` at any point in time, its `downloadState` must be one of `{notDownloaded, downloading, downloaded, failed}` — never null, never an unlisted value.

**Validates: Requirements 1.3, P1**

### Property 2: Progress Bounds Invariant

*For any* download operation on any `AudioPack`, every progress value emitted by the `DownloadManager` must be in the closed interval [0.0, 1.0].

**Validates: Requirements 3.2, P2**

### Property 3: Storage Sum Invariant

*For any* collection of `AudioPack` objects, `getTotalUsedStorageBytes()` must equal the sum of `totalSizeBytes` for all packs whose `downloadState` is `downloaded`.

**Validates: Requirements 6.5, P3**

### Property 4: Download-Delete Round-Trip

*For any* `AudioPack`, the sequence `download -> delete -> download` must result in the same final `downloaded` state as a single `download` operation, with all track files present and `isAvailableOffline` returning `true`.

**Validates: Requirements 4.4, 7.3, P4**

### Property 5: Offline Availability Consistency

*For any* `AudioPack` with `downloadState == downloaded`, `isAvailableOffline(packId)` must return `true`. For any pack with `downloadState != downloaded`, it must return `false`.

**Validates: Requirements 5.6, P5**

### Property 6: File Existence After Download

*For any* `AudioPack` after a successful download, all `AudioTrack` objects must have a non-null `localPath` pointing to an existing, readable file on the device.

**Validates: Requirements 3.4, P6**

### Property 7: State Persistence Round-Trip

*For any* `AudioPack` with `downloadState == downloaded` and all files present, persisting state then restoring it (simulating app restart) must preserve `downloadState == downloaded`. If any file is missing, the restored state must be `failed`.

**Validates: Requirements 8.2, 8.3, 8.4, P7**

### Property 8: Pack Size Consistency

*For any* `AudioPack` in the Pack_Catalog, `totalSizeBytes` must equal the sum of `fileSizeBytes` for all tracks in the pack.

**Validates: Requirements 1.6, P8**

### Property 9: Content Category Completeness

*For any* `AudioPack` in the Pack_Catalog, the `tracks` list must contain at least one `AudioTrack` for each value in the `ContentCategory` enum.

**Validates: Requirements 1.7, P9**

### Property 10: Deterministic State Transitions

*For any* `AudioPack`, the only valid state transitions are: `notDownloaded -> downloading`, `downloading -> downloaded`, `downloading -> failed`, `downloading -> notDownloaded` (cancel), `downloaded -> notDownloaded` (delete), `failed -> notDownloaded` (retry). No other transitions may occur without explicit user action.

**Validates: Requirements 3.1, 3.4, 3.5, NFR 2.1, P10**

### Property 11: UI Controls Match Download State

*For any* `AudioPack` in any `DownloadState`, the rendered `AudioPackCard` widget must display exactly the controls appropriate for that state: Download button (notDownloaded), progress bar + Cancel (downloading), Play + Delete (downloaded), error text + Retry (failed).

**Validates: Requirements 2.3, 2.4, 2.5, 2.6**

---

## Error Handling

| Scenario | Detection | Response | User-Visible Message |
|---|---|---|---|
| I/O error during simulated write | `IOError` in `startDownload` | Transition to `failed`, set `errorMessage` | "Download failed. Tap Retry." |
| App killed during download | On next launch: `downloading` state in prefs | `verifyAndRestoreStates` transitions to `failed` | "Download was interrupted. Tap Retry." |
| File missing after restart | `isAvailableOffline` returns false for `downloaded` pack | Transition to `failed` | "Audio files missing. Tap Retry." |
| Delete called on non-downloaded pack | `downloadState != downloaded` | No-op, no error thrown | None |
| Duplicate packId in catalog | Detected in `AudioPackNotifier._init()` | Throw `StateError` at startup | Dev assertion failure only |
| Download called on already-downloaded pack | `downloadState == downloaded` | No-op | SnackBar: "Already downloaded." |
| Out of storage during write | `FileSystemException` | Transition to `failed` | "Insufficient storage space." |
| `just_audio` fails to open local file | `PlayerException` | Fall back to TTS silently | None (TTS plays instead) |

---

## Testing Strategy

### Dual Testing Approach

Unit tests cover specific examples, edge cases, and state machine transitions. Property-based tests verify universal invariants across all inputs. Both are required and complementary.

### Property-Based Testing

Use the `test` package with a `Random`-seeded generator helper that produces arbitrary `AudioPack` instances. Each property test runs a minimum of 100 iterations. If `dart_quickcheck` or a similar library is available on pub.dev at implementation time, prefer it over a manual generator.

Each property test must include a comment tag:
```dart
// Feature: offline-audio-packs, Property N: <property_text>
```

### Unit Tests (`test/audio_pack_service_test.dart`)

```
group('DownloadState enum — P1')
  test: has exactly 4 values
  test: values are notDownloaded, downloading, downloaded, failed

group('Pack size consistency — P8')
  property test (100 iterations): totalSizeBytes == sum(track.fileSizeBytes)

group('Content category completeness — P9')
  property test (100 iterations): all ContentCategory values present in tracks

group('Download state machine — P10')
  test: notDownloaded -> downloading on startDownload
  test: downloading -> downloaded on completion
  test: downloading -> failed on IOError
  test: downloading -> notDownloaded on cancel (no orphaned files)
  test: downloaded -> notDownloaded on delete
  test: failed -> notDownloaded on retry

group('Progress bounds — P2')
  property test (100 iterations): all emitted progress values in [0.0, 1.0]

group('Storage sum invariant — P3')
  property test (100 iterations): getTotalUsedStorageBytes == sum of downloaded pack sizes

group('isAvailableOffline consistency — P5')
  property test (100 iterations): downloaded state <-> isAvailableOffline true

group('State persistence round-trip — P7')
  test: persist then load returns same states
  test: persist downloaded, delete file, load -> failed state

group('Download-delete round-trip — P4')
  test: download -> delete -> download results in downloaded state with files present

group('Edge cases')
  test: delete on notDownloaded pack does not throw
  test: download on already-downloaded pack is a no-op
```

### Widget Smoke Test (`test/offline_audio_screen_test.dart`)

```
test: OfflineAudioScreen renders without error
  - Override audioPackCatalogProvider with 3 test packs
    (one notDownloaded, one downloading at 0.45, one downloaded)
  - pumpWidget(ProviderScope(overrides: [...], child: OfflineAudioScreen()))
  - expect: finds StorageSummaryCard
  - expect: finds 3 pack cards
  - expect: finds 'Download' text (notDownloaded pack)
  - expect: finds LinearProgressIndicator (downloading pack)
  - expect: finds 'Delete' text (downloaded pack)
```

### Unit Test Balance

Unit tests focus on concrete state machine transitions, edge cases, and integration points. Property tests handle broad input coverage. Avoid duplicating coverage between the two — unit tests should not re-test what property tests already cover universally.
