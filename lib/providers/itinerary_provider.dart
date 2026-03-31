import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/smart_itinerary.dart';
import '../services/smart_scheduler_service.dart';

final itineraryProvider =
    AsyncNotifierProvider<ItineraryNotifier, SmartItinerary?>(
        ItineraryNotifier.new);

class ItineraryNotifier extends AsyncNotifier<SmartItinerary?> {
  @override
  Future<SmartItinerary?> build() async => null;

  Future<void> generate(ItineraryRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = SmartSchedulerService();
      return service.generate(request);
    });
  }

  void reset() {
    state = const AsyncData(null);
  }
}
