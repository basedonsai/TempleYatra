# Temple Yatra Stabilization Bugfix Design

## Overview

Four independent bugs silently degrade the Temple Yatra app without crashing working screens.
This design formalizes each bug condition, defines the expected correct behavior, hypothesizes
root causes from the source code, and plans targeted minimal fixes with a two-phase testing
strategy (exploratory on unfixed code, then fix + preservation checking).

The four bugs are:
1. Route Planner false GPS — `onCameraMove` feeds camera center into `_updateUserPosition`,
   triggering false off-route detection; `recalculateRoute` uses `indexOf` on a synthetic Temple.
2. Map Screen polyline race — `_updateRoutePolyline` clears polylines before the async
   Directions API call resolves; stale-polyline guard blocks updates when a request is in flight.
3. Simulation zero distance — `_calculateDistance` always returns `0.0` due to a copy-paste
   ternary bug (`isNotEmpty ? 0.0 : 0.0`), collapsing all arrival times to start time.
4. TTS type error — `preGenerateAudio` assigns `FlutterTts.speak()` return (`dynamic`) to
   `bytes` (`Uint8List`); storytelling screen calls `speak` with empty text when no content loaded.

---

## Glossary

- **Bug_Condition (C)**: A predicate over inputs that returns `true` exactly when the defective
  code path is exercised.
- **Property (P)**: The desired observable behavior for inputs where C holds after the fix.
- **Preservation**: The guarantee that inputs where C does NOT hold produce identical behavior
  before and after the fix.
- **F**: The original (unfixed) function.
- **F'**: The fixed function.
- **`_updateUserPosition`**: Method in `_RoutePlannerScreenState`
  (`lib/screens/route_planner_screen.dart`) that sets `_currentUserPosition` and checks waypoint
  arrival.
- **`_updateRoutePolyline`**: Method in `_MapScreenState` (`lib/screens/map_screen.dart`) that
  clears and rebuilds the polyline set after a Directions API call.
- **`_calculateDistance`**: Method in `SimulationController`
  (`lib/services/simulation_controller.dart`) that should return Haversine km between two temples.
- **`preGenerateAudio`**: Method in `RegionalTTSService`
  (`lib/services/regional_tts_service.dart`) that attempts to pre-cache audio bytes.
- **`_isLoadingRoute`**: Boolean flag in `_MapScreenState` used to guard concurrent API calls.
- **`_storyContent`**: String field in `_StorytellingScreenState` holding the currently loaded
  story text; empty when no content has been fetched yet.

---

## Bug Details


### Bug 1 — Route Planner False GPS

The bug manifests whenever the user pans or zooms the map in `RoutePlannerScreen`. The
`onCameraMove` callback passes `position.target` (the camera center) directly to
`_updateUserPosition`, which stores it as `_currentUserPosition`. The periodic
`_checkRouteDeviation` timer then evaluates off-route status against this camera-derived
position, not a real GPS fix. A secondary defect in `_triggerReRouting` constructs a synthetic
`Temple(id: 'current_location', ...)` and passes it to `RoutingEngine.recalculateRoute` as
`currentLocation`; that method calls `temples.indexOf(nextTemple)` on the engine's list which
never contains the synthetic temple, so `indexOf` returns `-1` and the reorder logic silently
produces a wrong route.

**Formal Specification:**
```
FUNCTION isBugCondition_FalseGPS(event)
  INPUT: event — source of a LatLng update
  OUTPUT: boolean

  RETURN event.source = CameraMove
         AND event.target is stored as _currentUserPosition
END FUNCTION

FUNCTION isBugCondition_IndexOf(rerouteCall)
  INPUT: rerouteCall — invocation of recalculateRoute(currentLocation, nextTemple)
  OUTPUT: boolean

  RETURN currentLocation.id = 'current_location'
         AND currentLocation NOT IN engine.temples
END FUNCTION
```

**Examples:**
- User pans map east → camera center (17.42, 78.51) stored as GPS → deviation check fires →
  false re-route triggered even though user is stationary.
- `recalculateRoute(currentLocation: syntheticTemple, nextTemple: birlaMandir)` →
  `temples.indexOf(birlaMandir)` returns `0` but `currentLocation` is not in the list →
  reordered list starts with synthetic temple that has no real coordinates in the route.

---

### Bug 2 — Map Screen Polyline Race

The bug manifests when the user selects two or more temples in `MapScreen`. `_updateRoutePolyline`
immediately calls `_polylines.clear()` before the `await _directionsService.getRouteBetweenTemples`
call resolves, leaving the map with no polyline during the entire API round-trip. A second path
of the same bug: when `_isLoadingRoute` is already `true` (a request is in flight), the method
returns early without clearing or updating, so the previous selection's polyline remains visible
after the user changes their selection.

**Formal Specification:**
```
FUNCTION isBugCondition_PolylineClear(call)
  INPUT: call — invocation of _updateRoutePolyline
  OUTPUT: boolean

  RETURN _polylines was cleared BEFORE async API call resolved
         AND selectedTemples.length >= 2
END FUNCTION

FUNCTION isBugCondition_StalePolyline(call)
  INPUT: call — invocation of _updateRoutePolyline
  OUTPUT: boolean

  RETURN _isLoadingRoute = true
         AND selectedTemples changed since last call
END FUNCTION
```

**Examples:**
- User selects Temple A and Temple B → polyline clears immediately → spinner shows for 2 s →
  new polyline appears. During those 2 s the map shows no route.
- User selects A+B (request in flight) then deselects B → `_isLoadingRoute` is `true` →
  early return → A+B polyline stays on map even though only A is selected.

---

### Bug 3 — Simulation Zero Distance

The bug is present unconditionally in `SimulationController._calculateDistance`. The method
constructs a `RoutingEngine` with two temples and returns
`routingEngine.optimizeRoute().isNotEmpty ? 0.0 : 0.0` — both branches of the ternary return
`0.0`. This means every inter-temple travel time is `0 minutes`, so `_calculateArrivalTimes`
sets every temple's arrival time equal to `_startTime`.

**Formal Specification:**
```
FUNCTION isBugCondition_ZeroDistance(a, b)
  INPUT: a, b of type Temple
  OUTPUT: boolean

  RETURN true   // always — the method always returns 0.0
END FUNCTION
```

**Examples:**
- `_calculateDistance(birlaMandir, chilkurBalaji)` → `0.0` km (actual ~35 km).
- All five temples in a route get `arrivalTime = _startTime` → ETA display shows identical
  times for every stop.

---

### Bug 4 — TTS Type Error and Empty-Text Speak

Two related defects in the TTS subsystem:

**4a** — `preGenerateAudio` calls `await _flutterTts.speak(text)` and assigns the result to
`bytes` typed as `Uint8List`. `FlutterTts.speak()` returns `dynamic` (actually `void`/`null`
at runtime on most platforms). The `if (bytes != null)` guard silently swallows the null, so
the method always returns an empty list. On platforms where the cast is strict this throws a
runtime type error.

**4b** — `StorytellingScreen._togglePlayPause` calls `_ttsService.speak(text: _storyContent, ...)`
without checking whether `_storyContent` is empty. `RegionalTTSService.speak` does guard
`if (text.isEmpty) return` internally, but the play button's visual state is toggled by the
`onStateChanged` callback which never fires for an empty-text call, leaving the button showing
"pause" while nothing is playing.

**Formal Specification:**
```
FUNCTION isBugCondition_BytesAssignment(call)
  INPUT: call — invocation of preGenerateAudio
  OUTPUT: boolean

  RETURN FlutterTts.speak() return value is assigned to Uint8List bytes
END FUNCTION

FUNCTION isBugCondition_EmptySpeak(call)
  INPUT: call — invocation of _togglePlayPause
  OUTPUT: boolean

  RETURN _storyContent.isEmpty AND _isPlaying = false
END FUNCTION
```

**Examples:**
- `preGenerateAudio(texts: ['Om Namah Shivaya'], languageCode: 'hi')` → `bytes = null` →
  `audioFiles` is empty → caller receives `[]` instead of audio data.
- User opens StorytellingScreen before content loads, taps play → `speak('')` called →
  TTS silent → `onStateChanged` never fires → button shows pause icon indefinitely.

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- `HomeScreen`, `TempleListScreen`, `TempleDetailScreen`, `YatraPlannerScreen`,
  `ChatbotScreen`, and `CommunityScreen` must render and function identically.
- `RoutingEngine.optimizeRoute()` must continue returning a west-to-east list starting from
  Birla Mandir for valid temple lists.
- `DirectionsService` CORS fallback (`_generateEstimatedRouteForRoute`) must continue returning
  a valid `DirectionsResponse`.
- `RegionalTTSService.speak` called with non-empty text must continue invoking `FlutterTts.speak`
  and firing `onStateChanged`.
- `SimulationController.skipCurrentTemple()` and `skipTempleAtIndex()` must continue removing
  temples and calling `notifyListeners()`.
- `MapScreen` with zero temples selected must continue showing all markers and no polyline.
- `RoutePlannerScreen` opened with a valid temple list must continue displaying the vehicle
  selector, statistics row, map, and budget summary without errors.
- `StorytellingScreen` must continue displaying story text and content-type chips regardless
  of TTS availability.

**Scope:**
All inputs that do NOT satisfy any of the four bug conditions above must be completely unaffected.
This includes: real Geolocator GPS fixes updating `_currentUserPosition`, polyline updates after
a successful API response, simulation distance calculations between distinct temples, and TTS
speak calls with non-empty text.

---

## Hypothesized Root Cause

### Bug 1 — False GPS
1. **Wrong callback wired to position update**: `onCameraMove` was likely intended to update
   the map viewport only, but a developer mistakenly routed it to `_updateUserPosition` which
   was designed for real GPS events.
2. **Synthetic Temple not in engine list**: `recalculateRoute` was written assuming
   `currentLocation` is always a member of `temples`; the synthetic object created in
   `_triggerReRouting` was never added to the engine's list before calling `indexOf`.

### Bug 2 — Polyline Race
1. **Eager clear before async**: `_polylines.clear()` was placed at the top of
   `_updateRoutePolyline` before the `await`, so the UI always sees an empty polyline set
   during the API call.
2. **Guard returns without update**: The `if (!_isLoadingRoute)` guard was intended to prevent
   duplicate requests but also prevents the polyline from being updated when selection changes
   mid-flight.

### Bug 3 — Zero Distance
1. **Copy-paste ternary error**: The developer likely intended
   `optimizeRoute().isNotEmpty ? haversineDistance(...) : 0.0` but wrote `0.0` in both branches,
   or intended to delegate to `_haversineDistance` but accidentally used the ternary shorthand.

### Bug 4 — TTS Type Error
1. **Wrong API assumption**: `FlutterTts.speak()` does not return audio bytes; the developer
   confused it with a hypothetical `synthesizeToFile` or `getAudioBytes` API.
2. **Missing empty-content guard in UI**: `_togglePlayPause` was written assuming content is
   always loaded before the user can tap play, but the button is visible immediately on screen
   open before `_loadContent` completes.

---

## Correctness Properties

Property 1: Bug Condition — Camera Move Does Not Update GPS Position

_For any_ `CameraPosition` event delivered via `onCameraMove`, the fixed
`_RoutePlannerScreenState` SHALL NOT update `_currentUserPosition`; only events originating
from a real `Geolocator` position stream SHALL update that field.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition — Reroute Uses Nearest Temple, Not indexOf

_For any_ invocation of `_triggerReRouting` where `_currentUserPosition` is a valid GPS fix,
the fixed code SHALL select the next waypoint by computing Haversine distance from
`_currentUserPosition` to each remaining temple and choosing the nearest, rather than using
`temples.indexOf` with a synthetic Temple object.

**Validates: Requirements 2.3**

Property 3: Bug Condition — Polyline Preserved During API Call

_For any_ temple selection change that triggers `_updateRoutePolyline`, the fixed
`_MapScreenState` SHALL keep the previous polyline visible until the new API response arrives,
then atomically replace it; the map SHALL NOT show zero polylines while a request is in flight.

**Validates: Requirements 2.4**

Property 4: Bug Condition — In-Flight Request Superseded on Selection Change

_For any_ call to `_updateRoutePolyline` while `_isLoadingRoute` is `true`, the fixed code
SHALL cancel or supersede the in-flight request and start a new one for the updated selection,
rather than returning early with a stale polyline.

**Validates: Requirements 2.5**

Property 5: Bug Condition — Distance Returns Haversine Value

_For any_ pair of distinct `Temple` objects `(a, b)`, the fixed
`SimulationController._calculateDistance(a, b)` SHALL return the same value as
`_haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude)`, which is `> 0.0`
when `a != b`.

**Validates: Requirements 2.6, 2.7**

Property 6: Bug Condition — preGenerateAudio Does Not Assign speak() Return

_For any_ call to `RegionalTTSService.preGenerateAudio`, the fixed method SHALL NOT assign
the return value of `FlutterTts.speak()` to a `Uint8List` variable, and SHALL NOT throw a
runtime type error.

**Validates: Requirements 2.8**

Property 7: Bug Condition — Empty Content Prevents speak and Shows Feedback

_For any_ tap on the play button in `StorytellingScreen` while `_storyContent` is empty, the
fixed `_togglePlayPause` SHALL display a user-visible message (e.g. SnackBar) and SHALL NOT
call `_ttsService.speak` with an empty string.

**Validates: Requirements 2.9**

Property 8: Preservation — Non-Buggy Inputs Unchanged

_For any_ input that does NOT satisfy any of the seven bug conditions above (real GPS fix,
valid polyline update after API response, simulation with distinct temples, TTS with non-empty
text, unaffected screens), the fixed code SHALL produce the same observable behavior as the
original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

---

## Fix Implementation

### Changes Required

#### File: `lib/screens/route_planner_screen.dart`

**Function**: `_RoutePlannerScreenState` — `onCameraMove` callback and `_triggerReRouting`

**Specific Changes:**

1. **Remove `_updateUserPosition` from `onCameraMove`**: In the `GoogleMap` widget's
   `onCameraMove` parameter, remove the call to `_updateUserPosition(position.target)`.
   Camera movement must not update the GPS position field.

2. **Wire real GPS stream**: Add a `StreamSubscription<Position>` field. In `initState`,
   subscribe to `Geolocator.getPositionStream()` and call `_updateUserPosition` only from
   that callback. Cancel the subscription in `dispose`.

3. **Replace `indexOf` with nearest-temple search**: In `_triggerReRouting`, remove the
   synthetic `Temple(id: 'current_location', ...)` construction and the
   `engine.recalculateRoute(currentLocation: ..., nextTemple: ...)` call. Instead, find the
   nearest remaining temple by iterating `_optimizedRoute.sublist(_currentWaypointIndex)` and
   computing `calculateDistance` to each; set `_currentWaypointIndex` to the index of the
   nearest temple and call `_fetchDirections` with the remaining route.

#### File: `lib/screens/map_screen.dart`

**Function**: `_MapScreenState._updateRoutePolyline`

**Specific Changes:**

4. **Defer polyline clear until response arrives**: Move `_polylines.clear()` to after the
   `await` resolves (inside the `try` block, before adding the new polyline). The map retains
   the old polyline while the request is in flight.

5. **Cancel in-flight request on new selection**: Replace the `if (!_isLoadingRoute) return`
   early-exit guard with a cancellation token pattern (or an incrementing request counter).
   When a new selection arrives while `_isLoadingRoute` is `true`, increment the counter so
   the previous response is discarded, then start a new request.

#### File: `lib/services/simulation_controller.dart`

**Function**: `SimulationController._calculateDistance`

**Specific Changes:**

6. **Delegate to `_haversineDistance`**: Replace the entire body of `_calculateDistance` with:
   ```dart
   return _haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude);
   ```
   Remove the `RoutingEngine` construction; it is unnecessary and was the source of the bug.

#### File: `lib/services/regional_tts_service.dart`

**Function**: `RegionalTTSService.preGenerateAudio`

**Specific Changes:**

7. **Remove unsupported bytes assignment**: Replace `final bytes = await _flutterTts.speak(text)`
   with a direct `await _flutterTts.speak(text)` call (no assignment). Since `FlutterTts` does
   not expose audio bytes via `speak()`, the method should document that pre-generation is not
   supported on this platform and return an empty list, or be removed from the public API.

#### File: `lib/screens/storytelling_screen.dart`

**Function**: `_StorytellingScreenState._togglePlayPause`

**Specific Changes:**

8. **Guard empty content before speak**: At the top of `_togglePlayPause`, add:
   ```dart
   if (!_isPlaying && _storyContent.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Content is still loading. Please wait.')),
     );
     return;
   }
   ```

---

## Testing Strategy

### Validation Approach

Testing follows a two-phase approach: first run exploratory tests against the UNFIXED code to
surface counterexamples and confirm root cause hypotheses; then run fix-checking and
preservation-checking tests against the FIXED code.

---

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate each bug on unfixed code. Confirm or refute
root cause hypotheses. If refuted, re-hypothesize before implementing the fix.

**Test Plan**: Write unit tests that directly invoke the buggy methods with inputs satisfying
each bug condition. Run on unfixed code and observe failures.

**Test Cases:**

1. **False GPS from camera** (Bug 1a): Simulate a `CameraPosition` event and call
   `_updateUserPosition(position.target)` directly; assert that `_currentUserPosition` is NOT
   updated. Will fail on unfixed code because the method unconditionally sets the field.

2. **indexOf with synthetic Temple** (Bug 1b): Call `RoutingEngine.recalculateRoute` with a
   `currentLocation` Temple whose `id` is `'current_location'` and is not in `temples`; assert
   the returned route starts from the nearest real temple. Will fail on unfixed code because
   `indexOf` returns `-1`.

3. **Polyline cleared before API** (Bug 2a): Call `_updateRoutePolyline` with two selected
   temples; assert that `_polylines` is non-empty immediately after the call (before the async
   completes). Will fail on unfixed code because `_polylines.clear()` runs synchronously first.

4. **Stale polyline on selection change** (Bug 2b): Set `_isLoadingRoute = true`, change
   `_selectedTemples`, call `_updateRoutePolyline`; assert the polyline reflects the new
   selection. Will fail on unfixed code because the early-return guard blocks the update.

5. **Zero distance** (Bug 3): Call `_calculateDistance(birlaMandir, chilkurBalaji)`; assert
   result `> 0.0`. Will fail on unfixed code because both ternary branches return `0.0`.

6. **preGenerateAudio bytes assignment** (Bug 4a): Call `preGenerateAudio` with a mock
   `FlutterTts` that returns `null` from `speak`; assert no `TypeError` is thrown and the
   return value is `[]`. Will fail on unfixed code if the platform enforces the `Uint8List` type.

7. **Empty-text speak** (Bug 4b): Call `_togglePlayPause` while `_storyContent` is `''` and
   `_isPlaying` is `false`; assert `FlutterTts.speak` is NOT called and a SnackBar is shown.
   Will fail on unfixed code because the guard is absent.

**Expected Counterexamples:**
- `_currentUserPosition` is set from camera events (Bug 1a).
- `recalculateRoute` returns a route with the synthetic temple at index 0 (Bug 1b).
- `_polylines` is empty during API call (Bug 2a).
- Polyline shows previous selection after selection change mid-flight (Bug 2b).
- `_calculateDistance` returns `0.0` for any two distinct temples (Bug 3).
- `preGenerateAudio` returns `[]` or throws (Bug 4a).
- Play button enters inconsistent state on empty content (Bug 4b).

---

### Fix Checking

**Goal**: Verify that for all inputs where each bug condition holds, the fixed function produces
the expected behavior (Properties 1–7).

**Pseudocode:**
```
FOR ALL event WHERE isBugCondition_FalseGPS(event) DO
  result := _updateUserPosition_fixed(event)
  ASSERT _currentUserPosition unchanged
END FOR

FOR ALL (a, b) WHERE isBugCondition_ZeroDistance(a, b) DO
  result := _calculateDistance_fixed(a, b)
  ASSERT result = haversineDistance(a.lat, a.lng, b.lat, b.lng)
  ASSERT result > 0.0 WHEN a != b
END FOR

FOR ALL call WHERE isBugCondition_EmptySpeak(call) DO
  result := _togglePlayPause_fixed()
  ASSERT FlutterTts.speak NOT called
  ASSERT SnackBar shown
END FOR
```

---

### Preservation Checking

**Goal**: Verify that for all inputs where no bug condition holds, the fixed functions produce
the same result as the original functions (Property 8).

**Pseudocode:**
```
FOR ALL event WHERE NOT isBugCondition_FalseGPS(event) DO
  ASSERT _updateUserPosition_original(event) = _updateUserPosition_fixed(event)
END FOR

FOR ALL (a, b) WHERE a = b DO
  ASSERT _calculateDistance_fixed(a, b) = 0.0  // same as original for identical temples
END FOR

FOR ALL call WHERE _storyContent.isNotEmpty AND NOT _isPlaying DO
  ASSERT _togglePlayPause_fixed() calls FlutterTts.speak  // same as original
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because
it generates many random inputs automatically, catches edge cases, and provides strong guarantees
that behavior is unchanged for all non-buggy inputs.

**Test Cases:**

1. **Real GPS fix still updates position**: Simulate a `Geolocator` position event; assert
   `_currentUserPosition` IS updated (preserved behavior).
2. **Polyline renders after API response**: After API call resolves, assert polyline is present
   and matches the response (preserved behavior).
3. **Simulation with identical temples**: `_calculateDistance(a, a)` returns `0.0` (edge case,
   same as original).
4. **TTS speak with non-empty content**: `_togglePlayPause` with loaded content calls
   `FlutterTts.speak` (preserved behavior).
5. **Unaffected screens render**: Navigate to Home, TempleList, TempleDetail, YatraPlanner,
   Chatbot, Community — assert no errors (preserved behavior).

---

### Unit Tests

- Test `_calculateDistance` returns correct Haversine value for known temple pairs.
- Test `_calculateArrivalTimes` produces strictly increasing times after the distance fix.
- Test `_togglePlayPause` shows SnackBar and does not call speak when `_storyContent` is empty.
- Test `preGenerateAudio` returns empty list without throwing when `speak` returns null.
- Test `recalculateRoute` selects nearest temple by distance, not by `indexOf`.

### Property-Based Tests

- Generate random pairs of distinct `Temple` objects; assert `_calculateDistance(a, b) > 0.0`.
- Generate random `Temple` lists; assert `_calculateArrivalTimes` produces monotonically
  increasing arrival times.
- Generate random non-empty strings; assert `_togglePlayPause` calls `FlutterTts.speak` exactly
  once per invocation.
- Generate random `CameraPosition` events; assert `_currentUserPosition` is never updated by
  `onCameraMove` after the fix.

### Integration Tests

- Full route planner flow: open screen, pan map, assert no re-route triggered, then simulate
  real GPS deviation, assert re-route fires with correct nearest-temple selection.
- Full map screen flow: select two temples, assert polyline visible throughout API call, change
  selection mid-flight, assert new polyline replaces old after response.
- Full simulation flow: initialize with five temples, start simulation, assert all arrival times
  are distinct and increasing.
- Full storytelling flow: open screen before content loads, tap play, assert SnackBar shown;
  wait for content, tap play again, assert TTS fires.
