# Bugfix Requirements Document

## Introduction

This document covers five high-impact bugs in the Temple Yatra Flutter app (SQLite + Riverpod, local-first). The fixes are scoped to minimal, targeted changes only — no major refactors, no breaking of working features, and no redesigns. SQLite remains the source of truth throughout.

---

## Bug 1 — Festival Calendar & Crowd Indicator

### Bug Analysis

#### Current Behavior (Defect)

1.1 WHEN `TempleCalendarScreen` is opened for any temple other than Birla Mandir THEN the system shows "No upcoming festivals scheduled" even though festival data exists in SQLite for that temple.

1.2 WHEN `computeCrowdLevel` is called with a `templeId` and a list of events THEN the system returns `CrowdLevel.low` for temples whose festivals are not loaded, because `templeFestivalsProvider` returns an empty list while the async DB query is still in flight.

1.3 WHEN `festivalProvider` (the global provider) is used to supply events to crowd indicators THEN the system may return events for the wrong temple because the provider fetches all upcoming festivals without filtering by `templeId` before passing them to `computeCrowdLevel`.

#### Expected Behavior (Correct)

2.1 WHEN `TempleCalendarScreen` is opened for any temple that has festival rows in the `festivals` SQLite table THEN the system SHALL display those festivals in the list.

2.2 WHEN `templeFestivalsProvider(templeId)` is loading THEN the system SHALL show a loading indicator rather than an empty list, so that crowd level is not computed against an empty event set.

2.3 WHEN `computeCrowdLevel` is called for a given `templeId` THEN the system SHALL only consider festival events whose `templeId` matches, which is already enforced inside `computeCrowdLevel` — the caller must pass the full event list for that temple, not a globally-filtered list.

#### Unchanged Behavior (Regression Prevention)

3.1 WHEN `TempleCalendarScreen` is opened for Birla Mandir THEN the system SHALL CONTINUE TO display its festivals correctly.

3.2 WHEN a temple has no festival rows in SQLite THEN the system SHALL CONTINUE TO show "No upcoming festivals scheduled".

3.3 WHEN `CrowdBadge` is rendered with a computed `CrowdLevel` THEN the system SHALL CONTINUE TO display the correct badge color and label.

---

## Bug 2 — Community Grouping by Temple

### Bug Analysis

#### Current Behavior (Defect)

2.1.1 WHEN a user opens `CommunityScreen` THEN the system shows all posts from all temples in a single undifferentiated feed with no way to filter by temple.

2.1.2 WHEN a user wants to read posts about a specific temple THEN the system provides no filter mechanism, forcing the user to scroll through all posts.

2.1.3 WHEN `communityFeedProvider` is built THEN the system calls `CommunityRepository.getFeed()` which returns all posts regardless of `temple_id`, and no temple filter is applied at the provider or UI layer.

#### Expected Behavior (Correct)

2.2.1 WHEN a user opens the Feed tab in `CommunityScreen` THEN the system SHALL display a temple filter dropdown (populated from `allTemplesDbProvider`) above the post list, with an "All Temples" default option.

2.2.2 WHEN a user selects a specific temple from the filter dropdown THEN the system SHALL show only posts whose `templeId` matches the selected temple.

2.2.3 WHEN "All Temples" is selected THEN the system SHALL show all posts (current behavior preserved).

2.2.4 WHEN `CommunityRepository.getFeed()` is called THEN the system SHALL CONTINUE TO return all posts; filtering SHALL be applied in the UI layer only, reusing the existing provider without a new DB query.

#### Unchanged Behavior (Regression Prevention)

3.2.1 WHEN a user submits a new post with a selected temple THEN the system SHALL CONTINUE TO save the post with the correct `templeId` and `templeName`.

3.2.2 WHEN a user likes or deletes a post THEN the system SHALL CONTINUE TO work correctly regardless of the active temple filter.

3.2.3 WHEN the Contribute tab is open THEN the system SHALL CONTINUE TO show the post submission form unchanged.

---

## Bug 3 — Layout Overflow Issues

### Bug Analysis

#### Current Behavior (Defect)

3.1.1 WHEN `CommunityScreen` renders on a narrow device (width < 360 dp) THEN the system throws a RenderFlex overflow error in the author row of `_PostCard` because the author name and role badge are not constrained.

3.1.2 WHEN `TempleDetailScreen` renders the quick-actions row (Directions + Call buttons) on a narrow device THEN the system throws a RenderFlex overflow error because the `Row` children are not wrapped in `Expanded`.

3.1.3 WHEN `TempleDetailScreen` renders the festival list row (crowd badge + name + spacer + date) THEN the system throws a RenderFlex overflow error when the festival name is long, because the name `Text` widget has no `Expanded` wrapper.

3.1.4 WHEN `YatraPlannerScreen` renders the temple selection `Wrap` with many chips on a small screen THEN the system may overflow because individual chip labels are not constrained.

3.1.5 WHEN `RoutePlannerScreen` renders the statistics row THEN the system may overflow on narrow screens because `_buildStatCard` column children have no width constraint.

#### Expected Behavior (Correct)

3.2.1 WHEN `_PostCard` renders the author row THEN the system SHALL wrap the author name and role badge column in an `Expanded` widget so it never overflows.

3.2.2 WHEN `TempleDetailScreen` renders the quick-actions row THEN the system SHALL use `Expanded` on both buttons (already done) and ensure no unconstrained children exist.

3.2.3 WHEN `TempleDetailScreen` renders each festival row THEN the system SHALL wrap the festival name `Text` in `Expanded` so long names are ellipsized rather than overflowing.

3.2.4 WHEN `YatraPlannerScreen` renders temple chips THEN the system SHALL ensure chip labels use `overflow: TextOverflow.ellipsis` and a `maxWidth` constraint so they do not overflow.

3.2.5 WHEN `RoutePlannerScreen` renders the statistics row THEN the system SHALL wrap each `_buildStatCard` in `Expanded` so the row distributes space evenly on all screen widths.

#### Unchanged Behavior (Regression Prevention)

3.3.1 WHEN the layout renders on a standard-width device (≥ 360 dp) THEN the system SHALL CONTINUE TO display all UI elements with the same visual appearance.

3.3.2 WHEN `CrowdBadge` is rendered inside a festival row THEN the system SHALL CONTINUE TO display correctly alongside the festival name and date.

---

## Bug 4 — Itinerary Planning Issues

### Bug Analysis

#### Current Behavior (Defect)

4.1.1 WHEN `ItineraryGenerator._createDailyPlans` calculates the arrival time for the first temple of each day THEN the system passes `previousArrivalTime = '08:00 AM'` and `dailyDuration = Duration.zero`, but `_calculateArrivalTime` adds `elapsed.inMinutes` (which is 0) to the start time — this part is correct. However, for subsequent temples, `dailyDuration` accumulates both travel time AND darshan time, so the arrival time for temple N is offset by the sum of all previous durations rather than just the time since the previous departure.

4.1.2 WHEN `_calculateArrivalTime` is called with a `previousTime` string and an `elapsed` Duration THEN the system adds `elapsed.inMinutes` to the parsed time, but `elapsed` is `dailyDuration` (total day elapsed so far) rather than the time elapsed since the last departure — causing arrival times to drift forward incorrectly for days with more than 2 temples.

4.1.3 WHEN `_calculateDepartureTime` is called THEN the system correctly adds `darshanDuration` to `arrivalTime`, but the next arrival is computed from `departureTime` plus the full `dailyDuration` again, creating a double-counting of elapsed time.

4.1.4 WHEN `SmartSchedulerService._allocateDays` flushes a day and starts a new one THEN the system correctly resets `currentDayMinutes = 0.0` but does NOT reset `currentTemples = []` before the `continue` statement — the temple that triggered the flush is added to `currentTemples` after the reset, which is correct. However, the `dayIndex >= request.numberOfDays` break exits without flushing the last partial day, potentially dropping temples.

#### Expected Behavior (Correct)

4.2.1 WHEN `ItineraryGenerator._createDailyPlans` computes arrival time for temple N THEN the system SHALL compute it as `departureTime[N-1] + travelTime[N]`, not as `startTime + dailyDuration`.

4.2.2 WHEN `_calculateArrivalTime` is called THEN the system SHALL receive only the incremental time since the last departure (travel time to next temple), not the cumulative day duration.

4.2.3 WHEN `SmartSchedulerService._allocateDays` reaches `dayIndex >= request.numberOfDays` THEN the system SHALL stop adding new days but SHALL NOT drop temples that were already assigned to the last valid day.

4.2.4 WHEN timings are computed by `SmartSchedulerService._computeTimings` THEN the system SHALL produce monotonically increasing arrival and departure times across all visits in a day (already enforced by the existing assert — the fix must ensure the assert never fires).

#### Unchanged Behavior (Regression Prevention)

4.3.1 WHEN a single-temple day is generated THEN the system SHALL CONTINUE TO show arrival = start time and departure = start time + darshan duration.

4.3.2 WHEN `SmartSchedulerService` generates an itinerary THEN the system SHALL CONTINUE TO use `RoutingEngine` for temple ordering and `BudgetService` for cost estimation.

4.3.3 WHEN `ItineraryPreviewScreen` renders a generated itinerary THEN the system SHALL CONTINUE TO display day cards and visit tiles correctly.

---

## Bug 5 — Dynamic Rerouting Issues

### Bug Analysis

#### Current Behavior (Defect)

5.1.1 WHEN `_triggerReRouting` is called and `_currentWaypointIndex > 0` THEN the system calls `_optimizedRoute.sublist(_currentWaypointIndex)` to get remaining temples, but then searches for the nearest temple within that sublist and computes `nearestIndex = _currentWaypointIndex + i` — this is correct. However, `_optimizedRoute = newRoute` replaces the full route with only the remaining segment, so `_currentWaypointIndex` is reset to 0 but the route no longer contains already-visited temples. On the next reroute, `sublist(0)` is the full remaining route, which is correct. This logic appears sound in the current code.

5.1.2 WHEN `_startGpsTracking` starts the position stream THEN the system calls `_updateUserPosition` on every GPS update, which calls `setState` — but `_checkRouteDeviation` is only called by the 10-second timer, not by GPS updates. If the timer fires while `_isReRoutingInProgress = true`, the check is skipped. However, if the user moves off-route between timer ticks, the deviation is not detected until the next tick, which can be up to 10 seconds late.

5.1.3 WHEN `_updateUserPosition` is called with a new GPS position THEN the system updates `_currentUserPosition` but does NOT call `_checkRouteDeviation`, meaning GPS stream updates do not trigger reroute checks — only the periodic timer does.

5.1.4 WHEN `_checkRouteDeviation` checks movement with `if (movement < 0.05)` (50 meters) THEN the system skips the deviation check and returns early, but also sets `_lastCheckedPosition = _currentUserPosition` inside the early-return branch — meaning the position is updated even when the check is skipped, so the next check will again compare against the most recent position rather than the last position where a check was actually performed.

#### Expected Behavior (Correct)

5.2.1 WHEN `_updateUserPosition` receives a new GPS position THEN the system SHALL call `_checkRouteDeviation` directly so that reroute detection is triggered by GPS updates, not only by the periodic timer.

5.2.2 WHEN `_checkRouteDeviation` determines the user has not moved significantly (< 50 m) THEN the system SHALL NOT update `_lastCheckedPosition`, so that the movement threshold is measured from the last position where a full check was performed.

5.2.3 WHEN `_triggerReRouting` selects the nearest remaining temple THEN the system SHALL use the Haversine distance from `_currentUserPosition` to each remaining temple (already implemented correctly) and SHALL set `_currentWaypointIndex = 0` after replacing `_optimizedRoute` with the remaining segment.

5.2.4 WHEN the reroute completes THEN the system SHALL call `_fetchDirections` with the new route and show the rerouting snackbar (already implemented).

#### Unchanged Behavior (Regression Prevention)

5.3.1 WHEN the app runs on web (`kIsWeb == true`) THEN the system SHALL CONTINUE TO skip GPS tracking and route monitoring.

5.3.2 WHEN the user has not deviated from the route THEN the system SHALL CONTINUE TO advance `_currentWaypointIndex` as waypoints are reached.

5.3.3 WHEN location permission is denied THEN the system SHALL CONTINUE TO function without GPS, with manual reroute available via the banner button.

5.3.4 WHEN `_isReRoutingInProgress` is true THEN the system SHALL CONTINUE TO skip redundant reroute checks to prevent concurrent reroutes.
