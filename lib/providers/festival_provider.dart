import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/festival_event.dart';
import '../database/db_providers.dart';

final festivalProvider = Provider<List<FestivalEvent>>((ref) {
  return ref.watch(upcomingFestivalsDbProvider(9999)).when(
    data: (d) => d,
    loading: () => [],
    error: (e, st) => [],
  );
});

final templeFestivalsProvider = Provider.family<List<FestivalEvent>, String>(
  (ref, templeId) => ref.watch(templeFestivalsDbProvider(templeId)).when(
    data: (d) => d,
    loading: () => [],
    error: (e, st) => [],
  ),
);
