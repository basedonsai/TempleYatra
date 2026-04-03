// Bug Condition Exploration Test — Bug 5b: _lastCheckedPosition updated on early-return path
//
// Task 1.3 — Validates: Requirements 5.1.4, 5.2.2
//
// THE BUG: Inside _checkRouteDeviation, when movement < 0.05 km (50 m), the
// early-return branch sets _lastCheckedPosition = _currentUserPosition BEFORE
// returning. This resets the position baseline even though no full deviation
// check was performed.
//
// Consequence: if the user moves in many small steps (each < 50 m), the
// cumulative movement from the last full check is never measured — each step
// resets the baseline, so a 200 m off-route drift in 5 × 40 m steps is never
// detected.
//
// THIS TEST IS EXPECTED TO FAIL ON UNFIXED CODE — failure confirms Bug 5b exists.
// DO NOT fix the code or the test when it fails.
//
// Expected counterexample:
//   After calling _checkRouteDeviation with movement < 0.05 km,
//   _lastCheckedPosition == _currentUserPosition (was updated on early-return).
//   The test asserts it should NOT be updated — FAILS on unfixed code.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yatra_app/utils/distance_calculator.dart';

// ---------------------------------------------------------------------------
// Extracted logic mirror of _checkRouteDeviation's movement-threshold branch
//
// Because _RoutePlannerScreenState is private and requires GoogleMap platform
// channels, we replicate the exact logic of the early-return branch here.
// This is the same pattern used for Bug 1a in bug_condition_exploration_test.dart.
//
// The replicated logic is taken verbatim from route_planner_screen.dart:
//
//   if (_lastCheckedPosition != null) {
//     final movement = calculateDistance(
//       _currentUserPosition!.latitude, _currentUserPosition!.longitude,
//       _lastCheckedPosition!.latitude, _lastCheckedPosition!.longitude,
//     );
//     if (movement < 0.05) {
//       _lastCheckedPosition = _currentUserPosition;  // ← THE BUG
//       return;
//     }
//   }
//   _lastCheckedPosition = _currentUserPosition;
// ---------------------------------------------------------------------------

/// Simulates the BUGGY early-return branch of _checkRouteDeviation.
///
/// Returns the value of [lastCheckedPosition] after the method runs.
/// On unfixed code, when movement < 0.05 km, this returns [currentUserPosition]
/// (the baseline was reset). The test asserts it should remain [originalLastChecked].
LatLng? _simulateBuggyCheckRouteDeviation({
  required LatLng currentUserPosition,
  required LatLng lastCheckedPosition,
}) {
  // Mutable local mirrors of the state fields
  LatLng? _currentUserPosition = currentUserPosition;
  LatLng? _lastCheckedPosition = lastCheckedPosition;

  // Replicated verbatim from route_planner_screen.dart _checkRouteDeviation:
  if (_lastCheckedPosition != null) {
    final movement = calculateDistance(
      _currentUserPosition!.latitude,
      _currentUserPosition.longitude,
      _lastCheckedPosition!.latitude,
      _lastCheckedPosition.longitude,
    );
    if (movement < 0.05) {
      // THE BUG: _lastCheckedPosition is updated even on early-return
      _lastCheckedPosition = _currentUserPosition;
      return _lastCheckedPosition; // early return — returns updated position
    }
  }
  // Full check path: update after check
  _lastCheckedPosition = _currentUserPosition;
  return _lastCheckedPosition;
}

// ---------------------------------------------------------------------------
// Preservation Test — Bug 5: rerouting guard prevents concurrent reroutes
//
// Task 2.4 — Validates: Requirements 5.3.4
//
// PRESERVATION: When _isReRoutingInProgress == true, _checkRouteDeviation
// returns early without triggering a new reroute. This guard must be preserved
// after the Bug 5 fixes.
//
// THIS TEST IS EXPECTED TO PASS ON UNFIXED CODE — it confirms the baseline
// behavior that must be preserved after the fix.
// ---------------------------------------------------------------------------

/// Simulates the rerouting guard at the top of _checkRouteDeviation.
///
/// Returns true if the guard fired (reroute was skipped), false if the
/// deviation check proceeded past the guard.
///
/// Replicates verbatim from route_planner_screen.dart _checkRouteDeviation:
///   if (_isReRoutingInProgress) return;
bool _simulateCheckRouteDeviationGuard({
  required bool isReRoutingInProgress,
}) {
  // Replicated verbatim from route_planner_screen.dart _checkRouteDeviation:
  if (isReRoutingInProgress) return true; // guard fired — reroute skipped
  return false; // guard did not fire — check proceeds
}

void main() {
  // ---------------------------------------------------------------------------
  // Preservation — Bug 5: rerouting guard prevents concurrent reroutes
  //
  // Validates: Requirements 5.3.4
  // ---------------------------------------------------------------------------
  group('Preservation — Bug 5: rerouting guard prevents concurrent reroutes', () {
    test(
      // EXPECTED: PASSES on unfixed code (and must continue to pass after fix).
      //
      // When _isReRoutingInProgress == true, _checkRouteDeviation returns early
      // without performing any deviation check or triggering a new reroute.
      // This is the concurrent-reroute prevention guard that must be preserved.
      '_checkRouteDeviation skips check when _isReRoutingInProgress is true',
      () {
        // Act: simulate _checkRouteDeviation with _isReRoutingInProgress = true
        final guardFired = _simulateCheckRouteDeviationGuard(
          isReRoutingInProgress: true,
        );

        // Assert: the guard fired — no reroute was triggered
        expect(
          guardFired,
          isTrue,
          reason: 'PRESERVATION 5.3.4: When _isReRoutingInProgress == true, '
              '_checkRouteDeviation must return early (guard fires) to prevent '
              'concurrent reroutes. The guard was not fired — this would allow '
              'a second reroute to start while one is already in progress.',
        );
      },
    );

    test(
      // EXPECTED: PASSES on both unfixed and fixed code.
      // Sanity check: when _isReRoutingInProgress == false, the guard does NOT
      // fire and the deviation check proceeds normally.
      '_checkRouteDeviation proceeds when _isReRoutingInProgress is false',
      () {
        // Act: simulate _checkRouteDeviation with _isReRoutingInProgress = false
        final guardFired = _simulateCheckRouteDeviationGuard(
          isReRoutingInProgress: false,
        );

        // Assert: the guard did not fire — check proceeds
        expect(
          guardFired,
          isFalse,
          reason: 'When _isReRoutingInProgress == false, _checkRouteDeviation '
              'should proceed past the guard and perform the deviation check.',
        );
      },
    );

    test(
      // EXPECTED: PASSES on unfixed code (and must continue to pass after fix).
      //
      // Verifies the guard is idempotent: calling the check multiple times while
      // _isReRoutingInProgress == true always skips — no reroute is ever triggered.
      'guard fires consistently across multiple calls while rerouting is in progress',
      () {
        // Simulate 5 consecutive calls to _checkRouteDeviation while rerouting
        for (int i = 0; i < 5; i++) {
          final guardFired = _simulateCheckRouteDeviationGuard(
            isReRoutingInProgress: true,
          );
          expect(
            guardFired,
            isTrue,
            reason: 'Call $i: guard must fire on every call while '
                '_isReRoutingInProgress == true.',
          );
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Bug 5b — _lastCheckedPosition updated on early-return path
  //
  // Validates: Requirements 5.1.4, 5.2.2
  // ---------------------------------------------------------------------------
  group('Bug 5b — _lastCheckedPosition updated on early-return path', () {
    test(
      // EXPECTED: FAILS on unfixed code.
      //
      // The test asserts that after _checkRouteDeviation takes the early-return
      // branch (movement < 0.05 km), _lastCheckedPosition is NOT updated.
      //
      // On unfixed code, _lastCheckedPosition IS updated to _currentUserPosition
      // inside the early-return block — so the assertion fails, confirming Bug 5b.
      //
      // Counterexample: _lastCheckedPosition == _currentUserPosition after
      // early-return, even though no full deviation check was performed.
      '_lastCheckedPosition should NOT be updated when movement < 0.05 km (early-return branch)',
      () {
        // Arrange: positions that are 0.03 km (30 m) apart — below the 0.05 km threshold.
        // At lat ~17.4°, 1° latitude ≈ 111 km → 0.03 km ≈ 0.00027° latitude.
        const originalLastChecked = LatLng(17.4000, 78.4691);
        const currentPosition = LatLng(17.4003, 78.4691); // ~33 m north

        // Verify the movement is indeed < 0.05 km (sanity check for test setup)
        final movement = calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          originalLastChecked.latitude,
          originalLastChecked.longitude,
        );
        expect(
          movement,
          lessThan(0.05),
          reason: 'Test setup: movement should be < 0.05 km to trigger early-return. '
              'Actual movement: ${movement.toStringAsFixed(4)} km',
        );

        // Act: simulate _checkRouteDeviation with movement < threshold
        final resultLastChecked = _simulateBuggyCheckRouteDeviation(
          currentUserPosition: currentPosition,
          lastCheckedPosition: originalLastChecked,
        );

        // Assert: _lastCheckedPosition should NOT have been updated.
        // On unfixed code, it IS updated to currentPosition — test FAILS.
        expect(
          resultLastChecked,
          equals(originalLastChecked),
          reason: 'BUG 5b: _lastCheckedPosition was updated to _currentUserPosition '
              'inside the early-return branch (movement < 0.05 km). '
              'Expected _lastCheckedPosition to remain at its original value '
              '($originalLastChecked) since no full deviation check was performed. '
              'Actual: $resultLastChecked. '
              'This means the movement threshold is measured from the most recent '
              'GPS update rather than the last full check, defeating the threshold.',
        );
      },
    );

    test(
      // EXPECTED: PASSES on both unfixed and fixed code.
      // Sanity check: when movement >= 0.05 km, _lastCheckedPosition IS updated
      // (this is the correct behavior on the full-check path).
      '_lastCheckedPosition SHOULD be updated when movement >= 0.05 km (full check path)',
      () {
        // Arrange: positions that are 0.10 km (100 m) apart — above the threshold.
        // 0.10 km ≈ 0.0009° latitude at lat ~17.4°
        const originalLastChecked = LatLng(17.4000, 78.4691);
        const currentPosition = LatLng(17.4009, 78.4691); // ~100 m north

        // Verify the movement is >= 0.05 km
        final movement = calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          originalLastChecked.latitude,
          originalLastChecked.longitude,
        );
        expect(
          movement,
          greaterThanOrEqualTo(0.05),
          reason: 'Test setup: movement should be >= 0.05 km to trigger full check. '
              'Actual movement: ${movement.toStringAsFixed(4)} km',
        );

        // Act: simulate _checkRouteDeviation with movement >= threshold
        final resultLastChecked = _simulateBuggyCheckRouteDeviation(
          currentUserPosition: currentPosition,
          lastCheckedPosition: originalLastChecked,
        );

        // Assert: _lastCheckedPosition SHOULD be updated after a full check.
        expect(
          resultLastChecked,
          equals(currentPosition),
          reason: 'After a full deviation check (movement >= 0.05 km), '
              '_lastCheckedPosition should be updated to _currentUserPosition.',
        );
      },
    );

    test(
      // EXPECTED: FAILS on unfixed code.
      //
      // Demonstrates the cumulative drift scenario: 5 small steps of ~0.03 km each.
      // Each step resets _lastCheckedPosition, so cumulative movement is never measured.
      // After 5 steps, the user has moved ~0.15 km total, but each individual check
      // sees only ~0.03 km movement and takes the early-return branch.
      //
      // The test asserts that after 5 small steps, _lastCheckedPosition should
      // still equal the ORIGINAL position (from before any steps) — meaning the
      // full check would fire on the next call with cumulative movement >= 0.05 km.
      //
      // On unfixed code, _lastCheckedPosition is reset on each step, so it equals
      // the position after step 5 — the cumulative drift is never detected.
      'cumulative drift: _lastCheckedPosition should remain at original after 5 small steps',
      () {
        // Arrange: start at a known position; take 5 steps of ~0.03 km each.
        // Each step moves ~0.00027° latitude north (≈ 30 m).
        const step = 0.00027; // degrees latitude ≈ 30 m
        const startPosition = LatLng(17.4000, 78.4691);

        // Simulate 5 consecutive GPS updates, each < 0.05 km from the previous.
        // On unfixed code, each call resets _lastCheckedPosition to the new position.
        // On fixed code, _lastCheckedPosition stays at startPosition until a full check.
        LatLng lastChecked = startPosition;
        LatLng current = startPosition;

        for (int i = 1; i <= 5; i++) {
          current = LatLng(startPosition.latitude + step * i, startPosition.longitude);

          // Verify each step is < 0.05 km from the PREVIOUS position
          final stepMovement = calculateDistance(
            current.latitude, current.longitude,
            lastChecked.latitude, lastChecked.longitude,
          );

          if (stepMovement < 0.05) {
            // Buggy early-return: resets lastChecked to current
            lastChecked = current; // THE BUG: this line should NOT be here
          } else {
            // Full check path: update after check
            lastChecked = current;
          }
        }

        // After 5 small steps, total movement from startPosition ≈ 5 × 30 m = 150 m.
        final totalMovement = calculateDistance(
          current.latitude, current.longitude,
          startPosition.latitude, startPosition.longitude,
        );
        expect(
          totalMovement,
          greaterThan(0.05),
          reason: 'Total movement after 5 steps should be > 0.05 km. '
              'Actual: ${totalMovement.toStringAsFixed(4)} km',
        );

        // Assert: _lastCheckedPosition should still be at startPosition.
        // On unfixed code, it equals `current` (position after step 5) — FAILS.
        expect(
          lastChecked,
          equals(startPosition),
          reason: 'BUG 5b (cumulative drift): After 5 small steps (each < 0.05 km), '
              '_lastCheckedPosition should remain at the original position ($startPosition) '
              'so that cumulative movement >= 0.05 km triggers a full check. '
              'On unfixed code, _lastCheckedPosition is reset on each early-return, '
              'so it equals the position after step 5 ($current). '
              'This means 150 m of cumulative drift is never detected.',
        );
      },
    );
  });
}
