# Implementation Plan

- [x] 1. Write bug condition exploration tests
  - **Property 1: Bug Condition** - Festival Loading State Treated as Empty / Arrival Time Drift / GPS Deviation Bypass
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms the bugs exist
  - **DO NOT attempt to fix the tests or the code when they fail**
  - **GOAL**: Surface counterexamples that demonstrate each bug on unfixed code

  - [x] 1.1 Bug 1 — `templeFestivalsProvider` loading state collapses to `[]`
    - In `test/providers/festival_provider_test.dart`, mock `templeFestivalsDbProvider` to return a `Future` that never completes (simulates in-flight DB query)
    - Watch `templeFestivalsProvider(templeId)` and assert the result is NOT an empty list while loading
    - **Expected counterexample**: `templeFestivalsProvider` returns `[]` while DB is still loading — confirms Bug 1
    - Run on UNFIXED code; expect FAILURE
    - _Requirements: 1.2, 2.2_

  - [x] 1.2 Bug 4 — `_createDailyPlans` arrival time drift
    - In `test/services/itinerary_generator_test.dart`, create an `ItineraryGenerator` with 3 temples, 30 min darshan each, 20 min travel between each
    - Call `generate()` and inspect `dayPlans[0].visits`
    - Assert `visits[1].arrivalTime == '08:50 AM'` (correct: 08:30 depart + 20 min travel)
    - **Expected counterexample**: `visits[1].arrivalTime` is `'09:20 AM'` (buggy: 08:00 + 80 min cumulative) — confirms Bug 4
    - Run on UNFIXED code; expect FAILURE
    - _Requirements: 4.1.1, 4.1.2, 4.2.1_

  - [x] 1.3 Bug 5b — `_lastCheckedPosition` updated on early-return path
    - In `test/screens/route_planner_screen_test.dart`, call `_checkRouteDeviation` with movement < 0.05 km
    - Assert `_lastCheckedPosition` is NOT updated after the early-return branch
    - **Expected counterexample**: `_lastCheckedPosition` equals `_currentUserPosition` even though no full check was performed — confirms Bug 5b
    - Run on UNFIXED code; expect FAILURE
    - _Requirements: 5.1.4, 5.2.2_

- [x] 2. Write preservation property tests (BEFORE implementing fixes)
  - **Property 2: Preservation** - Existing Correct Behaviors Unchanged
  - **IMPORTANT**: Follow observation-first methodology — run unfixed code with non-buggy inputs, observe outputs, then write tests
  - Run tests on UNFIXED code; expect PASS (confirms baseline to preserve)

  - [x] 2.1 Bug 1 preservation — resolved data state returns correct festival list
    - Observe: `templeFestivalsProvider` with a resolved `data` state returns the festival list correctly on unfixed code
    - Write property test: for any `templeId` where `templeFestivalsDbProvider` has resolved with data, `templeFestivalsProvider` returns the same list
    - Verify PASSES on unfixed code
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 2.2 Bug 2 preservation — "All Temples" shows all posts
    - Observe: `_FeedTab` with no filter selected shows all posts on unfixed code
    - Write test: when `_selectedTempleId == null`, the displayed post list equals the full unfiltered feed
    - Verify PASSES on unfixed code
    - _Requirements: 2.2.3, 3.2.1, 3.2.2_

  - [x] 2.3 Bug 4 preservation — single-temple day timing unchanged
    - Observe: `_createDailyPlans` with 1 temple produces `arrivalTime == '08:00 AM'` and `departureTime == '08:30 AM'` (30 min darshan) on unfixed code
    - Write property test: for any single-temple day, `arrivalTime == startTime` and `departureTime == startTime + darshanDuration`
    - Verify PASSES on unfixed code
    - _Requirements: 4.3.1_

  - [x] 2.4 Bug 5 preservation — rerouting guard prevents concurrent reroutes
    - Observe: when `_isReRoutingInProgress == true`, `_checkRouteDeviation` returns early on unfixed code
    - Write test: calling `_checkRouteDeviation` while `_isReRoutingInProgress == true` does not trigger a new reroute
    - Verify PASSES on unfixed code
    - _Requirements: 5.3.4_

- [x] 3. Fix Bug 1 — `templeFestivalsProvider` loading state

  - [x] 3.1 Update `lib/providers/festival_provider.dart`
    - Change `templeFestivalsProvider` return type from `Provider.family<List<FestivalEvent>, String>` to `Provider.family<AsyncValue<List<FestivalEvent>>, String>`
    - Remove the `.when()` call; return `ref.watch(templeFestivalsDbProvider(templeId))` directly
    - _Bug_Condition: `templeFestivalsDbProvider(templeId).isLoading == true` and caller receives `[]`_
    - _Expected_Behavior: provider returns `AsyncValue.loading()` so callers can show a loading indicator_
    - _Preservation: `data` branch continues to return the festival list unchanged_
    - _Requirements: 1.2, 2.1, 2.2, 3.1, 3.2, 3.3_

  - [x] 3.2 Update `lib/screens/temple_calendar_screen.dart`
    - Replace `ref.watch(templeFestivalsProvider(temple.id))` with `ref.watch(templeFestivalsDbProvider(temple.id))`
    - Wrap the body in `.when(loading: () => const CircularProgressIndicator(), error: (e, _) => const SizedBox(), data: (allEvents) { ... })`
    - _Requirements: 2.1, 2.2_

  - [x] 3.3 Update `lib/screens/temple_detail_screen.dart` — crowd status Consumer (line ~212)
    - Replace `ref.watch(templeFestivalsProvider(temple.id))` with `ref.watch(templeFestivalsDbProvider(temple.id))`
    - In the Consumer, call `.when(loading: () => const SizedBox(), error: (e, _) => const SizedBox(), data: (events) { ... computeCrowdLevel ... })`
    - _Requirements: 2.2, 3.3_

  - [x] 3.4 Update `lib/screens/temple_detail_screen.dart` — festival list Consumer (line ~293)
    - Replace `ref.watch(templeFestivalsProvider(temple.id))` with `ref.watch(templeFestivalsDbProvider(temple.id))`
    - Wrap with `.when(loading: () => const CircularProgressIndicator(), error: (e, _) => const SizedBox(), data: (events) { ... })`
    - _Requirements: 2.1, 2.2_

  - [x] 3.5 Update `lib/screens/route_planner_screen.dart` — temple list Consumer (line ~680)
    - Replace `ref.watch(templeFestivalsProvider(temple.id))` with `ref.watch(templeFestivalsDbProvider(temple.id))`
    - Pass `[]` to `computeCrowdLevel` only on error (not loading); show `CrowdBadge(level: CrowdLevel.low)` as placeholder on loading
    - _Requirements: 2.2, 3.3_

  - [x] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Loading State Propagated Correctly
    - Re-run the SAME test from task 1.1 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (confirms `templeFestivalsProvider` no longer collapses loading to `[]`)
    - _Requirements: 2.1, 2.2_

  - [x] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Resolved Festival Data Unchanged
    - Re-run the SAME test from task 2.1
    - **EXPECTED OUTCOME**: Test PASSES (no regressions in data/error branches)

- [x] 4. Fix Bug 2 — Community feed temple filter

  - [x] 4.1 Convert `_FeedTab` to `ConsumerStatefulWidget` in `lib/screens/community_screen.dart`
    - Change `class _FeedTab extends ConsumerWidget` to `class _FeedTab extends ConsumerStatefulWidget`
    - Add `ConsumerState<_FeedTab> createState() => _FeedTabState()`
    - Create `class _FeedTabState extends ConsumerState<_FeedTab>` with `String? _selectedTempleId` field
    - Move the `build` method body into `_FeedTabState.build`
    - _Bug_Condition: `_selectedTempleId == null` and posts contain multiple distinct `templeId` values_
    - _Expected_Behavior: when `_selectedTempleId != null`, only posts where `post.templeId == _selectedTempleId` are shown_
    - _Preservation: `communityFeedProvider` and `CommunityRepository.getFeed()` are unchanged_
    - _Requirements: 2.2.1, 2.2.2, 2.2.3, 2.2.4_

  - [x] 4.2 Add temple filter dropdown above the post list
    - In `_FeedTabState.build`, watch `allTemplesDbProvider` for the dropdown items
    - Add a `DropdownButton<String?>` above the `ListView.builder` with an "All Temples" null option plus one item per temple
    - On change, call `setState(() => _selectedTempleId = value)`
    - _Requirements: 2.2.1_

  - [x] 4.3 Apply filter to post list in the `data` branch
    - In the `data: (posts)` branch, compute `final filtered = _selectedTempleId == null ? posts : posts.where((p) => p.templeId == _selectedTempleId).toList()`
    - Pass `filtered` (not `posts`) to `ListView.builder`
    - _Requirements: 2.2.2, 2.2.3_

  - [x] 4.4 Verify bug condition exploration test passes (no dedicated exploration test for Bug 2 — verify via unit test)
    - Write unit test: `_FeedTab` with `_selectedTempleId = 'birla_mandir_hyderabad'` shows only posts with matching `templeId`
    - **EXPECTED OUTCOME**: Test PASSES after fix
    - _Requirements: 2.2.2_

  - [x] 4.5 Verify preservation tests still pass
    - **Property 2: Preservation** - All Temples Feed Unchanged
    - Re-run the SAME test from task 2.2
    - **EXPECTED OUTCOME**: Test PASSES (no regressions for "All Temples" default)

- [x] 5. Fix Bug 3 — Layout overflow issues

  - [x] 5.1 Fix `lib/screens/temple_detail_screen.dart` — festival list row (line ~307)
    - Wrap `Text(e.name)` in `Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis))`
    - Replace `const Spacer()` with `const SizedBox(width: 8)` (Spacer is redundant once Expanded is used)
    - _Bug_Condition: `screenWidth < 360` and festival name `Text` has no `Expanded` wrapper_
    - _Expected_Behavior: long festival names are ellipsized; no `RenderFlex` overflow_
    - _Preservation: visual appearance on screens >= 360 dp is unchanged_
    - _Requirements: 3.1.3, 3.2.3, 3.3.1, 3.3.2_

  - [x] 5.2 Fix `lib/screens/route_planner_screen.dart` — `_buildStatisticsRow` (line ~851)
    - Remove `mainAxisAlignment: MainAxisAlignment.spaceEvenly` from the `Row`
    - Wrap each `_buildStatCard(...)` call in `Expanded(child: _buildStatCard(...))`
    - _Bug_Condition: `screenWidth < 360` and `_buildStatCard` columns have no width constraint_
    - _Expected_Behavior: statistics row distributes space evenly on all screen widths_
    - _Preservation: visual appearance on screens >= 360 dp is unchanged_
    - _Requirements: 3.1.5, 3.2.5, 3.3.1_

  - [x] 5.3 Verify `_PostCard` author row is already fixed (no change needed)
    - Confirm `community_screen.dart` line ~168 already has `Expanded(child: Column(...))` wrapping the author name + role badge column
    - Document as confirmed — no code change required
    - _Requirements: 3.1.1, 3.2.1_

  - [x] 5.4 Verify bug condition exploration test passes (no dedicated exploration test for Bug 3 — verify via widget test)
    - Write widget test: render `TempleDetailScreen` festival row and `_buildStatisticsRow` at 320 dp width; assert no `RenderFlex` overflow errors
    - **EXPECTED OUTCOME**: Tests PASS after fix
    - _Requirements: 3.2.3, 3.2.5_

  - [x] 5.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Standard-Width Layout Unchanged
    - Re-run the SAME test from task 2 (standard-width rendering)
    - **EXPECTED OUTCOME**: Test PASSES (no regressions on >= 360 dp screens)

- [x] 6. Fix Bug 4 — Itinerary arrival time drift

  - [x] 6.1 Fix `_createDailyPlans` in `lib/services/itinerary_generator.dart`
    - In the `for` loop, change the `_calculateArrivalTime` call from passing `dailyDuration` to passing `travelTime`
    - Before: `final arrivalTime = _calculateArrivalTime(previousArrivalTime, dailyDuration);`
    - After: `final arrivalTime = _calculateArrivalTime(previousArrivalTime, travelTime);`
    - Note: `travelTime` is already computed above as `Duration(minutes: estimateTravelTime(travelDistance).toInt())` and is `Duration.zero` for `i == 0`
    - The `dailyDuration` accumulator is unchanged — it still tracks total day elapsed for the `> 10 hours` warning
    - _Bug_Condition: `day.visits.length > 1` and `visits[i].arrivalTime != departureTime[i-1] + travelTime[i]`_
    - _Expected_Behavior: `arrivalTime[i] == _calculateArrivalTime(visits[i-1].departureTime, travelTime[i])` for all `i >= 1`_
    - _Preservation: single-temple days are unaffected (`travelTime == Duration.zero` for `i == 0`)_
    - _Requirements: 4.1.1, 4.1.2, 4.2.1, 4.2.2, 4.3.1_

  - [x] 6.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Monotonically Correct Arrival Times
    - Re-run the SAME test from task 1.2 — do NOT write a new test
    - **EXPECTED OUTCOME**: `visits[1].arrivalTime == '08:50 AM'` (08:30 depart + 20 min travel) — Test PASSES
    - _Requirements: 4.2.1, 4.2.2, 4.2.4_

  - [x] 6.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Single-Temple Day Timing Unchanged
    - Re-run the SAME test from task 2.3
    - **EXPECTED OUTCOME**: Test PASSES (single-temple days unaffected)

- [x] 7. Fix Bug 5 — Dynamic rerouting GPS bypass and threshold drift

  - [x] 7.1 Fix Bug 5a — add `_checkRouteDeviation()` call in `_updateUserPosition` in `lib/screens/route_planner_screen.dart`
    - After the `setState` block in `_updateUserPosition`, add a call to `_checkRouteDeviation()`
    - The existing `_isReRoutingInProgress` guard inside `_checkRouteDeviation` already prevents concurrent reroutes
    - _Bug_Condition: GPS position update received, `_isReRoutingInProgress == false`, but `_checkRouteDeviation` is never called_
    - _Expected_Behavior: every GPS update triggers a deviation check when not already rerouting_
    - _Preservation: `_isReRoutingInProgress == true` guard continues to skip redundant checks_
    - _Requirements: 5.1.3, 5.2.1, 5.3.4_

  - [x] 7.2 Fix Bug 5b — remove `_lastCheckedPosition` update from early-return branch in `_checkRouteDeviation`
    - Remove the line `_lastCheckedPosition = _currentUserPosition;` from inside the `if (movement < 0.05) { ... return; }` block
    - Keep the `_lastCheckedPosition = _currentUserPosition;` line that appears AFTER the early-return block (after the full check)
    - _Bug_Condition: `movement < 0.05` early-return taken, `_lastCheckedPosition` updated, cumulative movement >= 0.05 km never detected_
    - _Expected_Behavior: `_lastCheckedPosition` is only updated after a full deviation check completes_
    - _Preservation: `_lastCheckedPosition` is still updated correctly after a full check_
    - _Requirements: 5.1.4, 5.2.2_

  - [x] 7.3 Verify bug condition exploration tests now pass
    - **Property 1: Expected Behavior** - GPS Updates Trigger Deviation Check / Threshold Measured from Last Full Check
    - Re-run the SAME tests from tasks 1.3 — do NOT write new tests
    - **EXPECTED OUTCOME**: Both tests PASS (confirms both Bug 5a and 5b are fixed)
    - _Requirements: 5.2.1, 5.2.2_

  - [x] 7.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Rerouting Guard Unchanged
    - Re-run the SAME test from task 2.4
    - **EXPECTED OUTCOME**: Test PASSES (no regressions in concurrent-reroute prevention)

- [x] 8. Checkpoint — Ensure all tests pass
  - Run the full test suite: `flutter test`
  - Verify all exploration tests pass (bugs are fixed)
  - Verify all preservation tests pass (no regressions)
  - Verify no new `RenderFlex` overflow errors on 320 dp device
  - Ask the user if any questions arise
