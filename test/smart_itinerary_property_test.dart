// Property-Based Tests: SmartSchedulerService
// Tasks 10.1 – 10.5
//
// Manual property-based testing using dart:math Random (no external PBT library).
// Each property is exercised over 50 random inputs with a fixed seed for reproducibility.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/models/smart_itinerary.dart';
import 'package:yatra_app/models/temple_model.dart';
import 'package:yatra_app/services/budget_service.dart';
import 'package:yatra_app/services/smart_scheduler_service.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

const int _iterations = 50;
const int _seed = 42;

/// Generate a random Temple near Hyderabad (lat 17.3–17.5, lng 78.3–78.5).
Temple _randomTemple(Random rng, int index) {
  final lat = 17.3 + rng.nextDouble() * 0.2;
  final lng = 78.3 + rng.nextDouble() * 0.2;
  return Temple(
    id: 'temple_$index',
    name: 'Temple $index',
    placeId: 'place_$index',
    latitude: lat,
    longitude: lng,
    address: '',
    distinctiveFeatures: '',
    festivals: '',
    prasadamInfo: '',
    darshanTimings: '',
    estimatedVisitDurationMinutes: 45,
  );
}

/// Generate a list of [count] random temples.
List<Temple> _randomTemples(Random rng, int count) =>
    List.generate(count, (i) => _randomTemple(rng, i));

/// Build an ItineraryRequest with random temple count (1–10) and day count (1–14).
/// Returns the request and the rng state is advanced.
ItineraryRequest _randomRequest(Random rng) {
  final templeCount = 1 + rng.nextInt(10); // 1–10
  final numberOfDays = 1 + rng.nextInt(14); // 1–14
  final maxTemplesPerDay = 1 + rng.nextInt(5); // 1–5
  final temples = _randomTemples(rng, templeCount);

  return ItineraryRequest(
    temples: temples,
    startDate: DateTime(2025, 6, 1),
    numberOfDays: numberOfDays,
    maxBudget: 0, // no budget limit — avoids warnings interfering with properties
    travelMode: VehicleType.car,
    startTime: const TimeOfDay(hour: 8, minute: 0),
    maxTemplesPerDay: maxTemplesPerDay,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final service = SmartSchedulerService();

  // -------------------------------------------------------------------------
  // 10.1 days.length <= request.numberOfDays
  // Validates: Requirements 2 (Day Count Bounded)
  // -------------------------------------------------------------------------
  test(
    '10.1 Property: days.length <= request.numberOfDays for any valid request',
    () {
      final rng = Random(_seed);
      for (int i = 0; i < _iterations; i++) {
        final request = _randomRequest(rng);
        final itinerary = service.generate(request);

        expect(
          itinerary.days.length,
          lessThanOrEqualTo(request.numberOfDays),
          reason:
              'Iteration $i: days.length=${itinerary.days.length} '
              'must be <= numberOfDays=${request.numberOfDays} '
              '(temples=${request.temples.length}, '
              'maxTemplesPerDay=${request.maxTemplesPerDay})',
        );
      }
    },
  );

  // -------------------------------------------------------------------------
  // 10.2 All visit timings are monotonically increasing
  // Validates: Requirements 3 (Timings Monotonically Increasing)
  // -------------------------------------------------------------------------
  test(
    '10.2 Property: all visit timings are monotonically increasing',
    () {
      final rng = Random(_seed);
      for (int i = 0; i < _iterations; i++) {
        final request = _randomRequest(rng);
        final itinerary = service.generate(request);

        for (final day in itinerary.days) {
          for (int vi = 0; vi < day.visits.length; vi++) {
            final v = day.visits[vi];

            // arrivalTime[i] < departureTime[i]
            expect(
              v.arrivalTime.isBefore(v.departureTime),
              isTrue,
              reason:
                  'Iteration $i, day ${day.dayNumber}, visit $vi: '
                  'arrivalTime (${v.arrivalTime}) must be before '
                  'departureTime (${v.departureTime})',
            );

            // departureTime[i] <= arrivalTime[i+1]
            if (vi > 0) {
              final prev = day.visits[vi - 1];
              expect(
                !prev.departureTime.isAfter(v.arrivalTime),
                isTrue,
                reason:
                    'Iteration $i, day ${day.dayNumber}: '
                    'departureTime[${vi - 1}] (${prev.departureTime}) '
                    'must be <= arrivalTime[$vi] (${v.arrivalTime})',
              );
            }
          }
        }
      }
    },
  );

  // -------------------------------------------------------------------------
  // 10.3 totalCost.total == transport + stay + food + templeSpecific + misc
  // Validates: Requirements 4 (Cost Non-Negative and Additive)
  // -------------------------------------------------------------------------
  test(
    '10.3 Property: totalCost.total == transport + stay + food + templeSpecific + misc',
    () {
      final rng = Random(_seed);
      for (int i = 0; i < _iterations; i++) {
        final request = _randomRequest(rng);
        final itinerary = service.generate(request);

        final c = itinerary.totalCost;
        final expectedTotal = c.transport + c.stay + c.food + c.templeSpecific + c.misc;

        expect(
          (c.total - expectedTotal).abs(),
          lessThan(0.01),
          reason:
              'Iteration $i: totalCost.total=${c.total} must equal '
              'transport(${c.transport}) + stay(${c.stay}) + '
              'food(${c.food}) + templeSpecific(${c.templeSpecific}) + '
              'misc(${c.misc}) = $expectedTotal (within 0.01)',
        );
      }
    },
  );

  // -------------------------------------------------------------------------
  // 10.4 No temple appears in more than one day (uniqueness across days)
  // Validates: Requirements 1 (Route Ordering Preserved / No Duplicates)
  // -------------------------------------------------------------------------
  test(
    '10.4 Property: no temple appears in more than one day',
    () {
      final rng = Random(_seed);
      for (int i = 0; i < _iterations; i++) {
        final request = _randomRequest(rng);
        final itinerary = service.generate(request);

        // Collect all temple IDs across all days
        final seenIds = <String>{};
        for (final day in itinerary.days) {
          for (final visit in day.visits) {
            final id = visit.temple.id;
            expect(
              seenIds.contains(id),
              isFalse,
              reason:
                  'Iteration $i: temple "$id" (${visit.temple.name}) '
                  'appears in more than one day — uniqueness violated',
            );
            seenIds.add(id);
          }
        }
      }
    },
  );

  // -------------------------------------------------------------------------
  // 10.5 visits.length <= maxTemplesPerDay for every day
  // Validates: Requirements 7 (Temples Per Day Bounded)
  // -------------------------------------------------------------------------
  test(
    '10.5 Property: visits.length <= maxTemplesPerDay for every day',
    () {
      final rng = Random(_seed);
      for (int i = 0; i < _iterations; i++) {
        final request = _randomRequest(rng);
        final itinerary = service.generate(request);

        for (final day in itinerary.days) {
          expect(
            day.visits.length,
            lessThanOrEqualTo(request.maxTemplesPerDay),
            reason:
                'Iteration $i, day ${day.dayNumber}: '
                'visits.length=${day.visits.length} must be <= '
                'maxTemplesPerDay=${request.maxTemplesPerDay}',
          );
        }
      }
    },
  );
}
