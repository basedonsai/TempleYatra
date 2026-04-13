import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/db_providers.dart';
import '../models/temple_model.dart';
import '../services/crowd_engine.dart';
import '../widgets/crowd_badge.dart';

class TempleCalendarScreen extends ConsumerWidget {
  final Temple temple;

  const TempleCalendarScreen({super.key, required this.temple});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final festivalsAsync = ref.watch(templeFestivalsDbProvider(temple.id));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text('${temple.name} — Festivals'),
        leading: const BackButton(),
      ),
      body: festivalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox(),
        data: (allEvents) {
          final upcoming = allEvents
              .where((e) =>
                  !DateTime(e.date.year, e.date.month, e.date.day)
                      .isBefore(today))
              .toList();

          return upcoming.isEmpty
              ? const Center(child: Text('No upcoming festivals scheduled.'))
              : ListView.builder(
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final event = upcoming[index];
                    final eventDay = DateTime(
                        event.date.year, event.date.month, event.date.day);
                    final isToday = eventDay == today;

                    return ListTile(
                      leading: CrowdBadge(
                        level: computeCrowdLevel(
                            temple.id, event.date, allEvents),
                      ),
                      title: Text(event.name),
                      subtitle:
                          Text(DateFormat('d MMM yyyy').format(event.date)),
                      tileColor: isToday ? Colors.orange.shade50 : null,
                    );
                  },
                );
        },
      ),
    );
  }
}
