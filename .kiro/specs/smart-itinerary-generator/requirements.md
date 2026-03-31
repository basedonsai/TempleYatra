# Requirements Document: Smart Itinerary Generator

## Introduction

The Smart Itinerary Generator allows users of the Temple Yatra app to convert a set of
selected temples into a structured, day-by-day travel plan. The feature accepts travel date,
start time, budget, number of days, selected temples, travel mode, and optional stops;
optimizes the route; allocates temples across days; estimates costs; and produces a
downloadable PDF itinerary. It is Feature 1 from the product spec and builds on the
stabilized routing foundation completed in the bugfix spec.

---

## Glossary

- **Itinerary**: A day-by-day travel plan covering selected temples, timings, and cost estimates.
- **Day Plan**: A single day within an itinerary, containing one or more temple visits.
- **Temple Visit**: A scheduled stop at a temple, with arrival time, departure time, and cost.
- **Travel Mode**: The mode of transport chosen by the user (Car, Bike, or Bus).
- **Optional Stops**: Free-text notes the user may add to describe additional stops or preferences.
- **Cost Summary**: An itemized breakdown of transport, accommodation, food, temple-specific, and miscellaneous costs.
- **Budget Warning**: A notice shown to the user when estimated costs exceed the stated maximum budget.
- **Omission Warning**: A notice shown to the user when not all selected temples can fit within the requested number of days.

---

## Requirements

### Requirement 1: Itinerary Input Collection

**User Story:** As a user, I want to provide my travel preferences so that the app can
generate a personalized itinerary for my temple visit.

#### Acceptance Criteria

1. WHEN the user initiates itinerary generation from the route planning screen THEN the
   system SHALL navigate to an input screen with the currently selected temples pre-loaded.

2. WHEN the input screen is displayed THEN the system SHALL present the following fields:
   travel start date (date picker), trip start time (time picker, default 08:00 AM),
   number of days (stepper, 1–14), maximum budget in ₹ (numeric field), travel mode
   (Car / Bike / Bus selector), and optional stops (free-text field).

3. WHEN the user submits the form with a start date in the past THEN the system SHALL
   display an inline validation error and SHALL NOT proceed to generation.

4. WHEN the user submits the form with zero temples selected THEN the system SHALL display
   an error message and SHALL NOT proceed to generation.

5. WHEN the user submits a valid form THEN the system SHALL begin itinerary generation and
   show a loading indicator.

---

### Requirement 2: Route Optimization

**User Story:** As a user, I want my temples ordered in an efficient travel sequence so
that I minimize unnecessary backtracking.

#### Acceptance Criteria

1. WHEN generating an itinerary THEN the system SHALL order temples using the app's
   existing west-to-east route optimization without altering that logic.

2. WHEN the optimized order is determined THEN the system SHALL use that order as the
   canonical sequence for day allocation; no temple SHALL be reordered after this step.

3. WHEN the temple list contains only one temple THEN the system SHALL skip route
   optimization and produce a single-temple, single-day itinerary.

---

### Requirement 3: Day Allocation

**User Story:** As a user, I want my temples distributed sensibly across my available
days so that each day is manageable and not overloaded.

#### Acceptance Criteria

1. WHEN allocating temples to days THEN the system SHALL place at most 3 temples per day
   by default.

2. WHEN allocating temples to days THEN the system SHALL ensure no single day exceeds
   10 hours of combined visit and travel time.

3. WHEN the total number of temples cannot all fit within the requested number of days
   THEN the system SHALL warn the user BEFORE generation proceeds, listing which temples
   will be omitted, and give the user the opportunity to adjust their inputs before
   continuing.

4. WHEN the number of days exceeds the number of temples THEN the system SHALL produce
   one day per temple and SHALL NOT create empty day plans.

5. WHEN a temple has no recorded visit duration THEN the system SHALL default to 45
   minutes for that temple's visit duration.

---

### Requirement 4: Time Scheduling

**User Story:** As a user, I want each temple visit to have a realistic arrival and
departure time so that I can follow the itinerary on the day of travel.

#### Acceptance Criteria

1. WHEN computing visit timings THEN the system SHALL start each day at the trip start
   time provided by the user (default 08:00 AM).

2. WHEN computing visit timings THEN the system SHALL set each temple's arrival time to
   the previous temple's departure time plus the estimated travel duration between them.

3. WHEN computing visit timings THEN the system SHALL guarantee that for every visit,
   arrival time is before departure time.

4. WHEN computing visit timings THEN the system SHALL guarantee that for every pair of
   consecutive visits within a day, the earlier visit's departure time is no later than
   the next visit's arrival time.

5. WHEN estimating travel duration between two temples THEN the system SHALL use the
   straight-line distance and the average speed for the selected travel mode
   (Car: 40 km/h, Bike: 35 km/h, Bus: 25 km/h).

---

### Requirement 5: Cost Estimation

**User Story:** As a user, I want an itemized cost estimate for my trip so that I can
plan my finances before travelling.

#### Acceptance Criteria

1. WHEN estimating costs THEN the system SHALL compute transport cost based on distance
   and the selected travel mode using the app's existing cost calculation logic.

2. WHEN estimating costs THEN the system SHALL compute accommodation cost as
   (number of days − 1) × the nightly rate for the chosen accommodation tier
   (Budget: ₹500, Mid-Range: ₹1500, Luxury: ₹5000).

3. WHEN estimating costs THEN the system SHALL compute food cost as number of days × ₹500
   per day as a default.

4. WHEN estimating costs THEN the system SHALL compute a temple-specific cost estimate
   (prasadam, entry, offerings) of ₹150 per temple visit as a default.

5. WHEN estimating costs THEN the system SHALL compute a miscellaneous cost of ₹200 per day.

6. WHEN the total estimated cost exceeds the user's stated maximum budget and the maximum
   budget is greater than zero THEN the system SHALL add a budget warning to the itinerary
   listing the overage amount.

7. WHEN the user sets maximum budget to zero THEN the system SHALL treat it as no budget
   limit and SHALL NOT emit a budget warning.

---

### Requirement 6: Itinerary Preview

**User Story:** As a user, I want to review my generated itinerary before exporting it
so that I can verify the plan meets my needs.

#### Acceptance Criteria

1. WHEN the itinerary is generated successfully THEN the system SHALL display the full
   day-by-day plan to the user.

2. WHEN displaying a day plan THEN the system SHALL show for each temple visit: temple
   name, arrival time, departure time, visit duration, travel distance from the previous
   stop, and estimated cost for that leg.

3. WHEN displaying the itinerary THEN the system SHALL show a cost summary with itemized
   breakdown: transport, accommodation, food, temple-specific, miscellaneous, and total.

4. WHEN the itinerary contains warnings THEN the system SHALL display them in a visible
   warning banner at the top of the preview.

5. WHEN the user chooses to return to the route planning screen THEN the system SHALL
   navigate back without losing the existing route state.

---

### Requirement 7: PDF Export

**User Story:** As a user, I want to export my itinerary as a PDF so that I can save or
share it for use during my trip.

#### Acceptance Criteria

1. WHEN the user requests PDF export from the itinerary preview THEN the system SHALL
   generate a PDF document of the itinerary.

2. WHEN building the PDF THEN the system SHALL include: a header with the app name and
   trip title, one section per day with all visit details, and a cost summary section.

3. WHEN the PDF is built successfully THEN the system SHALL present the native share sheet
   so the user can save or share the file.

4. WHEN the share sheet is unavailable THEN the system SHALL save the PDF to a
   platform-appropriate location accessible to the user and SHALL show a confirmation
   message displaying the saved file name.

5. WHEN PDF generation fails THEN the system SHALL show an error message "Export failed.
   Please try again." and SHALL NOT crash.

6. WHEN building the PDF THEN the system SHALL NOT include any user personally identifiable
   information beyond what the user explicitly entered in the optional stops field.

---

### Requirement 8: Architecture and Integration Constraints

**User Story:** As a developer, I want the new feature to integrate cleanly with the
existing app so that no currently working screens or flows are broken.

#### Acceptance Criteria

1. WHEN the feature is added THEN the system SHALL NOT alter the behavior of any existing
   working screens (map, route planner, home, temple list, temple detail, yatra planner,
   chatbot, community, simulation, storytelling).

2. WHEN the feature is added THEN the system SHALL reuse the app's existing routing,
   budget, and itinerary generation logic without breaking their current behavior.

3. WHEN the feature manages state THEN the system SHALL use the same state management
   pattern already established in the app, ensuring consistency with existing providers.

4. WHEN the new itinerary entry point is added THEN it SHALL be reachable from the route
   planning screen via a new "Generate Itinerary" action; no changes to the main
   navigation structure are required.

---

### Requirement 9: Testing Coverage

**User Story:** As a developer, I want the feature's core behaviors covered by automated
tests so that regressions are caught early.

#### Acceptance Criteria

1. WHEN the feature is implemented THEN the scheduling logic SHALL be covered by unit
   tests for: single-temple input, multi-temple single-day allocation, multi-day
   allocation, budget warning emission, and timing monotonicity.

2. WHEN the feature is implemented THEN the PDF export logic SHALL be covered by unit
   tests verifying that a non-empty document is produced for both minimal and multi-day
   itineraries.

3. WHEN the feature is implemented THEN property-based tests SHALL verify the following
   for all generated itineraries: day count does not exceed the requested number of days,
   visit timings are monotonically increasing, total cost equals the sum of its components,
   no temple appears in more than one day, and no day contains more than the maximum
   allowed temples.

4. WHEN the feature is implemented THEN all existing automated tests in the project SHALL
   continue to pass without modification.
