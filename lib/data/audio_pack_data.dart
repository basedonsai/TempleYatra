import '../models/audio_pack.dart';

// Chilkur Balaji tracks
// history: 2.1 MB, ritual: 1.8 MB, significance: 2.4 MB, travelTips: 1.5 MB
// total: 2_100_000 + 1_800_000 + 2_400_000 + 1_500_000 = 7_800_000
const _chilkurTracks = [
  AudioTrack(
    trackId: 'chilkur_balaji_history_01',
    title: 'Sthala Puranam of Chilkur Balaji',
    category: ContentCategory.history,
    durationSeconds: 210,
    fileSizeBytes: 2_100_000,
  ),
  AudioTrack(
    trackId: 'chilkur_balaji_ritual_01',
    title: 'Pradakshina Ritual — 108 Circumambulations',
    category: ContentCategory.ritual,
    durationSeconds: 180,
    fileSizeBytes: 1_800_000,
  ),
  AudioTrack(
    trackId: 'chilkur_balaji_significance_01',
    title: 'Why Chilkur Balaji is Called the Visa God',
    category: ContentCategory.significance,
    durationSeconds: 240,
    fileSizeBytes: 2_400_000,
  ),
  AudioTrack(
    trackId: 'chilkur_balaji_travel_01',
    title: 'Getting to Chilkur Balaji from Hyderabad',
    category: ContentCategory.travelTips,
    durationSeconds: 150,
    fileSizeBytes: 1_500_000,
  ),
];

// Birla Mandir tracks
// history: 1_900_000, ritual: 2_200_000, significance: 1_600_000, travelTips: 1_300_000
// total: 1_900_000 + 2_200_000 + 1_600_000 + 1_300_000 = 7_000_000
const _birlaTracks = [
  AudioTrack(
    trackId: 'birla_mandir_history_01',
    title: 'History of Birla Mandir Hyderabad',
    category: ContentCategory.history,
    durationSeconds: 190,
    fileSizeBytes: 1_900_000,
  ),
  AudioTrack(
    trackId: 'birla_mandir_ritual_01',
    title: 'Daily Puja and Aarti Schedule',
    category: ContentCategory.ritual,
    durationSeconds: 220,
    fileSizeBytes: 2_200_000,
  ),
  AudioTrack(
    trackId: 'birla_mandir_significance_01',
    title: 'Spiritual Significance of the White Marble Temple',
    category: ContentCategory.significance,
    durationSeconds: 160,
    fileSizeBytes: 1_600_000,
  ),
  AudioTrack(
    trackId: 'birla_mandir_travel_01',
    title: 'Visiting Birla Mandir — Tips and Timings',
    category: ContentCategory.travelTips,
    durationSeconds: 130,
    fileSizeBytes: 1_300_000,
  ),
];

// Jagannath Temple tracks
// history: 2_500_000, ritual: 2_800_000, significance: 2_300_000, travelTips: 1_700_000
// total: 2_500_000 + 2_800_000 + 2_300_000 + 1_700_000 = 9_300_000
const _jagannathTracks = [
  AudioTrack(
    trackId: 'jagannath_puri_history_01',
    title: 'Ancient History of Jagannath Temple',
    category: ContentCategory.history,
    durationSeconds: 250,
    fileSizeBytes: 2_500_000,
  ),
  AudioTrack(
    trackId: 'jagannath_puri_ritual_01',
    title: 'Rath Yatra — The Grand Chariot Festival',
    category: ContentCategory.ritual,
    durationSeconds: 280,
    fileSizeBytes: 2_800_000,
  ),
  AudioTrack(
    trackId: 'jagannath_puri_significance_01',
    title: 'Lord Jagannath — Significance and Symbolism',
    category: ContentCategory.significance,
    durationSeconds: 230,
    fileSizeBytes: 2_300_000,
  ),
  AudioTrack(
    trackId: 'jagannath_puri_travel_01',
    title: 'Pilgrimage Guide to Puri',
    category: ContentCategory.travelTips,
    durationSeconds: 170,
    fileSizeBytes: 1_700_000,
  ),
];

const List<AudioPack> allAudioPacks = [
  AudioPack(
    packId: 'pack_chilkur_balaji',
    templeId: 'chilkur_balaji',
    title: 'Chilkur Balaji Audio Pack',
    description:
        'Explore the history, rituals, and spiritual significance of the famous Visa Balaji temple near Hyderabad.',
    totalSizeBytes: 7_800_000,
    tracks: _chilkurTracks,
    downloadState: DownloadState.notDownloaded,
  ),
  AudioPack(
    packId: 'pack_birla_mandir',
    templeId: 'birla_mandir_hyderabad',
    title: 'Birla Mandir Audio Pack',
    description:
        'Discover the beauty and devotion of the iconic white marble Birla Mandir perched atop a rocky hill in Hyderabad.',
    totalSizeBytes: 7_000_000,
    tracks: _birlaTracks,
    downloadState: DownloadState.notDownloaded,
  ),
  AudioPack(
    packId: 'pack_jagannath_puri',
    templeId: 'jagannath_hyderabad',
    title: 'Jagannath Temple Audio Pack',
    description:
        'Journey through the sacred stories, grand rituals, and travel wisdom of the ancient Jagannath Temple in Hyderabad.',
    totalSizeBytes: 9_300_000,
    tracks: _jagannathTracks,
    downloadState: DownloadState.notDownloaded,
  ),
];
