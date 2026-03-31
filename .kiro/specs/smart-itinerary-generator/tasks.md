# Tasks: Smart Itinerary Generator

## Task List

- [x] 1. Data Models
  - [x] 1.1 Create `lib/models/smart_itinerary.dart` with `ItineraryRequest`, `SmartItinerary`, `SmartDayPlan`, `SmartTempleVisit`, `CostSummary`, `DayCost`
  - [x] 1.2 Validate `ItineraryRequest` fields: temples non-empty, numberOfDays in [1,14], maxBudget >= 0

- [x] 2. SmartSchedulerService
  - [x] 2.1 Create `lib/services/smart_scheduler_service.dart` with `generate(ItineraryRequest)` entry point
  - [x] 2.2 Implement `_allocateDays`: delegate ordering to `RoutingEngine.optimizeRoute`, split temples into days respecting `maxTemplesPerDay` and 10-hour cap
  - [x] 2.3 Implement `_computeTimings`: set `arrivalTime` / `departureTime` per visit using Haversine travel duration; enforce monotonicity postconditions
  - [x] 2.4 Implement `_estimateCosts`: delegate transport to `BudgetService`, compute stay/food/temple-specific/misc; emit budget warning when total > maxBudget

- [x] 3. Riverpod Provider
  - [x] 3.1 Create `lib/providers/itinerary_provider.dart` with `ItineraryNotifier extends AsyncNotifier<SmartItinerary?>` and `generate(ItineraryRequest)` / `reset()` methods

- [x] 4. ItineraryInputScreen
  - [x] 4.1 Create `lib/screens/itinerary_input_screen.dart` with date picker, days stepper, budget field, travel mode selector, optional stops field
  - [x] 4.2 Add inline validation: past date error, zero temples error
  - [x] 4.3 Wire "Generate" button to `itineraryProvider.notifier.generate(request)` and show loading indicator

- [x] 5. ItineraryPreviewScreen
  - [x] 5.1 Create `lib/screens/itinerary_preview_screen.dart` with day-by-day scrollable list showing per-visit details (temple name, arrival/departure, distance, cost)
  - [x] 5.2 Add cost summary card with itemized breakdown (transport, stay, food, temple-specific, misc, total)
  - [x] 5.3 Show warnings banner when `itinerary.warnings.isNotEmpty`
  - [x] 5.4 Add "Back to Route Planner" navigation action

- [x] 6. ItineraryExportService
  - [x] 6.1 Add `pdf` and `share_plus` to `pubspec.yaml`
  - [x] 6.2 Create `lib/services/itinerary_export_service.dart` with `buildPdf(SmartItinerary)` returning `Future<Uint8List>`
  - [x] 6.3 Implement PDF layout: header (app name, trip title, date range), one section per day, cost summary footer
  - [x] 6.4 Implement `shareAsPdf(SmartItinerary)` using `share_plus`; fall back to `saveToFile` when share sheet unavailable
  - [x] 6.5 Wire "Export PDF" FAB on `ItineraryPreviewScreen` to `ItineraryExportService`; handle errors with SnackBar

- [x] 7. Integration: RoutePlannerScreen Entry Point
  - [x] 7.1 Add "Generate Itinerary" button to `RoutePlannerScreen` action bar that navigates to `ItineraryInputScreen(selectedTemples: _optimizedRoute)`
  - [x] 7.2 Verify no existing `RoutePlannerScreen` behavior is changed (all existing tests still pass)

- [x] 8. Unit Tests: SmartSchedulerService
  - [x] 8.1 Test single temple → one day, one visit, zero travel distance
  - [x] 8.2 Test three temples, one day → all in day 1, timings monotonically increasing
  - [x] 8.3 Test six temples, two days, maxTemplesPerDay=3 → two days of three each
  - [x] 8.4 Test budget exceeded → `warnings.isNotEmpty`
  - [x] 8.5 Test `maxBudget == 0` → no budget warning emitted
  - [x] 8.6 Test temple with null `estimatedVisitDurationMinutes` → defaults to 45 min
  - [x] 8.7 Test `numberOfDays > temples.length` → `days.length == temples.length`, no empty days

- [x] 9. Unit Tests: ItineraryExportService
  - [x] 9.1 Test `buildPdf` returns non-empty `Uint8List` for a minimal single-day itinerary
  - [x] 9.2 Test `buildPdf` returns non-empty `Uint8List` for a multi-day itinerary

- [x] 10. Property-Based Tests: SmartSchedulerService
  - [x] 10.1 Property: `days.length <= request.numberOfDays` for any valid request with random temple counts and day counts
  - [x] 10.2 Property: all visit timings are monotonically increasing (`arrivalTime[i] < departureTime[i]` and `departureTime[i] <= arrivalTime[i+1]`)
  - [x] 10.3 Property: `totalCost.total == transport + stay + food + templeSpecific + misc` (cost additivity)
  - [x] 10.4 Property: no temple appears in more than one day (uniqueness across days)
  - [x] 10.5 Property: `visits.length <= maxTemplesPerDay` for every day in every generated itinerary

- [x] 11. Regression: Existing Tests
  - [x] 11.1 Run `flutter test test/preservation_property_test.dart` — all tests must pass
  - [x] 11.2 Run `flutter test test/bug_condition_exploration_test.dart` — all tests must pass
