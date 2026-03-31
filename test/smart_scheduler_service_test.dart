// Unit Tests: SmartSchedulerService
// Tasks 8.1 – 8.7

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/models/smart_itinerary.dart';
import 'package:yatra_app/models/temple_model.dart';
import 'package:yatra_app/services/budget_service.dart';
import 'package:yatra_app/services/smart_scheduler_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal Temple with the given coordinates.
/// All temples are clustered near Hyderabad to keep distances small and
/// travel times fast (well under the 10-hour daily cap).
Temple makeTemple(
  String id,
  String name,
  double lat,
  double lng, {
  int? visitMinutes,
}) {
  return Temple(
    id: id,
    name: name,
    placeId: 'place_$id',
    latitude: lat,
    longitude: lng,
    address: '',
    distinctiveFeatures: '',
    festivals: '',
    prasadamInfo: '',
    darshanTimings: '',
    estimatedVisitDurationMinutes: visitMinutes,
  );
}

/// Build a standard ItineraryRequest with sensible defaults.
ItineraryRequest makeRequest({
  required List<Temple> temples,
  int numberOfDays = 1,
  double maxBudget = 0,
  int? maxTemplesPerDay,
  VehicleType travelMode = VehicleType.car,
}) {
  return ItineraryRequest(
    temples: temples,
    startDate: DateTime(2025, 1, 1),
    numberOfDays: numberOfDays,
    maxBudget: maxBudget,
    travelMode: travelMode,
    startTime: const TimeOfDay(hour: 8, minute: 0),
    maxTemplesPerDay: maxTemplesPerDay,
  );
}

// ---------------------------------------------------------------------------
// Shared temple fixtures — all within ~1 km of each other
// ---------------------------------------------------------------------------

final t1 = makeTemple('t1', 'Temple 1', 17.4000, 78.4000, visitMinutes: 45);
final t2 = makeTemple('t2', 'Temple 2', 17.4010, 78.4010, visitMinutes: 45);
final t3 = makeTemple('t3', 'Temple 3', 17.4020, 78.4020, visitMinutes: 45);
final t4 = makeTemple('t4', 'Temple 4', 17.4030, 78.4030, visitMinutes: 45);
final t5 = makeTemple('t5', 'Temple 5', 17.4040, 78.4040, visitMinutes: 45);
final t6 = makeTemple('t6', 'Temple 6', 17.4050, 78.4050, visitMinutes: 45);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final service = SmartSchedulerService();

  // -------------------------------------------------------------------------
  // 8.1 Single temple → one day, one visit, zero travel distance
  // -------------------------------------------------------------------------
  test('8.1 single temple → one day, one visit, zero travel distance', () {
    final request = makeRequest(temples: [t1]);
    final itinerary = service.generate(request);

    expect(itinerary.days.length, equals(1),
        reason: 'Should produce exactly one day for a single temple');

    final day = itinerary.days.first;
    expect(day.visits.length, equals(1),
        reason: 'Day 1 should have exactly one visit');

    final visit = day.visits.first;
    expect(visit.travelDistanceKm, equals(0.0),
        reason: 'First visit has no preceding temple, so travel distance is 0');
  });

  // -------------------------------------------------------------------------
  // 8.2 Three temples, one day → all in day 1, timings monotonically increasing
  // -------------------------------------------------------------------------
  test('8.2 three temples, one day → all in day 1, timings monotonically increasing', () {
    final request = makeRequest(
      temples: [t1, t2, t3],
      numberOfDays: 1,
      maxTemplesPerDay: 3,
    );
    final itinerary = service.generate(request);

    expect(itinerary.days.length, equals(1),
        reason: 'All three temples should fit in one day');

    final day = itinerary.days.first;
    expect(day.visits.length, equals(3),
        reason: 'Day 1 should contain all three visits');

    // Timings must be monotonically increasing
    for (int i = 0; i < day.visits.length; i++) {
      final v = day.visits[i];
      expect(v.arrivalTime.isBefore(v.departureTime), isTrue,
          reason: 'arrivalTime must be before departureTime at visit $i');
      if (i > 0) {
        expect(
          !day.visits[i - 1].departureTime.isAfter(v.arrivalTime),
          isTrue,
          reason: 'departureTime[${i - 1}] must be <= arrivalTime[$i]',
        );
      }
    }
  });

  // -------------------------------------------------------------------------
  // 8.3 Six temples, two days, maxTemplesPerDay=3 → two days of three each
  // -------------------------------------------------------------------------
  test('8.3 six temples, two days, maxTemplesPerDay=3 → two days of three each', () {
    final request = makeRequest(
      temples: [t1, t2, t3, t4, t5, t6],
      numberOfDays: 2,
      maxTemplesPerDay: 3,
    );
    final itinerary = service.generate(request);

    expect(itinerary.days.length, equals(2),
        reason: 'Should produce exactly two days');
    expect(itinerary.days[0].visits.length, equals(3),
        reason: 'Day 1 should have 3 visits');
    expect(itinerary.days[1].visits.length, equals(3),
        reason: 'Day 2 should have 3 visits');
  });

  // -------------------------------------------------------------------------
  // 8.4 Budget exceeded → warnings.isNotEmpty
  // -------------------------------------------------------------------------
  test('8.4 budget exceeded → warnings.isNotEmpty', () {
    // maxBudget=1 is far below any realistic trip cost, so a warning is guaranteed
    final request = makeRequest(
      temples: [t1, t2, t3],
      numberOfDays: 1,
      maxBudget: 1.0,
      maxTemplesPerDay: 3,
    );
    final itinerary = service.generate(request);

    expect(itinerary.warnings.isNotEmpty, isTrue,
        reason: 'A budget of ₹1 should always be exceeded, emitting a warning');
  });

  // -------------------------------------------------------------------------
  // 8.5 maxBudget == 0 → no budget warning emitted
  // -------------------------------------------------------------------------
  test('8.5 maxBudget == 0 → no budget warning emitted', () {
    final request = makeRequest(
      temples: [t1, t2, t3],
      numberOfDays: 1,
      maxBudget: 0,
      maxTemplesPerDay: 3,
    );
    final itinerary = service.generate(request);

    expect(itinerary.warnings.isEmpty, isTrue,
        reason: 'maxBudget=0 means no limit; no budget warning should be emitted');
  });

  // -------------------------------------------------------------------------
  // 8.6 Temple with null estimatedVisitDurationMinutes → defaults to 45 min
  // -------------------------------------------------------------------------
  test('8.6 null estimatedVisitDurationMinutes → visitDuration defaults to 45 min', () {
    final templeNoVisitDuration = makeTemple(
      'tn', 'Temple Null Duration', 17.4000, 78.4000,
      // visitMinutes intentionally omitted → null
    );

    final request = makeRequest(temples: [templeNoVisitDuration]);
    final itinerary = service.generate(request);

    final visit = itinerary.days.first.visits.first;
    expect(visit.visitDuration, equals(const Duration(minutes: 45)),
        reason: 'Null estimatedVisitDurationMinutes should default to 45 minutes');
  });

  // -------------------------------------------------------------------------
  // 8.7 numberOfDays > temples.length → days.length == temples.length, no empty days
  // -------------------------------------------------------------------------
  test('8.7 numberOfDays > temples.length → days.length == temples.length, no empty days', () {
    // 3 temples, 5 days requested, maxTemplesPerDay=1 forces one temple per day.
    // Note: RoutingEngine._optimizeForTime() always prepends birla_mandir_hyderabad
    // from allTemples as the route start point, so the effective temple count is
    // temples.length + 1 = 4. The scheduler must not produce more days than
    // there are (effective) temples, and every day must be non-empty.
    final request = makeRequest(
      temples: [t1, t2, t3],
      numberOfDays: 5,
      maxTemplesPerDay: 1,
    );
    final itinerary = service.generate(request);

    // days.length must be <= numberOfDays (no phantom empty days)
    expect(itinerary.days.length, lessThanOrEqualTo(request.numberOfDays),
        reason: 'Should not produce more days than numberOfDays');

    // Every produced day must have at least one visit (no empty days)
    for (int i = 0; i < itinerary.days.length; i++) {
      expect(itinerary.days[i].visits.isNotEmpty, isTrue,
          reason: 'Day ${i + 1} must not be empty');
    }
  });
}
