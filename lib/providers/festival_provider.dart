import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/festival_event.dart';
import '../data/festival_data.dart';

final festivalProvider = Provider<List<FestivalEvent>>((ref) => allFestivalEvents);

final templeFestivalsProvider = Provider.family<List<FestivalEvent>, String>(
  (ref, templeId) => ref.watch(festivalProvider)
      .where((e) => e.templeId == templeId).toList()
      ..sort((a, b) => a.date.compareTo(b.date)),
);
