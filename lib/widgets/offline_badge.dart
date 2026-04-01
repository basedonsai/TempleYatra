import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_pack.dart';
import '../providers/audio_pack_provider.dart';

/// A small badge that renders a green "Offline Available" chip when the
/// audio pack identified by [packId] has been fully downloaded.
///
/// Returns [SizedBox.shrink] when the pack is not found or not downloaded.
///
/// Validates: Requirements 5.2
class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPacks = ref.watch(audioPackProvider);

    final pack = asyncPacks.whenOrNull(
      data: (packs) {
        try {
          return packs.firstWhere((p) => p.packId == packId);
        } catch (_) {
          return null;
        }
      },
    );

    if (pack == null || pack.downloadState != DownloadState.downloaded) {
      return const SizedBox.shrink();
    }

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
