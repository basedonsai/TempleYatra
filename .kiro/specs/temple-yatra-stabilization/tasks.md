# Implementation Plan

- [x] 1. Write bug condition exploration tests (BEFORE implementing any fix)
  - **Property 1: Bug Condition** - Four Bug Conditions: False GPS, Polyline Race, Zero Distance, TTS Type Error
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms each bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: These tests encode expected behavior — they will validate the fixes when they pass after implementation
  - **GOAL**: Surface counterexamples that demonstrate each bug exists
  - **Scoped PBT Approach**: For deterministic bugs (Bug 3), scope the property to concrete failing cases for reproducibility

  **Bug 1a — False GPS from camera (route_planner_screen.dart)**
  - Create a `_RoutePlannerScreenState` test harness; simulate a `CameraPosition` event and invoke `_updateUserPosition(position.target)` directly
  - Assert that `_currentUserPosition` is NOT updated after a camera-move event
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (method unconditionally sets the field)
  - Document counterexample: `_currentUserPosition` is set to camera center (17.42, 78.51) even though user is stationary
  - _Requirements: 1.1, 1.2_

  **Bug 1b — indexOf with synthetic Temple (route_planner_screen.dart)**
  - Call `RoutingEngine.recalculateRoute(currentLocation: Temple(id:'current_location',...), nextTemple: birlaMandir)` where `currentLocation` is NOT in `temples`
  - Assert the returned route starts from the nearest real temple, not the synthetic one
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (`indexOf` returns `-1`, route is wrong)
  - Document counterexample: route starts with synthetic temple at index 0
  - _Requirements: 1.3_

  **Bug 2a — Polyline cleared before API resolves (map_screen.dart)**
  - Inject a slow mock `DirectionsService`; call `_updateRoutePolyline` with two selected temples
  - Assert `_polylines` is non-empty immediately after the call (before async completes)
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (`_polylines.clear()` runs synchronously first)
  - Document counterexample: `_polylines` is empty during the 2-second API round-trip
  - _Requirements: 1.4_

  **Bug 2b — Stale polyline on selection change (map_screen.dart)**
  - Set `_isLoadingRoute = true`, change `_selectedTemples`, call `_updateRoutePolyline`
  - Assert the polyline reflects the new selection (not the previous one)
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (early-return guard blocks the update)
  - Document counterexample: A+B polyline stays on map after user deselects B
  - _Requirements: 1.5_

  **Bug 3 — Zero distance (simulation_controller.dart)**
  - Call `SimulationController._calculateDistance(birlaMandir, chilkurBalaji)` directly
  - Assert result `> 0.0` (actual distance is ~35 km)
  - **Scoped PBT**: Generate random pairs of distinct Temple objects; assert `_calculateDistance(a, b) > 0.0` for all
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (both ternary branches return `0.0`)
  - Document counterexample: `_calculateDistance(birlaMandir, chilkurBalaji)` returns `0.0`
  - _Requirements: 1.6, 1.7_

  **Bug 4a — preGenerateAudio bytes assignment (regional_tts_service.dart)**
  - Inject a mock `FlutterTts` whose `speak()` returns `null`; call `preGenerateAudio(texts: ['Om Namah Shivaya'], languageCode: 'hi')`
  - Assert no `TypeError` is thrown and the return value is `[]`
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (null assigned to `Uint8List bytes` may throw)
  - Document counterexample: `audioFiles` is empty or a `TypeError` is thrown
  - _Requirements: 1.8_

  **Bug 4b — Empty-text speak (storytelling_screen.dart)**
  - Create a `_StorytellingScreenState` test harness with `_storyContent = ''` and `_isPlaying = false`; call `_togglePlayPause()`
  - Assert `FlutterTts.speak` is NOT called and a SnackBar is shown
  - Run on UNFIXED code — **EXPECTED OUTCOME: FAILS** (guard is absent; speak is called with empty string)
  - Document counterexample: play button shows pause icon while TTS is silent
  - _Requirements: 1.9_

  - Mark task complete when all seven exploration tests are written, run, and failures are documented

- [x] 2. Write preservation property tests (BEFORE implementing any fix)
  - **Property 2: Preservation** - Non-Buggy Inputs Unchanged Across All Four Bug Groups
  - **IMPORTANT**: Follow observation-first methodology — run UNFIXED code with non-buggy inputs, observe outputs, then write tests
  - **GOAL**: Capture baseline behavior so regressions are caught after the fix

  **Preservation P1 — Real GPS fix still updates position**
  - Observe: simulate a `Geolocator` position event on unfixed code; `_currentUserPosition` IS updated
  - Write property-based test: for all valid `Position` objects from Geolocator stream, `_currentUserPosition` equals the position's lat/lng after `_updateUserPosition` is called
  - Verify test PASSES on UNFIXED code
  - _Requirements: 2.1, 2.2_

  **Preservation P2 — Polyline renders correctly after API response resolves**
  - Observe: after `getRouteBetweenTemples` resolves on unfixed code, `_polylines` contains exactly one polyline with the response's overview points
  - Write property-based test: for any valid `DirectionsResponse`, after the async completes, `_polylines` is non-empty and matches the response
  - Verify test PASSES on UNFIXED code
  - _Requirements: 2.4_

  **Preservation P3 — Simulation with identical temples returns 0.0**
  - Observe: `_calculateDistance(birlaMandir, birlaMandir)` returns `0.0` on unfixed code (edge case, same as expected)
  - Write test: assert `_calculateDistance(a, a) == 0.0` for any temple `a`
  - Verify test PASSES on UNFIXED code
  - _Requirements: 2.6_

  **Preservation P4 — TTS speak with non-empty content calls FlutterTts.speak**
  - Observe: `_togglePlayPause` with `_storyContent = 'Om Namah Shivaya'` and `_isPlaying = false` calls `FlutterTts.speak` exactly once on unfixed code
  - Write property-based test: for all non-empty `_storyContent` strings, `_togglePlayPause` invokes `FlutterTts.speak` exactly once
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.4, 3.8_

  **Preservation P5 — Unaffected screens render without errors**
  - Observe: `HomeScreen`, `TempleListScreen`, `TempleDetailScreen`, `YatraPlannerScreen`, `ChatbotScreen`, `CommunityScreen` all render without errors on unfixed code
  - Write widget tests asserting each screen builds without throwing
  - Verify tests PASS on UNFIXED code
  - _Requirements: 3.1_

  **Preservation P6 — RoutingEngine.optimizeRoute returns west-to-east list starting from Birla Mandir**
  - Observe: `RoutingEngine(temples: allTemples).optimizeRoute()` returns a list starting with Birla Mandir on unfixed code
  - Write test asserting first element is Birla Mandir for any valid temple list containing it
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.2_

  **Preservation P7 — SimulationController.skipCurrentTemple removes temple and notifies**
  - Observe: `skipCurrentTemple()` removes the first temple from `_currentRoute` and calls `notifyListeners()` on unfixed code
  - Write test asserting route length decreases by 1 and listener is called
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.5_

  - Mark task complete when all preservation tests are written, run, and passing on unfixed code

- [x] 3. Fix Bug 1 — Route Planner false GPS and indexOf rerouting

  - [x] 3.1 Remove _updateUserPosition from onCameraMove and wire real Geolocator stream
    - In `lib/screens/route_planner_screen.dart`, add `StreamSubscription<Position>? _positionSubscription` field
    - In `initState`, subscribe to `Geolocator.getPositionStream()` and call `_updateUserPosition` only from that callback
    - In `dispose`, cancel `_positionSubscription`
    - In the `GoogleMap` widget's `onCameraMove` parameter, remove the `_updateUserPosition(position.target)` call entirely
    - _Bug_Condition: isBugCondition_FalseGPS(event) where event.source = CameraMove_
    - _Expected_Behavior: only Geolocator stream events update _currentUserPosition_
    - _Preservation: real GPS fixes must continue updating _currentUserPosition (P1)_
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Replace indexOf with nearest-temple Haversine search in _triggerReRouting
    - In `_triggerReRouting`, remove the synthetic `Temple(id: 'current_location', ...)` construction
    - Remove the `engine.recalculateRoute(currentLocation: ..., nextTemple: ...)` call
    - Instead, iterate `_optimizedRoute.sublist(_currentWaypointIndex)` and compute `calculateDistance` to each temple from `_currentUserPosition`; select the temple with minimum distance as the next waypoint
    - Update `_currentWaypointIndex` to the index of the nearest temple and call `_fetchDirections` with the remaining route
    - _Bug_Condition: isBugCondition_IndexOf(rerouteCall) where currentLocation NOT IN engine.temples_
    - _Expected_Behavior: nearest temple by Haversine distance is selected as next waypoint_
    - _Preservation: RoutingEngine.optimizeRoute() behavior unchanged (P6)_
    - _Requirements: 2.3_

  - [x] 3.3 Verify Bug 1 exploration tests now pass
    - **Property 1: Expected Behavior** - False GPS and indexOf Fixed
    - **IMPORTANT**: Re-run the SAME tests from task 1 (Bug 1a and Bug 1b) — do NOT write new tests
    - Run Bug 1a test: assert camera-move event does NOT update `_currentUserPosition`
    - Run Bug 1b test: assert `_triggerReRouting` selects nearest temple by Haversine, not by indexOf
    - **EXPECTED OUTCOME**: Both tests PASS (confirms Bug 1 is fixed)
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.4 Verify preservation tests still pass after Bug 1 fix
    - **Property 2: Preservation** - Real GPS and RoutingEngine Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 (P1, P6) — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in GPS update and route optimization)

- [x] 4. Fix Bug 2 — Map Screen polyline race condition

  - [x] 4.1 Defer _polylines.clear() until after async resolves
    - In `lib/screens/map_screen.dart`, in `_updateRoutePolyline`, move `_polylines.clear()` to inside the `try` block, immediately before adding the new polyline (after the `await` resolves)
    - The map retains the old polyline while the request is in flight
    - _Bug_Condition: isBugCondition_PolylineClear(call) where _polylines cleared BEFORE async resolved_
    - _Expected_Behavior: previous polyline visible until new route data arrives, then atomically replaced_
    - _Preservation: polyline renders correctly after API response (P2)_
    - _Requirements: 2.4_

  - [x] 4.2 Replace early-return guard with cancellation token pattern
    - Add an `int _routeRequestId = 0` field to `_MapScreenState`
    - At the start of `_updateRoutePolyline`, increment `_routeRequestId` and capture the current value as `final requestId = _routeRequestId`
    - Remove the `if (!_isLoadingRoute) return` early-exit guard
    - After the `await` resolves, check `if (requestId != _routeRequestId) return` to discard stale responses
    - _Bug_Condition: isBugCondition_StalePolyline(call) where _isLoadingRoute=true AND selection changed_
    - _Expected_Behavior: in-flight request superseded; new request starts for updated selection_
    - _Preservation: MapScreen with zero temples selected shows no polyline (3.6)_
    - _Requirements: 2.5_

  - [x] 4.3 Verify Bug 2 exploration tests now pass
    - **Property 1: Expected Behavior** - Polyline Race Fixed
    - **IMPORTANT**: Re-run the SAME tests from task 1 (Bug 2a and Bug 2b) — do NOT write new tests
    - Run Bug 2a test: assert `_polylines` is non-empty while API call is in flight
    - Run Bug 2b test: assert polyline reflects new selection after mid-flight change
    - **EXPECTED OUTCOME**: Both tests PASS (confirms Bug 2 is fixed)
    - _Requirements: 2.4, 2.5_

  - [x] 4.4 Verify preservation tests still pass after Bug 2 fix
    - **Property 2: Preservation** - Polyline and MapScreen Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 (P2, P5) — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in polyline rendering and MapScreen)

- [x] 5. Fix Bug 3 — Simulation zero distance

  - [x] 5.1 Replace _calculateDistance body with _haversineDistance delegation
    - In `lib/services/simulation_controller.dart`, replace the entire body of `_calculateDistance(Temple a, Temple b)` with:
      ```dart
      return _haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude);
      ```
    - Remove the `RoutingEngine` construction inside `_calculateDistance`; it is unnecessary
    - _Bug_Condition: isBugCondition_ZeroDistance(a, b) — always true on unfixed code_
    - _Expected_Behavior: _calculateDistance(a, b) = _haversineDistance(a.lat, a.lng, b.lat, b.lng) > 0.0 when a != b_
    - _Preservation: _calculateDistance(a, a) still returns 0.0; skipCurrentTemple unchanged (P3, P7)_
    - _Requirements: 2.6, 2.7_

  - [x] 5.2 Verify Bug 3 exploration test now passes
    - **Property 1: Expected Behavior** - Zero Distance Fixed
    - **IMPORTANT**: Re-run the SAME test from task 1 (Bug 3) — do NOT write a new test
    - Run Bug 3 test: assert `_calculateDistance(birlaMandir, chilkurBalaji) > 0.0`
    - Run PBT: for random pairs of distinct temples, assert `_calculateDistance(a, b) > 0.0`
    - **EXPECTED OUTCOME**: Tests PASS (confirms Bug 3 is fixed)
    - _Requirements: 2.6, 2.7_

  - [x] 5.3 Verify preservation tests still pass after Bug 3 fix
    - **Property 2: Preservation** - Simulation Unchanged for Edge Cases
    - **IMPORTANT**: Re-run the SAME tests from task 2 (P3, P7) — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms `_calculateDistance(a, a) == 0.0` and skipCurrentTemple unchanged)

- [x] 6. Fix Bug 4 — TTS type error and empty-text speak

  - [x] 6.1 Remove bytes assignment from preGenerateAudio
    - In `lib/services/regional_tts_service.dart`, in `preGenerateAudio`, replace:
      ```dart
      final bytes = await _flutterTts.speak(text);
      if (bytes != null) {
        audioFiles.add(bytes);
      }
      ```
      with:
      ```dart
      await _flutterTts.speak(text);
      // FlutterTts.speak() does not return audio bytes on this platform
      ```
    - The method returns an empty list; document that pre-generation is not supported via speak()
    - _Bug_Condition: isBugCondition_BytesAssignment(call) — speak() return assigned to Uint8List_
    - _Expected_Behavior: no TypeError thrown; method returns [] without crashing_
    - _Preservation: RegionalTTSService.speak with non-empty text still calls FlutterTts.speak (P4)_
    - _Requirements: 2.8_

  - [x] 6.2 Add empty-content guard with SnackBar in _togglePlayPause
    - In `lib/screens/storytelling_screen.dart`, at the top of `_togglePlayPause`, add:
      ```dart
      if (!_isPlaying && _storyContent.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content is still loading. Please wait.')),
        );
        return;
      }
      ```
    - _Bug_Condition: isBugCondition_EmptySpeak(call) where _storyContent.isEmpty AND _isPlaying=false_
    - _Expected_Behavior: SnackBar shown; FlutterTts.speak NOT called with empty string_
    - _Preservation: _togglePlayPause with non-empty content still calls FlutterTts.speak (P4, 3.8)_
    - _Requirements: 2.9_

  - [x] 6.3 Verify Bug 4 exploration tests now pass
    - **Property 1: Expected Behavior** - TTS Type Error and Empty Speak Fixed
    - **IMPORTANT**: Re-run the SAME tests from task 1 (Bug 4a and Bug 4b) — do NOT write new tests
    - Run Bug 4a test: assert `preGenerateAudio` returns `[]` without throwing
    - Run Bug 4b test: assert `_togglePlayPause` shows SnackBar and does NOT call `FlutterTts.speak` when content is empty
    - **EXPECTED OUTCOME**: Both tests PASS (confirms Bug 4 is fixed)
    - _Requirements: 2.8, 2.9_

  - [x] 6.4 Verify preservation tests still pass after Bug 4 fix
    - **Property 2: Preservation** - TTS and StorytellingScreen Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 (P4, P5) — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms non-empty TTS speak and StorytellingScreen content display unchanged)

- [x] 7. Checkpoint — Ensure all tests pass
  - Re-run the full test suite: all seven exploration tests (now as fix-checking tests) must PASS
  - Re-run all preservation tests: P1–P7 must PASS
  - Run widget tests for unaffected screens (HomeScreen, TempleListScreen, TempleDetailScreen, YatraPlannerScreen, ChatbotScreen, CommunityScreen)
  - Confirm `_calculateArrivalTimes` produces strictly increasing arrival times for a 5-temple route
  - Confirm `MapScreen` with zero temples selected shows no polyline
  - Confirm `RoutePlannerScreen` opens with a valid temple list without errors
  - Ask the user if any questions arise before closing the spec
