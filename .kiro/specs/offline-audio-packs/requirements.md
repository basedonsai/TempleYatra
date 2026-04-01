# Requirements Document

## Introduction

The Offline Audio Packs feature enables users to download temple-specific audio content for offline playback in the Temple Yatra app. Currently, the storytelling feature relies on real-time TTS (text-to-speech) generation, which requires an active internet connection. This feature introduces downloadable audio packs containing pre-recorded narrations about temple history, rituals, significance, and travel tips. Users can download packs for their favorite temples, view download progress and storage usage, and play content offline. The feature is designed as an MVP with no backend dependency — all pack metadata is hardcoded, and audio files are bundled or simulated locally. The implementation integrates seamlessly with the existing `StorytellingScreen` and maintains compatibility with the current audio playback architecture.

---

## Glossary

- **Audio_Pack**: A downloadable collection of audio tracks for a specific temple, containing narrations about history, rituals, significance, and travel tips.
- **AudioPack**: The data model representing a single audio pack with metadata (templeId, title, description, totalSizeBytes, tracks, downloadState).
- **AudioTrack**: A single audio file within an AudioPack, representing one piece of content (e.g., "Sthala Puranam", "Morning Rituals").
- **Download_State**: An enum with values `notDownloaded`, `downloading`, `downloaded`, `failed` representing the current status of an audio pack.
- **Audio_Pack_Service**: The service layer responsible for managing audio pack downloads, storage, and state persistence.
- **Audio_Pack_Manager**: The Riverpod provider that exposes audio pack state and operations to the UI.
- **Pack_Catalog**: The local data source (`lib/data/audio_pack_data.dart`) that provides hardcoded AudioPack metadata for all temples.
- **Download_Manager**: The component within Audio_Pack_Service that handles download operations, progress tracking, and file I/O.
- **Storage_Manager**: The component that tracks used storage, calculates pack sizes, and manages file deletion.
- **Offline_Audio_Screen**: A new screen displaying the list of available audio packs with download controls and storage info.
- **Storytelling_Screen**: The existing `lib/screens/storytelling_screen.dart` that will be enhanced to use downloaded audio packs when available.
- **Content_Category**: An enum representing the type of audio content: `history`, `ritual`, `significance`, `travelTips`.
- **Temple**: The existing `Temple` model in `lib/models/temple_model.dart`.

---

## Requirements

### Requirement 1: Audio Pack Data Model

**User Story:** As a developer, I want a structured `AudioPack` model with typed fields for metadata and tracks, so that audio pack data can be queried, downloaded, and tested programmatically.

#### Acceptance Criteria

1. THE Audio_Pack SHALL define an `AudioPack` model with fields: `packId` (String), `templeId` (String), `title` (String), `description` (String), `totalSizeBytes` (int), `tracks` (List<AudioTrack>), and `downloadState` (Download_State).
2. THE Audio_Pack SHALL define an `AudioTrack` model with fields: `trackId` (String), `title` (String), `category` (Content_Category), `durationSeconds` (int), `fileSizeBytes` (int), and `localPath` (String?).
3. THE Audio_Pack SHALL define `Download_State` as an enum with exactly four values: `notDownloaded`, `downloading`, `downloaded`, `failed`.
4. THE Audio_Pack SHALL define `Content_Category` as an enum with values: `history`, `ritual`, `significance`, `travelTips`.
5. THE Pack_Catalog SHALL provide at least one `AudioPack` entry for each temple in `allTemples`.
6. FOR ALL `AudioPack` objects in Pack_Catalog, `totalSizeBytes` SHALL be greater than zero and SHALL equal the sum of `fileSizeBytes` of all tracks in the pack.
7. FOR ALL `AudioPack` objects in Pack_Catalog, the `tracks` list SHALL contain at least one track per `Content_Category` value.

---

### Requirement 2: Audio Pack Catalog Display

**User Story:** As a devotee, I want to see a list of available audio packs for temples, so that I can choose which packs to download for offline use.

#### Acceptance Criteria

1. THE Offline_Audio_Screen SHALL display a list of all `AudioPack` entries from the Pack_Catalog.
2. WHEN an `AudioPack` is displayed, THE Offline_Audio_Screen SHALL show the pack title, temple name, description, total size in MB, and current `Download_State`.
3. WHEN the `Download_State` is `notDownloaded`, THE Offline_Audio_Screen SHALL display a "Download" button.
4. WHEN the `Download_State` is `downloading`, THE Offline_Audio_Screen SHALL display a progress indicator showing download percentage.
5. WHEN the `Download_State` is `downloaded`, THE Offline_Audio_Screen SHALL display a "Delete" button and a "Play" button.
6. WHEN the `Download_State` is `failed`, THE Offline_Audio_Screen SHALL display a "Retry" button and an error message.
7. THE Offline_Audio_Screen SHALL be navigable from the main navigation menu or temple detail screen.

---

### Requirement 3: Download Initiation and Progress

**User Story:** As a devotee, I want to download an audio pack and see real-time progress, so that I know when the content is ready for offline use.

#### Acceptance Criteria

1. WHEN the user taps the "Download" button for an `AudioPack`, THE Download_Manager SHALL transition the pack's `Download_State` from `notDownloaded` to `downloading`.
2. WHILE the `Download_State` is `downloading`, THE Download_Manager SHALL emit progress updates as a value between 0.0 and 1.0.
3. THE Offline_Audio_Screen SHALL display the download progress as a percentage (e.g., "45%") and a linear progress bar.
4. WHEN the download completes successfully, THE Download_Manager SHALL transition the `Download_State` to `downloaded` and SHALL save all audio files to local storage.
5. WHEN the download fails due to network error or file I/O error, THE Download_Manager SHALL transition the `Download_State` to `failed` and SHALL store an error message.
6. THE Download_Manager SHALL support downloading multiple packs concurrently without blocking the UI thread.
7. THE Download_Manager SHALL persist the `Download_State` to local storage so that it survives app restarts.

---

### Requirement 4: Download Retry and Cancellation

**User Story:** As a devotee, I want to retry a failed download or cancel an in-progress download, so that I can manage my downloads flexibly.

#### Acceptance Criteria

1. WHEN the `Download_State` is `failed`, THE Offline_Audio_Screen SHALL display a "Retry" button.
2. WHEN the user taps "Retry", THE Download_Manager SHALL reset the pack's `Download_State` to `notDownloaded` and SHALL allow the user to initiate a new download.
3. WHEN the `Download_State` is `downloading`, THE Offline_Audio_Screen SHALL display a "Cancel" button.
4. WHEN the user taps "Cancel", THE Download_Manager SHALL stop the download, delete any partially downloaded files, and SHALL transition the `Download_State` to `notDownloaded`.
5. THE Download_Manager SHALL NOT leave orphaned files in storage after a cancellation or failure.

---

### Requirement 5: Offline Playback Integration

**User Story:** As a devotee, I want to play downloaded audio packs without an internet connection, so that I can listen to temple stories while traveling.

#### Acceptance Criteria

1. WHEN an `AudioPack` has `Download_State` equal to `downloaded`, THE Storytelling_Screen SHALL use the local audio files from the pack instead of generating TTS audio.
2. WHEN the user navigates to the Storytelling_Screen for a temple with a downloaded pack, THE Storytelling_Screen SHALL display an indicator (e.g., "Offline Available" badge).
3. WHEN the user plays audio from a downloaded pack, THE Storytelling_Screen SHALL use the device's audio player to play the local file without making any network requests.
4. WHEN an `AudioPack` is not downloaded, THE Storytelling_Screen SHALL fall back to the existing TTS-based audio generation.
5. THE Storytelling_Screen SHALL allow the user to switch between downloaded audio and TTS audio via a toggle or menu option.
6. FOR ALL downloaded packs, THE Audio_Pack_Service SHALL provide a method `isAvailableOffline(packId)` that returns `true` if and only if all tracks in the pack have valid `localPath` values pointing to existing files.

---

### Requirement 6: Storage Management and Display

**User Story:** As a devotee, I want to see how much storage my downloaded audio packs are using, so that I can manage my device storage effectively.

#### Acceptance Criteria

1. THE Offline_Audio_Screen SHALL display a storage summary showing total used storage (in MB) and the number of downloaded packs.
2. THE storage summary SHALL be displayed at the top of the Offline_Audio_Screen above the pack list.
3. WHEN the user downloads a new pack, THE storage summary SHALL update to reflect the increased storage usage.
4. WHEN the user deletes a pack, THE storage summary SHALL update to reflect the decreased storage usage.
5. THE Storage_Manager SHALL calculate total used storage as the sum of `totalSizeBytes` for all packs with `Download_State` equal to `downloaded`.
6. THE Storage_Manager SHALL provide a method `getTotalUsedStorageBytes()` that returns the total storage used by all downloaded packs.
7. THE Storage_Manager SHALL provide a method `getPackSizeBytes(packId)` that returns the size of a specific pack.

---

### Requirement 7: Pack Deletion

**User Story:** As a devotee, I want to delete downloaded audio packs to free up storage space, so that I can manage my device storage.

#### Acceptance Criteria

1. WHEN the `Download_State` is `downloaded`, THE Offline_Audio_Screen SHALL display a "Delete" button for the pack.
2. WHEN the user taps "Delete", THE Offline_Audio_Screen SHALL display a confirmation dialog asking "Delete this audio pack? This will free up [size] MB."
3. WHEN the user confirms deletion, THE Storage_Manager SHALL delete all local audio files for the pack and SHALL transition the `Download_State` to `notDownloaded`.
4. WHEN the user cancels the deletion dialog, THE Storage_Manager SHALL NOT delete any files and SHALL keep the `Download_State` as `downloaded`.
5. THE Storage_Manager SHALL ensure that all files associated with the pack are removed from local storage after deletion.
6. THE Storage_Manager SHALL update the storage summary immediately after deletion.
7. IF the user attempts to delete a pack that is already deleted (edge case), THE Storage_Manager SHALL NOT throw an error and SHALL return silently.

---

### Requirement 8: Download State Persistence

**User Story:** As a developer, I want download state to persist across app restarts, so that users do not lose their downloaded content or have to re-download packs.

#### Acceptance Criteria

1. THE Audio_Pack_Service SHALL persist the `Download_State` of all packs to local storage (e.g., SharedPreferences or a local database).
2. WHEN the app is restarted, THE Audio_Pack_Service SHALL restore the `Download_State` of all packs from local storage.
3. WHEN the app is restarted and a pack's `Download_State` is `downloaded`, THE Audio_Pack_Service SHALL verify that all local audio files still exist and are readable.
4. IF any local audio file is missing or corrupted after app restart, THE Audio_Pack_Service SHALL transition the pack's `Download_State` to `failed` and SHALL display an error message to the user.
5. THE Audio_Pack_Service SHALL NOT re-download packs automatically after app restart — the user must manually retry.

---

### Requirement 9: No Backend Dependency (MVP Constraint)

**User Story:** As a developer, I want the audio pack feature to work entirely offline without a backend, so that the MVP can be delivered quickly without server infrastructure.

#### Acceptance Criteria

1. THE Pack_Catalog SHALL be defined as a hardcoded Dart list in `lib/data/audio_pack_data.dart` with no network calls.
2. THE Download_Manager SHALL simulate downloads by copying bundled audio files from the app's assets to local storage (or by generating placeholder files for testing).
3. THE Audio_Pack_Service SHALL NOT make any HTTP requests to download audio files in Phase 1.
4. THE Audio_Pack_Service SHALL NOT require authentication or user accounts.
5. THE app SHALL function fully offline from first launch — no network connection is required to view the pack catalog or simulate downloads.

---

### Requirement 10: UI Integration with Temple Detail Screen

**User Story:** As a devotee viewing a temple's detail page, I want to see if an audio pack is available and download it directly, so that I can quickly access offline content.

#### Acceptance Criteria

1. WHEN the Temple_Detail_Screen renders, THE Temple_Detail_Screen SHALL display an "Audio Pack" section if an `AudioPack` exists for that temple.
2. THE "Audio Pack" section SHALL show the pack title, size, and a download button (if not downloaded) or a "Play Offline" button (if downloaded).
3. WHEN the user taps the download button, THE Download_Manager SHALL initiate the download and SHALL display progress inline in the Temple_Detail_Screen.
4. WHEN the user taps "Play Offline", THE Temple_Detail_Screen SHALL navigate to the Storytelling_Screen with the downloaded pack pre-selected.
5. THE Temple_Detail_Screen SHALL NOT alter existing sections (About, Festivals, Darshan Timings) — the Audio Pack section is an additive enhancement.

---

## Non-Functional Requirements

### NFR 1: Performance

1. THE Download_Manager SHALL download a 10 MB audio pack in under 30 seconds on a 5 Mbps connection (simulated in Phase 1).
2. THE Storage_Manager SHALL calculate total used storage in under 100 milliseconds for up to 50 downloaded packs.
3. THE Offline_Audio_Screen SHALL render the pack list in under 500 milliseconds for up to 100 packs.

### NFR 2: Correctness

1. THE Download_State SHALL never transition from `downloaded` to `downloading` without user action (delete or retry).
2. THE sum of all pack sizes reported by Storage_Manager SHALL always equal the actual disk space used by downloaded audio files (within 1% tolerance).
3. THE Audio_Pack_Service SHALL never report a pack as `downloaded` if any of its audio files are missing or unreadable.

### NFR 3: Compatibility

1. THE Audio_Pack feature SHALL be compatible with Flutter SDK `^3.10.1` and `flutter_riverpod ^2.4.0`.
2. THE Audio_Pack feature SHALL work on both Android and iOS platforms.
3. THE Audio_Pack feature SHALL NOT modify the existing `Temple` model in a breaking way.

### NFR 4: Testability

1. THE Download_Manager SHALL be implemented as a testable service with injectable dependencies (e.g., file system, network client).
2. THE Pack_Catalog SHALL be injectable via Riverpod provider overrides to support widget tests with controlled data.
3. THE Audio_Pack_Service SHALL expose methods for unit testing without requiring a full Flutter widget tree.

---

## Edge Cases

1. WHEN a temple has no `AudioPack` entry in the Pack_Catalog, THE Offline_Audio_Screen SHALL NOT display that temple, and THE Temple_Detail_Screen SHALL NOT show an "Audio Pack" section.
2. WHEN the device runs out of storage during a download, THE Download_Manager SHALL transition the pack's `Download_State` to `failed` with an error message "Insufficient storage space."
3. WHEN the user deletes a pack while it is being played in the Storytelling_Screen, THE Storytelling_Screen SHALL stop playback gracefully and SHALL display a message "Audio pack was deleted."
4. WHEN the app is killed (force-stopped) during a download, THE Audio_Pack_Service SHALL detect the incomplete download on next launch and SHALL transition the pack's `Download_State` to `failed`.
5. WHEN two packs for different temples have the same `packId`, THE Audio_Pack_Service SHALL throw a validation error at startup (this is a data integrity check).
6. WHEN the user attempts to download a pack that is already downloaded, THE Download_Manager SHALL display a message "This pack is already downloaded" and SHALL NOT re-download.
7. WHEN the device locale formats file sizes differently (e.g., MB vs MiB), THE Offline_Audio_Screen SHALL use the `intl` package for consistent size formatting.

---

## Correctness Properties (for Property-Based Testing)

These properties are suitable for automated or property-based testing of the Audio_Pack_Service and Download_Manager.

### P1: Download State Exhaustiveness
For any `AudioPack`, the `downloadState` field SHALL always be one of `{notDownloaded, downloading, downloaded, failed}` — never null, never an unlisted value.

### P2: Progress Bounds (Invariant)
WHILE an `AudioPack` has `Download_State` equal to `downloading`, the progress value SHALL always be in the range [0.0, 1.0] inclusive.

### P3: Storage Sum Invariant
The sum of `totalSizeBytes` for all packs with `Download_State` equal to `downloaded` SHALL equal the value returned by `Storage_Manager.getTotalUsedStorageBytes()` (within 1% tolerance for rounding).

### P4: Download-Delete Round-Trip (Idempotence)
For any `AudioPack`, the sequence `download → delete → download` SHALL result in the same final state as a single `download` operation. Deleting a pack SHALL fully reset its state to `notDownloaded`.

### P5: Offline Availability Consistency
For any `AudioPack` with `Download_State` equal to `downloaded`, `Audio_Pack_Service.isAvailableOffline(packId)` SHALL return `true`. For any pack with `Download_State` not equal to `downloaded`, it SHALL return `false`.

### P6: File Existence After Download
For any `AudioPack` with `Download_State` equal to `downloaded`, all `AudioTrack` objects in the pack SHALL have a non-null `localPath` that points to an existing, readable file on the device.

### P7: State Persistence Round-Trip
For any `AudioPack` with `Download_State` equal to `downloaded`, restarting the app SHALL preserve the `Download_State` as `downloaded` if and only if all local audio files still exist.

### P8: Pack Size Consistency
For any `AudioPack`, the `totalSizeBytes` field SHALL equal the sum of `fileSizeBytes` for all tracks in the pack. This is a structural invariant that must hold for all packs in the Pack_Catalog.

### P9: Content Category Completeness
For any `AudioPack` in the Pack_Catalog, the `tracks` list SHALL contain at least one `AudioTrack` for each value in the `Content_Category` enum.

### P10: Deterministic State Transitions
For any `AudioPack`, the state transition sequence SHALL be deterministic: `notDownloaded → downloading → downloaded` (success path) or `notDownloaded → downloading → failed` (failure path). No other transitions are valid without user action (delete, retry).

---

## MVP Scope (Phase 1)

The following are in scope for the initial implementation:

- `AudioPack`, `AudioTrack`, `Download_State`, and `Content_Category` models
- `Pack_Catalog` with hardcoded data for at least 3 temples (Chilkur Balaji, Birla Mandir, Jagannath Temple)
- `Audio_Pack_Service` with download simulation (copy from assets or generate placeholder files)
- `Download_Manager` with progress tracking and state persistence
- `Storage_Manager` with size calculation and deletion
- Riverpod providers for audio pack state
- `Offline_Audio_Screen` (new screen, full pack list with download controls)
- Storage summary widget (total used storage, pack count)
- Integration with `Temple_Detail_Screen` (Audio Pack section)
- Integration with `Storytelling_Screen` (use downloaded audio when available)
- Unit tests for `Audio_Pack_Service` (covering P1–P10)
- Widget smoke test for `Offline_Audio_Screen` rendering

---

## Out of Scope for Phase 1

- Backend API or remote server for hosting audio files
- Streaming audio playback (Phase 1 downloads full files before playback)
- User-generated or community-uploaded audio packs
- Admin panel for managing audio pack metadata
- Push notifications for new audio pack releases
- Audio pack recommendations based on user preferences
- Multi-language audio packs (Phase 1 uses English narration only)
- Audio pack versioning or updates (Phase 1 packs are immutable)
- Bandwidth throttling or adaptive quality selection
- Background downloads (Phase 1 requires app to be in foreground)
- Download queue management (Phase 1 downloads one pack at a time per user action)
- Audio pack sharing between users
- Analytics or telemetry for download success rates
- Integration with external audio sources (Spotify, YouTube, etc.)
- Offline map data or temple photos (Phase 1 is audio-only)
