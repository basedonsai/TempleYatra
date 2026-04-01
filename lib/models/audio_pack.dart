enum DownloadState {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

enum ContentCategory {
  history,
  ritual,
  significance,
  travelTips,
}

class AudioTrack {
  final String trackId;
  final String title;
  final ContentCategory category;
  final int durationSeconds;
  final int fileSizeBytes;
  final String? localPath;

  const AudioTrack({
    required this.trackId,
    required this.title,
    required this.category,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.localPath,
  });

  AudioTrack copyWith({
    String? trackId,
    String? title,
    ContentCategory? category,
    int? durationSeconds,
    int? fileSizeBytes,
    String? localPath,
  }) {
    return AudioTrack(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      localPath: localPath ?? this.localPath,
    );
  }
}

class AudioPack {
  final String packId;
  final String templeId;
  final String title;
  final String description;
  final int totalSizeBytes;
  final List<AudioTrack> tracks;
  final DownloadState downloadState;
  final double downloadProgress; // 0.0–1.0, meaningful only when downloading
  final String? errorMessage;    // non-null only when failed

  const AudioPack({
    required this.packId,
    required this.templeId,
    required this.title,
    required this.description,
    required this.totalSizeBytes,
    required this.tracks,
    this.downloadState = DownloadState.notDownloaded,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  AudioPack copyWith({
    String? packId,
    String? templeId,
    String? title,
    String? description,
    int? totalSizeBytes,
    List<AudioTrack>? tracks,
    DownloadState? downloadState,
    double? downloadProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AudioPack(
      packId: packId ?? this.packId,
      templeId: templeId ?? this.templeId,
      title: title ?? this.title,
      description: description ?? this.description,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      tracks: tracks ?? this.tracks,
      downloadState: downloadState ?? this.downloadState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
