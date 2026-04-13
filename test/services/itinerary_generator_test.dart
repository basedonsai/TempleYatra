// Bug Condition Exploration Test — Bug 4: _createDailyPlans arrival time drift
//
// Task 1.2 — Validates: Requirements 4.1.1, 4.1.2, 4.2.1
//
// THE BUG: _createDailyPlans passes `dailyDuration` (cumulative total elapsed
// time since day start) to _calculateArrivalTime instead of `travelTime`
// (incremental time since last departure).
//
// For a 2-temple day with 30 min darshan + 20 min travel:
//   Correct: 08:00 arrive T1 → 08:30 depart → 08:50 arrive T2 (08:30 + 20 min travel)
//   Buggy:   08:00 arrive T1 → 08:30 depart → 09:00 arrive T2 (08:30 + 30 min cumulative)
//
// NOTE: 2 temples are used (instead of 3) because ItineraryGenerator._optimizeRoute
// skips TSP for lists of length <= 2, preventing birla_mandir_hyderabad from being
// injected into the route by _nearestNeighborOrder. This gives a clean, predictable
// visit order and the exact timing values specified in the task.
//
// THIS TEST IS EXPECTED TO FAIL ON UNFIXED CODE — failure confirms Bug 4 exists.
// DO NOT fix the code or the test when it fails.
//
// Task 2.3 — Preservation test: single-temple day timing unchanged
// Validates: Requirements 4.3.1
//
// The bug only affects multi-temple days (i > 0 in the loop). For a single-temple
// day, dailyDuration == Duration.zero when _calculateArrivalTime is called, so
// the bug does not manifest. This test confirms the baseline behavior is preserved.
//
// THIS TEST IS EXPECTED TO PASS ON UNFIXED CODE — confirms baseline to preserve.

import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/models/temple_model.dart';
import 'package:yatra_app/services/itinerary_generator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper: build a minimal Temple with rating <= 4.5 (→ 30 min darshan)
  // placed at a given latitude (same longitude) so travel distance is
  // controlled via latitude offset.
  //
  // At lat ~17.4°, 1° latitude ≈ 111 km.
  // 0.122° ≈ 13.54 km → estimateTravelTime(13.54, Car@40 km/h) = 20.31 → 20 min.
  // ---------------------------------------------------------------------------
  Temple _makeTemple(String id, double latitude) {
    return Temple(
      id: id,
      name: 'Test Temple $id',
      placeId: 'place_$id',
      latitude: latitude,
      longitude: 78.47,
      address: '',
      distinctiveFeatures: '',
      festivals: '',
      prasadamInfo: '',
      darshanTimings: '',
      rating: 4.0, // <= 4.5 → darshanDuration = 30 min
    );
  }

  // ---------------------------------------------------------------------------
  // Bug 4 exploration test
  //
  // Validates: Requirements 4.1.1, 4.1.2, 4.2.1
  //
  // EXPECTED TO FAIL on unfixed code:
  //   visits[1].arrivalTime == '09:00 AM'  (buggy: 08:30 + 30 min cumulative)
  //   instead of the correct '08:50 AM'    (correct: 08:30 + 20 min travel)
  // ---------------------------------------------------------------------------
  test(
    'Bug 4 — visits[1].arrivalTime should be 08:50 AM (08:30 depart + 20 min travel)',
    () {
      // T1 at lat 17.40, T2 at lat 17.522 (≈ 13.54 km apart → 20 min travel at 40 km/h)
      final t1 = _makeTemple('t1', 17.40);
      final t2 = _makeTemple('t2', 17.522);

      final generator = ItineraryGenerator(
        availableTemples: [t1, t2],
        constraints: const ItineraryConstraints(
          maxTemplesPerDay: 2,
          travelMode: 'Car',
        ),
      );

      final itinerary = generator.generate();

      expect(
        itinerary.dayPlans,
        isNotEmpty,
        reason: 'Expected at least one day plan',
      );

      final visits = itinerary.dayPlans[0].visits;

      expect(
        visits.length,
        greaterThanOrEqualTo(2),
        reason: 'Expected at least 2 visits in day 1',
      );

      // visits[0]: arrives 08:00 AM, darshan 30 min, departs 08:30 AM
      expect(
        visits[0].arrivalTime,
        equals('08:00 AM'),
        reason: 'First temple should arrive at 08:00 AM (day start)',
      );
      expect(
        visits[0].departureTime,
        equals('08:30 AM'),
        reason: 'First temple should depart at 08:30 AM (08:00 + 30 min darshan)',
      );

      // visits[1]: correct arrival = 08:30 depart + 20 min travel = 08:50 AM
      // Buggy arrival = _calculateArrivalTime('08:30 AM', dailyDuration=30min) = 09:00 AM
      expect(
        visits[1].arrivalTime,
        equals('08:50 AM'),
        reason:
            'Second temple should arrive at 08:50 AM '
            '(08:30 depart + 20 min travel). '
            'On unfixed code this returns 09:00 AM because _createDailyPlans '
            'passes dailyDuration (30 min cumulative) instead of travelTime (20 min).',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Task 2.3 — Preservation test: single-temple day timing unchanged
  //
  // **Validates: Requirements 4.3.1**
  //
  // For a single-temple day, i == 0 throughout the loop, so:
  //   - dailyDuration == Duration.zero when _calculateArrivalTime is called
  //   - travelTime == Duration.zero (no previous temple)
  //   - Both buggy and fixed code produce the same result for i == 0
  //
  // This test PASSES on unfixed code — it confirms the baseline to preserve.
  // ---------------------------------------------------------------------------
  group('Bug 4 preservation — single-temple day timing unchanged', () {
    // Property: for any single-temple day with rating <= 4.5 (30 min darshan),
    // arrivalTime == '08:00 AM' and departureTime == '08:30 AM'.
    test(
      'single temple: arrivalTime == startTime (08:00 AM) and departureTime == startTime + darshanDuration (08:30 AM)',
      () {
        // A single temple with rating 4.0 → darshanDuration = 30 min
        final temple = Temple(
          id: 'single_temple',
          name: 'Single Test Temple',
          placeId: 'place_single',
          latitude: 17.40,
          longitude: 78.47,
          address: '',
          distinctiveFeatures: '',
          festivals: '',
          prasadamInfo: '',
          darshanTimings: '',
          rating: 4.0, // <= 4.5 → 30 min darshan
        );

        final generator = ItineraryGenerator(
          availableTemples: [temple],
          constraints: const ItineraryConstraints(
            maxTemplesPerDay: 1,
            travelMode: 'Car',
          ),
        );

        final itinerary = generator.generate();

        expect(
          itinerary.dayPlans,
          isNotEmpty,
          reason: 'Expected at least one day plan',
        );

        final visits = itinerary.dayPlans[0].visits;

        expect(
          visits.length,
          equals(1),
          reason: 'Expected exactly 1 visit for a single-temple day',
        );

        // Preservation: arrival must equal the day start time
        expect(
          visits[0].arrivalTime,
          equals('08:00 AM'),
          reason: 'Single-temple arrival must equal start time (08:00 AM)',
        );

        // Preservation: departure must equal start time + darshan duration (30 min)
        expect(
          visits[0].departureTime,
          equals('08:30 AM'),
          reason:
              'Single-temple departure must equal start time + darshan duration '
              '(08:00 AM + 30 min = 08:30 AM)',
        );
      },
    );

    // Property: for any single-temple day with rating > 4.5 (60 min darshan),
    // arrivalTime == '08:00 AM' and departureTime == '09:00 AM'.
    test(
      'single high-rated temple (rating > 4.5): arrivalTime == 08:00 AM, departureTime == 09:00 AM (60 min darshan)',
      () {
        final temple = Temple(
          id: 'single_popular_temple',
          name: 'Popular Test Temple',
          placeId: 'place_popular',
          latitude: 17.40,
          longitude: 78.47,
          address: '',
          distinctiveFeatures: '',
          festivals: '',
          prasadamInfo: '',
          darshanTimings: '',
          rating: 4.8, // > 4.5 → 60 min darshan
        );

        final generator = ItineraryGenerator(
          availableTemples: [temple],
          constraints: const ItineraryConstraints(
            maxTemplesPerDay: 1,
            travelMode: 'Car',
          ),
        );

        final itinerary = generator.generate();

        expect(itinerary.dayPlans, isNotEmpty);
        final visits = itinerary.dayPlans[0].visits;
        expect(visits.length, equals(1));

        expect(
          visits[0].arrivalTime,
          equals('08:00 AM'),
          reason: 'Single-temple arrival must equal start time (08:00 AM)',
        );

        expect(
          visits[0].departureTime,
          equals('09:00 AM'),
          reason:
              'Single high-rated temple departure must be 08:00 AM + 60 min = 09:00 AM',
        );
      },
    );
  });
}
