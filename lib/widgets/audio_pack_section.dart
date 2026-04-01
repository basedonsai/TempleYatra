import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_pack.dart';
import '../models/temple_model.dart';
import '../providers/audio_pack_provider.dart';
import '../screens/storytelling_screen.dart';

/// Displays an Audio Pack card inside the Temple Detail Screen.
///
/// Returns [SizedBox.shrink] when no pack exists for the given temple.
/// Validates: Requirements 10.1–10.5
class AudioPackSection extends ConsumerWidget {
  final Temple temple;

  const AudioPackSection({super.key, required this.temple});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(packForTempleProvider(temple.id));

    if (pack == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Row(
            children: [
              const Icon(Icons.headphones, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Audio Pack',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pack title and size
          Text(
            pack.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pack.totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // State-appropriate controls
          _buildControls(context, ref, pack),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, WidgetRef ref, AudioPack pack) {
    switch (pack.downloadState) {
      case DownloadState.notDownloaded:
        return _buildDownloadButton(ref, pack);

      case DownloadState.downloading:
        return _buildDownloadingControls(ref, pack);

      case DownloadState.downloaded:
        return _buildDownloadedControls(context, ref, pack);

      case DownloadState.failed:
        return _buildFailedControls(ref, pack);
    }
  }

  Widget _buildDownloadButton(WidgetRef ref, AudioPack pack) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () =>
            ref.read(audioPackProvider.notifier).download(pack.packId),
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDownloadingControls(WidgetRef ref, AudioPack pack) {
    final percent = (pack.downloadProgress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(audioPackProvider.notifier).cancelDownload(pack.packId),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pack.downloadProgress,
          backgroundColor: Colors.grey[200],
          color: Colors.orange,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildDownloadedControls(
      BuildContext context, WidgetRef ref, AudioPack pack) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToStorytelling(context, pack),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Play Offline', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[50],
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, ref, pack),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedControls(WidgetRef ref, AudioPack pack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pack.errorMessage ?? 'Download failed. Tap Retry.',
          style: const TextStyle(fontSize: 12, color: Colors.red),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                ref.read(audioPackProvider.notifier).retryDownload(pack.packId),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToStorytelling(BuildContext context, AudioPack pack) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorytellingScreen(
          templeId: temple.id,
          temple: temple,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AudioPack pack) async {
    final sizeMb =
        (pack.totalSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Audio Pack?'),
        content: Text(
          'Delete this audio pack? This will free up $sizeMb MB.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(audioPackProvider.notifier).deletePack(pack.packId);
    }
  }
}
