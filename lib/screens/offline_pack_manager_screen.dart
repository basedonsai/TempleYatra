import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_pack.dart';
import '../providers/audio_pack_provider.dart';
import '../theme/app_theme.dart';

/// Converts a snake_case templeId to a readable title-cased name.
/// e.g. 'chilkur_balaji' -> 'Chilkur Balaji'
String _templeDisplayName(String templeId) {
  return templeId
      .split('_')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class OfflinePackManagerScreen extends ConsumerWidget {
  const OfflinePackManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPacks = ref.watch(audioPackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Audio Packs'),
      ),
      body: asyncPacks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (packs) => _PackListView(packs: packs),
      ),
    );
  }
}

class _PackListView extends ConsumerWidget {
  final List<AudioPack> packs;

  const _PackListView({required this.packs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(audioPackServiceProvider);
    final totalBytes = service.getTotalUsedStorageBytes();
    final totalMb = totalBytes / (1024 * 1024);
    final downloadedCount =
        packs.where((p) => p.downloadState == DownloadState.downloaded).length;

    return Column(
      children: [
        _StorageSummaryCard(totalMb: totalMb, downloadedCount: downloadedCount),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: packs.length,
            itemBuilder: (context, index) =>
                _AudioPackCard(pack: packs[index]),
          ),
        ),
      ],
    );
  }
}

class _StorageSummaryCard extends StatelessWidget {
  final double totalMb;
  final int downloadedCount;

  const _StorageSummaryCard({
    required this.totalMb,
    required this.downloadedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppTheme.saffron.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.storage, color: AppTheme.saffron, size: 28),
            const SizedBox(width: 14),
            Text(
              '${totalMb.toStringAsFixed(1)} MB used  |  $downloadedCount pack${downloadedCount == 1 ? '' : 's'} downloaded',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPackCard extends ConsumerWidget {
  final AudioPack pack;

  const _AudioPackCard({required this.pack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(audioPackProvider.notifier);
    final sizeMb = pack.totalSizeBytes / (1024 * 1024);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                const Icon(Icons.temple_hindu,
                    color: AppTheme.saffron, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pack.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Temple name
            Text(
              _templeDisplayName(pack.templeId),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.saffron),
            ),
            const SizedBox(height: 6),
            // Description
            Text(
              pack.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            // Size
            Text(
              '${sizeMb.toStringAsFixed(1)} MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // State-appropriate controls
            _buildControls(context, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, AudioPackNotifier notifier) {
    switch (pack.downloadState) {
      case DownloadState.notDownloaded:
        return ElevatedButton.icon(
          onPressed: () => notifier.download(pack.packId),
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        );

      case DownloadState.downloading:
        final pct = (pack.downloadProgress * 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: pack.downloadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.saffron),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$pct%',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => notifier.cancelDownload(pack.packId),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
          ],
        );

      case DownloadState.downloaded:
        final sizeMb = pack.totalSizeBytes / (1024 * 1024);
        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to StorytellingScreen (integration handled in task 8)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening audio player...')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, notifier, sizeMb),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        );

      case DownloadState.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack.errorMessage ?? 'Download failed. Tap Retry.',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => notifier.retryDownload(pack.packId),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AudioPackNotifier notifier,
    double sizeMb,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Audio Pack'),
        content: Text(
          'Delete this audio pack? This will free up ${sizeMb.toStringAsFixed(1)} MB.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.deletePack(pack.packId);
    }
  }
}
