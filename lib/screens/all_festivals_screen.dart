import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/db_providers.dart';
import '../models/festival_event.dart';
import '../services/crowd_engine.dart';
import '../widgets/crowd_badge.dart';
import 'temple_calendar_screen.dart';

class AllFestivalsScreen extends ConsumerWidget {
  const AllFestivalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final festivalsAsync = ref.watch(upcomingFestivalsDbProvider(100));
    final templesAsync = ref.watch(allTemplesDbProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Festivals'),
        leading: const BackButton(),
      ),
      body: festivalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (festivals) {
          if (festivals.isEmpty) {
            return const Center(child: Text('No upcoming festivals found.'));
          }
          final temples = templesAsync.valueOrNull ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: festivals.length,
            itemBuilder: (context, i) {
              final f = festivals[i];
              final temple = temples.where((t) => t.id == f.templeId).firstOrNull;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CrowdBadge(
                    level: computeCrowdLevel(f.templeId, f.date, festivals),
                  ),
                  title: Text(f.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('d MMM yyyy').format(f.date)),
                      if (temple != null)
                        Text(
                          temple.name,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  isThreeLine: temple != null,
                  onTap: temple != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TempleCalendarScreen(temple: temple),
                            ),
                          )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
