import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OfflinePackManagerScreen extends StatelessWidget {
  const OfflinePackManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Temple Packs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Storage Info
          Card(
            color: AppTheme.saffron.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.storage, color: AppTheme.saffron, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Used',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text('245 MB / 2 GB'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.12,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.saffron),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Downloaded Packs',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _PackCard(
            templeName: 'Tirupati Balaji',
            size: '45 MB',
            lastUpdated: 'Updated 2 days ago',
            hasUpdate: false,
          ),
          _PackCard(
            templeName: 'Kashi Vishwanath',
            size: '38 MB',
            lastUpdated: 'Updated 1 week ago',
            hasUpdate: true,
          ),
          _PackCard(
            templeName: 'Somnath Temple',
            size: '52 MB',
            lastUpdated: 'Updated 3 days ago',
            hasUpdate: false,
          ),
          _PackCard(
            templeName: 'Meenakshi Temple',
            size: '41 MB',
            lastUpdated: 'Updated 5 days ago',
            hasUpdate: true,
          ),
          const SizedBox(height: 16),
          // Empty State (if no packs)
          // Uncomment to show empty state
          // Center(
          //   child: Column(
          //     children: [
          //       Icon(Icons.download_outlined, size: 64, color: Colors.grey),
          //       const SizedBox(height: 16),
          //       Text(
          //         'No offline packs downloaded',
          //         style: Theme.of(context).textTheme.titleLarge,
          //       ),
          //       const SizedBox(height: 8),
          //       Text(
          //         'Download temple packs to access content offline',
          //         style: Theme.of(context).textTheme.bodyMedium,
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final String templeName;
  final String size;
  final String lastUpdated;
  final bool hasUpdate;

  const _PackCard({
    required this.templeName,
    required this.size,
    required this.lastUpdated,
    required this.hasUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.temple_hindu, color: AppTheme.saffron),
        ),
        title: Text(templeName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(size),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  lastUpdated,
                  style: const TextStyle(fontSize: 12),
                ),
                if (hasUpdate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            if (hasUpdate)
              const PopupMenuItem(
                value: 'update',
                child: Row(
                  children: [
                    Icon(Icons.update, size: 20),
                    SizedBox(width: 8),
                    Text('Update Pack'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Pack', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'update') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updating $templeName pack...')),
              );
            } else if (value == 'delete') {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Pack'),
                  content: Text('Are you sure you want to delete $templeName pack?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$templeName pack deleted')),
                        );
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

