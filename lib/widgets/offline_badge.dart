import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_pack.dart';
import '../providers/audio_pack_provider.dart';

/// Shows a green "Offline Available" chip when the pack is downloaded.
/// Watches only its own pack — not the full list.
class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key, required this.packId});
  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the full provider but select only this pack's state
    final asyncPacks = ref.watch(audioPackProvider);
    final isDownloaded = asyncPacks.whenOrNull(
      data: (packs) {
        for (final p in packs) {
          if (p.packId == packId) return p.downloadState == DownloadState.downloaded;
        }
        return false;
      },
    ) ?? false;

    if (!isDownloaded) return const SizedBox.shrink();

    return Chip(
      avatar: const Icon(Icons.offline_bolt, color: Colors.green, size: 16),
      label: Text(
        'Offline Available',
        style: TextStyle(fontSize: 11, color: Colors.green[800]),
      ),
      backgroundColor: Colors.green[50],
      side: BorderSide(color: Colors.green[200]!),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
