// Bug Condition Exploration Test — Task 1.1
// Bug 1: templeFestivalsProvider loading state collapses to []
//
// This test MUST FAIL on unfixed code — failure confirms the bug exists.
// DO NOT fix the code or the test when it fails.
//
// Validates: Requirements 1.2, 2.2

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/database/db_providers.dart';
import 'package:yatra_app/models/festival_event.dart';
import 'package:yatra_app/providers/festival_provider.dart';

void main() {
  group('Bug 1 — templeFestivalsProvider loading state collapses to []', () {
    test(
      // EXPECTED: FAILS on unfixed code.
      //
      // Bug condition: templeFestivalsDbProvider(templeId) is in the loading
      // state (Future never completes). The unfixed templeFestivalsProvider
      // maps loading → [] via .when(loading: () => []).
      //
      // This test asserts the result is NOT an empty list while loading,
      // which FAILS on unfixed code because the provider returns [].
      //
      // Counterexample: templeFestivalsProvider returns [] while DB is still
      // loading — confirms Bug 1.
      'templeFestivalsProvider should NOT return [] while templeFestivalsDbProvider is loading',
      () {
        const templeId = 'chilkur_balaji';

        // A Completer whose future never completes — simulates an in-flight
        // DB query / loading state.
        final completer = Completer<List<FestivalEvent>>();

        final container = ProviderContainer(
          overrides: [
            // Override the DB provider to return a future that never resolves.
            templeFestivalsDbProvider(templeId).overrideWith(
              (ref) => completer.future,
            ),
          ],
        );

        addTearDown(container.dispose);

        // Read the synchronous wrapper provider.
        final result = container.read(templeFestivalsProvider(templeId));

        // Assert: while the DB future is still loading, the provider must NOT
        // return an empty list. It should propagate the loading state so callers
        // can show a loading indicator instead of "no festivals".
        //
        // FIXED: result is AsyncLoading (not []) because the provider now
        // returns ref.watch(templeFestivalsDbProvider(templeId)) directly.
        expect(
          result,
          isA<AsyncLoading<List<FestivalEvent>>>(),
          reason: 'BUG 1 FIX: templeFestivalsProvider should return '
              'AsyncLoading while templeFestivalsDbProvider is still loading, '
              'not an empty list that falsely signals "no festivals".',
        );
      },
    );
  });

  // Preservation Test — Task 2.1
  // Property 2: Preservation — Existing Festival Display Unchanged
  //
  // This test MUST PASS on unfixed code — it confirms the baseline behavior
  // that must be preserved after the fix.
  //
  // When templeFestivalsDbProvider has resolved with data, templeFestivalsProvider
  // correctly returns the same festival list via .when(data: (d) => d, ...).
  // This data branch must remain unchanged after the Bug 1 fix.
  //
  // Validates: Requirements 3.1, 3.2, 3.3
  group('Bug 1 preservation — resolved data state returns correct festival list', () {
    // Helper to build a list of FestivalEvent objects for a given templeId.
    List<FestivalEvent> _makeFestivals(String templeId, int count) {
      return List.generate(
        count,
        (i) => FestivalEvent(
          templeId: templeId,
          name: 'Festival $i',
          date: DateTime(2025, 1 + i, 1),
          crowdHint: CrowdLevel.moderate,
        ),
      );
    }

    // Property: for any templeId where templeFestivalsDbProvider has resolved
    // with data, templeFestivalsProvider returns the same list.
    //
    // Tested across several representative inputs (varying templeId and list
    // sizes) to cover the property space without a full PBT framework.
    //
    // PASSES on unfixed code: the data branch .when(data: (d) => d) is correct.
    test(
      'returns the resolved festival list unchanged for any templeId with data',
      () async {
        // Test across multiple (templeId, festival count) pairs to cover the
        // property: ∀ templeId, ∀ resolvedList → provider returns resolvedList.
        final cases = [
          ('birla_mandir_hyderabad', 3),
          ('chilkur_balaji', 1),
          ('some_temple_with_many_festivals', 10),
          ('temple_with_single_festival', 1),
          ('empty_temple', 0), // no festivals — should return []
        ];

        for (final (templeId, count) in cases) {
          final expectedFestivals = _makeFestivals(templeId, count);

          final container = ProviderContainer(
            overrides: [
              // Override DB provider to return an already-resolved future.
              templeFestivalsDbProvider(templeId).overrideWith(
                (ref) => Future.value(expectedFestivals),
              ),
            ],
          );
          addTearDown(container.dispose);

          // Pump the async provider so it resolves.
          await container.read(templeFestivalsDbProvider(templeId).future);

          // Now read the synchronous wrapper — it should return AsyncData with the resolved list.
          final result = container.read(templeFestivalsProvider(templeId));

          expect(
            result,
            isA<AsyncData<List<FestivalEvent>>>(),
            reason: 'Preservation failure for templeId="$templeId": '
                'templeFestivalsProvider should return AsyncData wrapping the '
                'resolved festival list.',
          );

          final data = result.asData?.value;
          expect(
            data,
            equals(expectedFestivals),
            reason: 'Preservation failure for templeId="$templeId": '
                'templeFestivalsProvider should return the resolved festival list '
                'unchanged, but returned $data instead of $expectedFestivals.',
          );
        }
      },
    );
  });
}
