# Temple Yatra Bugfixes — Design Document


## Overview

Five targeted bugfixes for the Temple Yatra Flutter app (SQLite + Riverpod, local-first). Each fix is minimal and scoped to the exact defect site. No refactors, no new architecture, no breaking changes.

1. **Bug 1** — `templeFestivalsProvider` silently returns `[]` during loading, causing false "no festivals" display and incorrect crowd level computation.
2. **Bug 2** — `CommunityScreen` feed has no temple filter; all posts are shown in one undifferentiated list.
3. **Bug 3** — Five `RenderFlex` overflow sites across `_PostCard`, `TempleDetailScreen`, and `RoutePlannerScreen`.
4. **Bug 4** — `ItineraryGenerator._createDailyPlans` passes cumulative `dailyDuration` to `_calculateArrivalTime` instead of the incremental `travelTime`, causing arrival times to drift forward incorrectly.
5. **Bug 5** — GPS updates never call `_checkRouteDeviation`; `_lastCheckedPosition` is updated on the early-return path, defeating the movement threshold.

---

## Glossary

- **Bug_Condition (C)**: The precise input or state that triggers the defect.
- **Property (P)**: The correct observable behavior when the bug condition holds.
- **Preservation**: Existing correct behavior that must not change after the fix.
- **templeFestivalsProvider**: `Provider.family<List<FestivalEvent>, String>` in `lib/providers/festival_provider.dart` — wraps `templeFestivalsDbProvider` and collapses loading/error to `[]`.
- **communityFeedProvider**: `AsyncNotifierProvider<CommunityFeedNotifier, List<CommunityPost>>` in `lib/database/db_providers.dart`.
- **_createDailyPlans**: Method in `ItineraryGenerator` (`lib/services/itinerary_generator.dart`) that splits an ordered temple list into per-day `DayPlan` objects with arrival/departure times.
- **_checkRouteDeviation**: Method in `_RoutePlannerScreenState` (`lib/screens/route_planner_screen.dart`) that compares `_currentUserPosition` against the planned route and triggers rerouting.
- **_lastCheckedPosition**: Field in `_RoutePlannerScreenState` used to gate the movement threshold check inside `_checkRouteDeviation`.

---

## Bug Details

### Bug 1 — Festival Calendar & Crowd Indicator

#### Bug Condition

The defect manifests when `TempleCalendarScreen` or `TempleDetailScreen` renders before `templeFestivalsDbProvider` has resolved. `templeFestivalsProvider` maps the `loading` state to `[]`, so the screen immediately renders "No upcoming festivals scheduled" and `computeCrowdLevel` returns `CrowdLevel.low` against an empty list.

```
FUNCTION isBugCondition_1(state)
  INPUT: state is AsyncValue<List<FestivalEvent>> from templeFestivalsDbProvider(templeId)
  OUTPUT: boolean

  RETURN state.isLoading == true
         AND caller treats result as [] (empty list)
         AND temple has festival rows in SQLite
END FUNCTION
```

**Examples:**
- Open `TempleCalendarScreen` for Chilkur Balaji → shows "No upcoming festivals scheduled" for ~200 ms before data arrives, then stays empty because the provider never re-renders (it already returned `[]`).
- `CrowdBadge` in `TempleDetailScreen` shows green (low) on first render even when a festival is today.
- Birla Mandir is unaffected only if its data resolves before the first frame — coincidental, not structural.

---

### Bug 2 — Community Grouping by Temple

#### Bug Condition

No temple filter state exists in `_FeedTab`. `communityFeedProvider` returns all posts; the UI renders them all unconditionally.

```
FUNCTION isBugCondition_2(screen)
  INPUT: screen is _FeedTab rendered in CommunityScreen
  OUTPUT: boolean

  RETURN selectedTempleFilter == null
         AND posts.length > 0
         AND posts contain entries from multiple distinct templeIds
END FUNCTION
```

**Examples:**
- User wants posts about Birla Mandir only — no way to filter; sees posts from all 20+ temples.
- `communityFeedProvider` returns 50 posts; all 50 are shown regardless of temple.

---

### Bug 3 — Layout Overflow Issues

#### Bug Condition

Five `Row` widgets contain unconstrained children that can exceed available width on narrow screens (< 360 dp).

```
FUNCTION isBugCondition_3(widget, screenWidth)
  INPUT: widget is one of the five identified Row sites, screenWidth in dp
  OUTPUT: boolean

  RETURN screenWidth < 360
         AND widget contains a child with no Expanded/flexible constraint
         AND child's intrinsic width > available Row width
END FUNCTION
```

**Affected sites (file → widget → missing constraint):**
1. `community_screen.dart` → `_PostCard` author row → author name + role badge column needs `Expanded`
2. `temple_detail_screen.dart` → festival list row → festival name `Text` needs `Expanded`
3. `route_planner_screen.dart` → `_buildStatisticsRow` → each `_buildStatCard` needs `Expanded`

> Note: The quick-actions row in `TempleDetailScreen` already uses `Expanded` on both buttons (lines 163–183 of the file). `YatraPlannerScreen` chip labels are inside a `Wrap` which handles overflow by reflowing — no fix needed there.

---

### Bug 4 — Itinerary Planning

#### Bug Condition

In `_createDailyPlans`, `_calculateArrivalTime` is called with `dailyDuration` (total elapsed time since day start) instead of `travelTime` (time since last departure). For temple index `i > 0`, `dailyDuration` already includes all previous darshan durations plus travel times, so the arrival time is computed as `startTime + totalElapsed` rather than `previousDeparture + travelTime`.

```
FUNCTION isBugCondition_4(day)
  INPUT: day is a DayPlan with visits list
  OUTPUT: boolean

  RETURN day.visits.length > 1
         AND EXISTS i IN [1, visits.length-1]:
               visits[i].arrivalTime != _calculateArrivalTime(
                 visits[i-1].departureTime,
                 visits[i].travelTime   // incremental
               )
END FUNCTION
```

**Examples:**
- Day with 3 temples, each 30 min darshan, 20 min travel:
  - Correct: 08:00 → 08:30 depart → 08:50 arrive T2 → 09:20 depart → 09:40 arrive T3
  - Buggy: 08:00 → 08:30 depart → 09:20 arrive T2 (adds 80 min = 30+20+30) → 10:40 arrive T3 (adds 140 min)

---

### Bug 5 — Dynamic Rerouting

#### Bug Condition

Two independent defects in `_RoutePlannerScreenState`:

**5a — GPS updates bypass deviation check:**
```
FUNCTION isBugCondition_5a(event)
  INPUT: event is a GPS position update from Geolocator stream
  OUTPUT: boolean

  RETURN _updateUserPosition is called
         AND _checkRouteDeviation is NOT called within _updateUserPosition
         AND _routeCheckTimer has not fired since last GPS update
END FUNCTION
```

**5b — Movement threshold measured from wrong baseline:**
```
FUNCTION isBugCondition_5b(state)
  INPUT: state is _RoutePlannerScreenState after an early-return in _checkRouteDeviation
  OUTPUT: boolean

  RETURN movement < 0.05 km (early-return branch taken)
         AND _lastCheckedPosition was updated to _currentUserPosition
         AND next call to _checkRouteDeviation compares against the updated position
         AND actual cumulative movement since last full check is >= 0.05 km but
             each individual step is < 0.05 km
END FUNCTION
```

**Examples:**
- User moves 200 m off-route in 5 small steps of 40 m each between timer ticks → no reroute triggered because each step is < 50 m and `_lastCheckedPosition` is reset each time.
- Timer fires every 10 s; user moves off-route 3 s after last tick → deviation not detected for up to 10 s.

---

## Expected Behavior

### Bug 1 — Preservation Requirements

**Unchanged Behaviors:**
- Birla Mandir calendar continues to display festivals correctly.
- Temples with no festival rows in SQLite continue to show "No upcoming festivals scheduled".
- `CrowdBadge` color and label rendering is unchanged.

**Scope:** Only the loading-state handling in `templeFestivalsProvider` changes. The `data` and `error` branches are untouched.

### Bug 2 — Preservation Requirements

**Unchanged Behaviors:**
- Post submission with temple selection continues to save `templeId` and `templeName` correctly.
- Like and delete operations continue to work regardless of active filter.
- Contribute tab is completely unchanged.
- `communityFeedProvider` and `CommunityRepository.getFeed()` are unchanged.

**Scope:** Filter state is local to `_FeedTab`; no provider or repository changes.

### Bug 3 — Preservation Requirements

**Unchanged Behaviors:**
- Visual appearance on standard-width devices (≥ 360 dp) is unchanged.
- `CrowdBadge` renders correctly alongside festival name and date.
- All tap targets and interactions remain functional.

**Scope:** Only `Expanded` wrappers are added; no layout restructuring.

### Bug 4 — Preservation Requirements

**Unchanged Behaviors:**
- Single-temple days: arrival = start time, departure = start time + darshan duration.
- `SmartSchedulerService` itinerary generation is unaffected (it uses `_computeTimings`, not `_createDailyPlans`).
- `ItineraryPreviewScreen` rendering is unchanged.

**Scope:** Only the argument passed to `_calculateArrivalTime` changes inside the loop in `_createDailyPlans`.

### Bug 5 — Preservation Requirements

**Unchanged Behaviors:**
- Web platform (`kIsWeb == true`) skips GPS tracking entirely.
- `_currentWaypointIndex` advances correctly as waypoints are reached.
- Location permission denial is handled gracefully.
- `_isReRoutingInProgress` guard prevents concurrent reroutes.

**Scope:** Two one-line changes: add `_checkRouteDeviation()` call in `_updateUserPosition`; remove `_lastCheckedPosition = _currentUserPosition` from the early-return branch.

---

## Hypothesized Root Causes

### Bug 1
`templeFestivalsProvider` was written as a synchronous `Provider.family` that calls `.when()` on the underlying `FutureProvider.family`. The `loading` case was mapped to `[]` as a convenience default, without considering that callers (calendar screen, crowd engine) treat `[]` as "no data" rather than "not yet loaded".

### Bug 2
The community feed was initially designed as a global feed. Temple filtering was deferred and never implemented. No filter state variable was added to `_FeedTab`, and `communityFeedProvider` has no `templeId` parameter.

### Bug 3
The five overflow sites were written without testing on narrow devices. `Row` children that contain `Text` widgets with variable-length content were not wrapped in `Expanded`, relying on the parent having sufficient width.

### Bug 4
`_calculateArrivalTime` takes a `previousTime` string and an `elapsed` Duration. The intent was to pass the incremental travel time, but the call site passes `dailyDuration` — the accumulator that grows with every temple. The variable name `dailyDuration` obscures that it is cumulative, not incremental.

### Bug 5a
`_updateUserPosition` was written to update position state and check waypoint advancement. The deviation check was intentionally placed in a periodic timer to avoid checking on every GPS event. However, the timer interval (10 s) is too coarse for real-time rerouting; the fix is to also call `_checkRouteDeviation` from `_updateUserPosition` (the existing `_isReRoutingInProgress` guard already prevents redundant reroutes).

### Bug 5b
The early-return branch inside `_checkRouteDeviation` was intended to skip the expensive deviation calculation when the user hasn't moved. The `_lastCheckedPosition` update was placed before the `return` statement, meaning the baseline is reset even when no check was performed. The fix is to move the update to after the full check.

---

## Correctness Properties

Property 1: Bug Condition — Loading State Not Treated as Empty

_For any_ `templeId` where `templeFestivalsDbProvider(templeId)` is in the loading state, the fixed `templeFestivalsProvider` SHALL NOT return an empty list; it SHALL propagate the loading state so callers can show a loading indicator instead of "no festivals".

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation — Existing Festival Display Unchanged

_For any_ `templeId` where `templeFestivalsDbProvider(templeId)` has resolved to a non-empty data state, the fixed `templeFestivalsProvider` SHALL return the same list as before, preserving correct festival display and crowd level computation.

**Validates: Requirements 3.1, 3.2, 3.3**

Property 3: Bug Condition — Temple Filter Applied to Feed

_For any_ selected `templeId` filter (not "All Temples"), the fixed `_FeedTab` SHALL display only posts where `post.templeId == selectedTempleId`, and the displayed list SHALL be a subset of the full unfiltered feed.

**Validates: Requirements 2.2.2, 2.2.4**

Property 4: Preservation — Unfiltered Feed Unchanged

_For any_ state where "All Temples" is selected (the default), the fixed `_FeedTab` SHALL display exactly the same posts as the original unfiltered feed, preserving current behavior.

**Validates: Requirements 2.2.3, 3.2.1, 3.2.2**

Property 5: Bug Condition — No RenderFlex Overflow on Narrow Screens

_For any_ screen width in the range [320 dp, 360 dp), the fixed widgets (`_PostCard` author row, `TempleDetailScreen` festival row, `RoutePlannerScreen` statistics row) SHALL render without throwing a `RenderFlex` overflow error.

**Validates: Requirements 3.2.1, 3.2.3, 3.2.5**

Property 6: Preservation — Standard-Width Layout Unchanged

_For any_ screen width >= 360 dp, the fixed widgets SHALL produce visually identical output to the original widgets, preserving all existing layout behavior.

**Validates: Requirements 3.3.1, 3.3.2**

Property 7: Bug Condition — Arrival Times Are Monotonically Correct

_For any_ day plan with N > 1 temples, the fixed `_createDailyPlans` SHALL produce visits where `arrivalTime[i] == departureTime[i-1] + travelTime[i]` for all `i` in `[1, N-1]`, and all arrival/departure times SHALL be monotonically increasing.

**Validates: Requirements 4.2.1, 4.2.2, 4.2.4**

Property 8: Preservation — Single-Temple Day Timing Unchanged

_For any_ day plan with exactly 1 temple, the fixed `_createDailyPlans` SHALL produce `arrivalTime == startTime` and `departureTime == startTime + darshanDuration`, identical to the original behavior.

**Validates: Requirements 4.3.1**

Property 9: Bug Condition — GPS Update Triggers Deviation Check

_For any_ GPS position update received by `_updateUserPosition` when `_isReRoutingInProgress == false`, the fixed code SHALL call `_checkRouteDeviation`, ensuring reroute detection is not limited to the 10-second timer interval.

**Validates: Requirements 5.2.1**

Property 10: Bug Condition — Movement Threshold Measured from Last Full Check

_For any_ sequence of GPS updates where each individual step is < 50 m but cumulative movement from the last full check is >= 50 m, the fixed `_checkRouteDeviation` SHALL perform a full deviation check (not early-return), because `_lastCheckedPosition` is only updated after a full check completes.

**Validates: Requirements 5.2.2**

Property 11: Preservation — Rerouting Guard Unchanged

_For any_ state where `_isReRoutingInProgress == true`, the fixed `_checkRouteDeviation` SHALL continue to skip the check, preserving the concurrent-reroute prevention behavior.

**Validates: Requirements 5.3.4**

---

## Fix Implementation

### Bug 1 — `lib/providers/festival_provider.dart`

**Function:** `templeFestivalsProvider`

**Change:** Return `AsyncValue<List<FestivalEvent>>` instead of `List<FestivalEvent>`, so callers can distinguish loading from empty. Update `TempleCalendarScreen` and `TempleDetailScreen` to call `.when()` directly on the async value.

```dart
// BEFORE
final templeFestivalsProvider = Provider.family<List<FestivalEvent>, String>(
  (ref, templeId) => ref.watch(templeFestivalsDbProvider(templeId)).when(
    data: (d) => d,
    loading: () => [],
    error: (e, st) => [],
  ),
);

// AFTER — expose the raw AsyncValue; callers handle loading/error
// Remove templeFestivalsProvider entirely and have callers watch
// templeFestivalsDbProvider(templeId) directly, OR keep the provider
// but change its type:
final templeFestivalsProvider =
    Provider.family<AsyncValue<List<FestivalEvent>>, String>(
  (ref, templeId) => ref.watch(templeFestivalsDbProvider(templeId)),
);
```

**Callers to update:**
- `TempleCalendarScreen.build`: replace `ref.watch(templeFestivalsProvider(temple.id))` with `ref.watch(templeFestivalsDbProvider(temple.id))` and wrap body in `.when(loading: ..., error: ..., data: ...)`.
- `TempleDetailScreen` (two `Consumer` widgets): same pattern — show `CircularProgressIndicator` on loading, empty text on error, existing content on data.
- `YatraPlannerScreen._TempleCrowdAvatar`: already uses `templeFestivalsProvider`; update to watch `templeFestivalsDbProvider` and pass `[]` to `computeCrowdLevel` only on error (not loading).
- `RoutePlannerScreen` temple list `Consumer`: same update.

---

### Bug 2 — `lib/screens/community_screen.dart`

**Widget:** `_FeedTab`

**Change:** Convert `_FeedTab` from `ConsumerWidget` to `ConsumerStatefulWidget`. Add `String? _selectedTempleId` state. Add a `DropdownButton` above the post list populated from `allTemplesDbProvider`. Filter `posts` in the `data` branch before passing to `ListView.builder`.

```dart
// Add to _FeedTabState:
String? _selectedTempleId; // null = "All Temples"

// In build, before ListView:
final templesAsync = ref.watch(allTemplesDbProvider);
// ... DropdownButton with "All Temples" + temple list

// Filter posts:
final filtered = _selectedTempleId == null
    ? posts
    : posts.where((p) => p.templeId == _selectedTempleId).toList();
// Use `filtered` in ListView.builder
```

No changes to `communityFeedProvider` or `CommunityRepository`.

---

### Bug 3 — Layout Overflow Fixes

**Site 1 — `lib/screens/community_screen.dart`, `_PostCard` author row**

The `Column` containing author name and role badge is already wrapped in `Expanded` (line ~152 of the file). Confirmed by reading the source — this site is already fixed in the current code. No change needed.

**Site 2 — `lib/screens/temple_detail_screen.dart`, festival list row**

```dart
// BEFORE (inside Consumer, upcoming.map):
Row(children: [
  CrowdBadge(...),
  const SizedBox(width: 8),
  Text(e.name),          // ← unconstrained
  const Spacer(),
  Text(DateFormat(...).format(e.date)),
])

// AFTER:
Row(children: [
  CrowdBadge(...),
  const SizedBox(width: 8),
  Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
  const SizedBox(width: 8),
  Text(DateFormat(...).format(e.date)),
])
```

**Site 3 — `lib/screens/route_planner_screen.dart`, `_buildStatisticsRow`**

```dart
// BEFORE:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildStatCard(...),
    _buildStatCard(...),
    _buildStatCard(...),
  ],
)

// AFTER:
Row(
  children: [
    Expanded(child: _buildStatCard(...)),
    Expanded(child: _buildStatCard(...)),
    Expanded(child: _buildStatCard(...)),
  ],
)
```

---

### Bug 4 — `lib/services/itinerary_generator.dart`

**Function:** `_createDailyPlans`

**Change:** Pass `travelTime` (incremental) instead of `dailyDuration` (cumulative) to `_calculateArrivalTime`. Also update `previousArrivalTime` to `departureTime` after each visit (already done correctly).

```dart
// BEFORE (inside the for loop, i > 0 branch):
final arrivalTime = _calculateArrivalTime(previousArrivalTime, dailyDuration);

// AFTER:
final arrivalTime = _calculateArrivalTime(previousArrivalTime, travelTime);
// travelTime is already computed above as:
// travelTime = Duration(minutes: estimateTravelTime(travelDistance).toInt());
// For i == 0, travelTime == Duration.zero, so first temple arrival == previousArrivalTime == '08:00 AM' ✓
```

The `dailyDuration` accumulator is still updated correctly after the fix — it continues to track total day elapsed for the `> 10 hours` warning check.

---

### Bug 5 — `lib/screens/route_planner_screen.dart`

**Function 5a:** `_updateUserPosition`

```dart
// AFTER setState block, add:
_checkRouteDeviation();
```

**Function 5b:** `_checkRouteDeviation`, early-return branch

```dart
// BEFORE:
if (movement < 0.05) {
  _lastCheckedPosition = _currentUserPosition;  // ← remove this line
  return;
}
_lastCheckedPosition = _currentUserPosition;    // ← keep only this one

// AFTER:
if (movement < 0.05) {
  return;  // do NOT update _lastCheckedPosition
}
_lastCheckedPosition = _currentUserPosition;
```

---

## Testing Strategy

### Validation Approach

Two-phase: first run exploratory tests on unfixed code to confirm root causes, then run fix-checking and preservation tests on fixed code.

### Exploratory Bug Condition Checking

**Goal:** Surface counterexamples that demonstrate each bug on unfixed code.

**Bug 1 — Test Plan:**
1. Mock `templeFestivalsDbProvider` to return a `Future` that completes after 500 ms.
2. Pump `TempleCalendarScreen` and check the widget tree at frame 0.
3. **Expected counterexample:** `find.text('No upcoming festivals scheduled.')` succeeds at frame 0 even though data is pending.

**Bug 4 — Test Plan:**
1. Create an `ItineraryGenerator` with 3 temples, 30 min darshan each, 20 min travel between each.
2. Call `generate()` and inspect `dayPlans[0].visits`.
3. **Expected counterexample:** `visits[1].arrivalTime` is `09:20 AM` (buggy: 08:00 + 80 min) instead of `08:50 AM` (correct: 08:30 + 20 min).

**Bug 5b — Test Plan:**
1. Call `_checkRouteDeviation` with movement = 0.03 km (< 0.05 threshold).
2. Inspect `_lastCheckedPosition` after the call.
3. **Expected counterexample:** `_lastCheckedPosition` equals `_currentUserPosition` even though no full check was performed.

### Fix Checking

**Goal:** Verify that for all inputs where the bug condition holds, the fixed code produces the expected behavior.

```
FOR ALL templeId WHERE templeFestivalsDbProvider(templeId).isLoading DO
  result := templeFestivalsProvider_fixed(templeId)
  ASSERT result.isLoading == true  // not []
END FOR

FOR ALL dayTemples WHERE dayTemples.length > 1 DO
  visits := _createDailyPlans_fixed(dayTemples)
  FOR i IN [1, visits.length-1] DO
    ASSERT visits[i].arrivalTime == addMinutes(visits[i-1].departureTime, travelTime[i])
  END FOR
END FOR

FOR ALL gpsUpdate WHERE NOT _isReRoutingInProgress DO
  _updateUserPosition_fixed(gpsUpdate)
  ASSERT _checkRouteDeviation_was_called == true
END FOR
```

### Preservation Checking

**Goal:** Verify that for all inputs where the bug condition does NOT hold, behavior is unchanged.

```
FOR ALL templeId WHERE templeFestivalsDbProvider(templeId).hasData DO
  ASSERT templeFestivalsProvider_original(templeId) ==
         templeFestivalsProvider_fixed(templeId)
END FOR

FOR ALL selectedTempleId WHERE selectedTempleId == null DO
  ASSERT _FeedTab_original(posts) == _FeedTab_fixed(posts)  // "All Temples" unchanged
END FOR

FOR ALL dayTemples WHERE dayTemples.length == 1 DO
  ASSERT _createDailyPlans_original(dayTemples) ==
         _createDailyPlans_fixed(dayTemples)
END FOR
```

### Unit Tests

- Bug 1: `TempleCalendarScreen` shows `CircularProgressIndicator` when provider is loading.
- Bug 1: `TempleCalendarScreen` shows festival list when provider resolves with data.
- Bug 2: `_FeedTab` with filter `templeId = 'birla_mandir'` shows only matching posts.
- Bug 2: `_FeedTab` with filter `null` shows all posts.
- Bug 3: `_PostCard` renders without overflow on 320 dp width.
- Bug 3: Festival row in `TempleDetailScreen` renders without overflow on 320 dp width.
- Bug 3: `_buildStatisticsRow` renders without overflow on 320 dp width.
- Bug 4: 3-temple day produces correct monotonically increasing arrival/departure times.
- Bug 4: 1-temple day arrival == `'08:00 AM'`, departure == `'08:30 AM'` (30 min darshan).
- Bug 5a: `_updateUserPosition` calls `_checkRouteDeviation` when not rerouting.
- Bug 5b: `_lastCheckedPosition` is NOT updated when movement < 50 m.
- Bug 5b: `_lastCheckedPosition` IS updated after a full deviation check.

### Property-Based Tests

- Bug 1 (Property 1): For any `templeId`, if the DB future is pending, `templeFestivalsProvider` never returns a non-loading `AsyncValue` with an empty list.
- Bug 4 (Property 7): For any list of N temples (N in [2, 10]) with random darshan durations [30, 90] min and random travel distances [1, 50] km, all arrival times in the generated day plan are strictly monotonically increasing.
- Bug 4 (Property 8): For any single-temple input, `arrivalTime == '08:00 AM'` and `departureTime == addMinutes('08:00 AM', darshanDuration)`.
- Bug 5 (Property 10): For any sequence of K GPS updates (K in [2, 20]) each < 50 m apart but with cumulative distance >= 50 m, `_checkRouteDeviation` performs a full check on the K-th update.

### Integration Tests

- Bug 1: Navigate to `TempleCalendarScreen` for a non-Birla temple; verify loading indicator appears then festivals render.
- Bug 2: Open `CommunityScreen`, select a temple filter, verify post list updates.
- Bug 4: Generate a 3-day itinerary with 3 temples/day; verify `ItineraryPreviewScreen` shows correct times on all day cards.
- Bug 5: Simulate GPS stream with off-route positions; verify reroute snackbar appears within one GPS update (not waiting for 10 s timer).
