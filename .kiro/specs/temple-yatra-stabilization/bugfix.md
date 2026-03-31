# Bugfix Requirements Document

## Introduction

The Temple Yatra Flutter app has several incomplete or broken subsystems that cause silent failures, dead code execution, and incorrect behavior at runtime. This spec targets four core problem areas before any new features are added: (1) route planner rerouting logic that fires against camera movement instead of real GPS, (2) map screen polyline state that is cleared before it can be rendered, (3) simulation controller distance calculation that always returns zero, and (4) TTS integration in the storytelling screen that calls a non-existent `bytes` return value from `flutter_tts`. These bugs do not crash working screens but silently degrade the user experience and produce incorrect data.

---

## Bug Analysis

### Current Behavior (Defect)

**Bug Group 1 — Route Planner: GPS rerouting fires on camera pan**

1.1 WHEN the user pans or moves the map camera in `RoutePlannerScreen` THEN the system calls `_updateUserPosition(position.target)` using the camera center as the user's GPS position, triggering false off-route detection

1.2 WHEN `_checkRouteDeviation` runs and `_currentUserPosition` is set from camera movement THEN the system may call `_triggerReRouting()` even though the user has not physically moved

1.3 WHEN `_triggerReRouting` creates a `currentLocation` Temple with `id: 'current_location'` THEN the system passes it to `RoutingEngine.recalculateRoute` which calls `temples.indexOf(nextTemple)` on a list that does not contain the synthetic temple, returning `-1` and silently producing an incorrect reordered route

**Bug Group 2 — Map Screen: Polyline state cleared before render**

1.4 WHEN the user selects two or more temples in `MapScreen` THEN the system calls `_updateRoutePolyline()` which immediately sets `_polylines.clear()` before the async `getRouteBetweenTemples` call completes, causing the map to render with no polyline while the API call is in flight

1.5 WHEN `_updateRoutePolyline` is called while `_isLoadingRoute` is already `true` THEN the system returns early without clearing or updating polylines, leaving a stale polyline from the previous selection on the map

**Bug Group 3 — Simulation Controller: Distance always returns zero**

1.6 WHEN `SimulationController._calculateDistance(Temple a, Temple b)` is called THEN the system constructs a `RoutingEngine` with two temples and calls `optimizeRoute().isNotEmpty ? 0.0 : 0.0`, always returning `0.0` regardless of actual distance

1.7 WHEN `_calculateArrivalTimes` uses the zero distance to compute travel time THEN the system sets all arrival times to the same value as `_startTime`, making every temple appear to be reachable instantly

**Bug Group 4 — TTS / Storytelling: `preGenerateAudio` calls non-existent return value**

1.8 WHEN `RegionalTTSService.preGenerateAudio` is called THEN the system calls `await _flutterTts.speak(text)` and assigns the result to `bytes`, but `FlutterTts.speak()` returns `dynamic` (not `Uint8List`), causing a runtime type error or silent null assignment

1.9 WHEN `StorytellingScreen._togglePlayPause` is called while `_isPlaying` is `false` and `_storyContent` is empty THEN the system calls `_ttsService.speak(text: '', languageCode: ...)` which silently does nothing, leaving the play button in an inconsistent visual state

---

### Expected Behavior (Correct)

**Bug Group 1 — Route Planner**

2.1 WHEN the user pans the map camera in `RoutePlannerScreen` THEN the system SHALL NOT update `_currentUserPosition`; only a real `Geolocator` position stream SHALL update that field

2.2 WHEN `_checkRouteDeviation` runs THEN the system SHALL only evaluate off-route status when `_currentUserPosition` was set by a verified GPS fix, not by camera movement

2.3 WHEN `_triggerReRouting` builds a new route THEN the system SHALL use the Haversine distance from `_currentUserPosition` to each remaining temple to find the nearest next waypoint, rather than relying on `indexOf` with a synthetic Temple object

**Bug Group 2 — Map Screen**

2.4 WHEN the user selects temples and a route fetch is in flight THEN the system SHALL keep the previous polyline visible until the new route data arrives, then atomically replace it

2.5 WHEN `_isLoadingRoute` is `true` and the user changes temple selection THEN the system SHALL cancel or supersede the in-flight request and start a new one for the updated selection

**Bug Group 3 — Simulation Controller**

2.6 WHEN `SimulationController._calculateDistance(Temple a, Temple b)` is called THEN the system SHALL return the Haversine distance in km between the two temples using the same formula already present in `_haversineDistance`

2.7 WHEN `_calculateArrivalTimes` computes travel time THEN the system SHALL produce distinct, monotonically increasing arrival times for each temple based on actual inter-temple distances

**Bug Group 4 — TTS / Storytelling**

2.8 WHEN `RegionalTTSService.preGenerateAudio` is called THEN the system SHALL either remove the unsupported `bytes` assignment or guard it with a platform capability check, and SHALL NOT throw a runtime type error

2.9 WHEN `StorytellingScreen._togglePlayPause` is called while content is empty THEN the system SHALL display a user-visible message (e.g. SnackBar) and SHALL NOT call `_ttsService.speak` with an empty string

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user navigates to `HomeScreen`, `TempleListScreen`, `TempleDetailScreen`, `YatraPlannerScreen`, `ChatbotScreen`, or `CommunityScreen` THEN the system SHALL CONTINUE TO render and function as before with no changes to those screens

3.2 WHEN `RoutingEngine.optimizeRoute()` is called with a valid temple list THEN the system SHALL CONTINUE TO return a west-to-east ordered list starting from Birla Mandir

3.3 WHEN `DirectionsService.getEstimatedRoute` is called as a CORS fallback THEN the system SHALL CONTINUE TO return a valid `DirectionsResponse` with approximate polyline points

3.4 WHEN `RegionalTTSService.speak` is called with a non-empty text and valid language code THEN the system SHALL CONTINUE TO invoke `FlutterTts.speak` and fire the `onStateChanged` callback

3.5 WHEN `SimulationController.skipCurrentTemple()` or `skipTempleAtIndex()` is called THEN the system SHALL CONTINUE TO remove the temple from `_currentRoute` and call `notifyListeners()`

3.6 WHEN `MapScreen` renders with zero temples selected THEN the system SHALL CONTINUE TO show all temple markers with no polyline

3.7 WHEN `RoutePlannerScreen` is opened with a valid temple list THEN the system SHALL CONTINUE TO display the vehicle selector, statistics row, map, and budget summary without errors

3.8 WHEN `StorytellingScreen` loads content for a temple THEN the system SHALL CONTINUE TO display the story text and content-type selector chips regardless of TTS availability

---

## Bug Condition Pseudocode

```pascal
// Bug 1.1 — False GPS from camera
FUNCTION isBugCondition_FalseGPS(event)
  INPUT: event of type CameraMove | GeolocatorFix
  OUTPUT: boolean
  RETURN event.source = CameraMove AND event is used as GPS position
END FUNCTION

FOR ALL event WHERE isBugCondition_FalseGPS(event) DO
  result ← _updateUserPosition'(event)
  ASSERT result does NOT update _currentUserPosition
END FOR

FOR ALL event WHERE NOT isBugCondition_FalseGPS(event) DO
  ASSERT F(event) = F'(event)  // GeolocatorFix still updates position
END FOR

// Bug 1.6 — Zero distance in simulation
FUNCTION isBugCondition_ZeroDistance(a, b)
  INPUT: a, b of type Temple
  OUTPUT: boolean
  RETURN true  // always buggy — method always returns 0.0
END FUNCTION

FOR ALL (a, b) WHERE isBugCondition_ZeroDistance(a, b) DO
  result ← _calculateDistance'(a, b)
  ASSERT result = haversineDistance(a.lat, a.lng, b.lat, b.lng)
  ASSERT result > 0.0 WHEN a ≠ b
END FOR
```
