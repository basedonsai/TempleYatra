# Design Document: Festival Calendar & Crowd Indicator

## Overview

This feature adds structured festival data and deterministic crowd-level indicators to the Temple Yatra app. It is purely additive — no existing models, screens, or providers are modified in breaking ways. New components slot into the existing Riverpod + Flutter architecture as a self-contained module.

The core data flow is:

```
Festival_Data_Source (mock list)
        ↓
  festivalProvider (Riverpod)
        ↓
  CrowdEngine.compute(templeId, date, events) → CrowdLevel
        ↓
  CrowdBadge widget (green / amber / red)
        ↓
  Existing screens (TempleCard, DetailScreen, PlannerScreen, RouteScreen)
```

All computation is synchronous and in-memory. No network calls are introduced.

---

## Architecture

The feature follows the existing layered pattern in the app:

```
lib/
├── models/
│   └── festival_event.dart       # FestivalEvent + CrowdLevel enum
├── data/
│   └── festival_data.dart        # Mock List<FestivalEvent> for all 10 temples
├── services/
│   └── crowd_engine.dart         # Pure CrowdLevel computation function
├── providers/
│   └── festival_provider.dart    # Riverpod provider exposing festival data
├── widgets/
│   └── crowd_badge.dart          # Reusable CrowdBadge widget (full + compact)
└── screens/
    └── temple_calendar_screen.dart  # New screen: per-temple festival list
```

Existing screens receive minimal, localized edits — no structural changes.

### Dependency Graph

```
festival_event.dart
      ↑
festival_data.dart ──→ festival_provider.dart
      ↑                        ↑
crowd_engine.dart         (consumed by)
      ↑                        ↑
crowd_badge.dart ←─────────────┘
      ↑
temple_list_screen.dart
temple_detail_screen.dart
temple_calendar_screen.dart
yatra_planner_screen.dart
route_planner_screen.dart
```

`CrowdEngine` has zero Flutter dependencies — it only imports `festival_event.dart`.

---

## Components and Interfaces

### `lib/models/festival_event.dart`

```dart
enum CrowdLevel { low, moderate, high }

class FestivalEvent {
  final String templeId;
  final String name;
  final DateTime date;
  final CrowdLevel crowdHint;

  const FestivalEvent({
    required this.templeId,
    required this.name,
    required this.date,
    required this.crowdHint,
  });
}
```

`crowdHint` is the pre-computed hint stored with the event (always `high` for festival days). The `CrowdEngine` recomputes dynamically for any query date.

---

### `lib/services/crowd_engine.dart`

Public API — a single top-level function:

```dart
CrowdLevel computeCrowdLevel(
  String templeId,
  DateTime queryDate,
  List<FestivalEvent> events,
)
```

No class, no state, no Flutter imports.

---

### `lib/data/festival_data.dart`

```dart
// Returns all festival events for all temples.
final List<FestivalEvent> allFestivalEvents = [ ... ];

// Convenience: events for a single temple, sorted by date.
List<FestivalEvent> festivalEventsForTemple(String templeId) { ... }
```

---

### `lib/providers/festival_provider.dart`

```dart
// Synchronous provider — data is already in memory.
final festivalProvider = Provider<List<FestivalEvent>>((ref) => allFestivalEvents);

// Derived provider: events for a specific temple.
final templeFestivalsProvider = Provider.family<List<FestivalEvent>, String>(
  (ref, templeId) => ref.watch(festivalProvider)
      .where((e) => e.templeId == templeId)
      .toList()
      ..sort((a, b) => a.date.compareTo(b.date)),
);
```

Widgets consume `templeFestivalsProvider(temple.id)` and call `computeCrowdLevel` inline.

---

### `lib/widgets/crowd_badge.dart`

Two rendering modes controlled by a `compact` flag:

| Mode | Visual | Use case |
|------|--------|----------|
| `compact: false` (default) | 8px dot + label text | TempleCard, DetailScreen, CalendarScreen |
| `compact: true` | 8px dot only, no text | RoutePlannerScreen 100px cards |

```dart
class CrowdBadge extends StatelessWidget {
  final CrowdLevel level;
  final bool compact;   // default: false

  const CrowdBadge({super.key, required this.level, this.compact = false});
}
```

Color mapping (deterministic, total function):

| CrowdLevel | Color | Label |
|------------|-------|-------|
| `low` | `Colors.green` | "Low Crowd" |
| `moderate` | `Colors.amber` | "Moderate" |
| `high` | `Colors.red` | "High Crowd" |

Full badge layout: `Row [ dot (8px circle) | SizedBox(4) | Text(label) ]`  
Compact badge: `dot (8px circle)` only, wrapped in a `Tooltip` with the label for accessibility.

---

### `lib/screens/temple_calendar_screen.dart`

```dart
class TempleCalendarScreen extends StatelessWidget {
  final Temple temple;
  const TempleCalendarScreen({super.key, required this.temple});
}
```

Consumed via `ConsumerWidget` to watch `templeFestivalsProvider(temple.id)`.

---

## Data Models

### `FestivalEvent`

| Field | Type | Notes |
|-------|------|-------|
| `templeId` | `String` | Must match a `Temple.id` in `allTemples` |
| `name` | `String` | English festival name |
| `date` | `DateTime` | Concrete date, no nulls; time component ignored |
| `crowdHint` | `CrowdLevel` | Always `high` for festival entries in mock data |

### `CrowdLevel`

```dart
enum CrowdLevel { low, moderate, high }
```

Exactly three values. Ordinal order (`low < moderate < high`) is used for monotonicity checks.

---

## CrowdEngine Algorithm

```
function computeCrowdLevel(templeId, queryDate, events):
  // Normalize queryDate to midnight (date-only comparison)
  qDay = DateOnly(queryDate)

  // Filter to this temple's events
  templeEvents = events.where(e => e.templeId == templeId)

  // Rule 1 — Festival Day (highest priority)
  for each event in templeEvents:
    if DateOnly(event.date) == qDay:
      return CrowdLevel.high

  // Rule 2 — Festival Proximity (±1 or ±2 calendar days)
  for each event in templeEvents:
    diff = abs(DateOnly(event.date).daysSince(qDay))
    if diff <= 2:
      return CrowdLevel.moderate

  // Rule 3 — Weekend
  if queryDate.weekday in {Friday=5, Saturday=6, Sunday=7}:
    return CrowdLevel.moderate

  // Rule 4 — Default
  return CrowdLevel.low
```

**Date-only comparison**: strip time by using `DateTime(y, m, d)` before diffing.  
**Day difference**: `(a.difference(b)).inDays.abs()` where both are midnight-normalized.  
**Priority**: rules are evaluated top-to-bottom; first match wins. A festival day that also falls on a weekend returns `high`, not `moderate`.

---

## Riverpod Provider Design

Both providers are synchronous `Provider` (not `AsyncNotifierProvider`) because all data is in-memory.

```
festivalProvider          → List<FestivalEvent>  (all temples)
templeFestivalsProvider   → List<FestivalEvent>  (per temple, sorted)
```

### Widget consumption pattern

```dart
// In a ConsumerWidget build():
final events = ref.watch(templeFestivalsProvider(temple.id));
final level = computeCrowdLevel(temple.id, DateTime.now(), events);
return CrowdBadge(level: level);
```

### Testability via provider override

```dart
// In widget tests:
ProviderScope(
  overrides: [
    festivalProvider.overrideWithValue(mockEvents),
  ],
  child: MyWidget(),
)
```

---

## CrowdBadge Widget Spec

### Props

```dart
CrowdBadge({
  required CrowdLevel level,
  bool compact = false,
})
```

### Full badge (compact: false)

```
[ ●  Low Crowd  ]   ← green dot + text, Row, no background
[ ●  Moderate   ]   ← amber dot + text
[ ●  High Crowd ]   ← red dot + text
```

Rendered as a `Row` with `mainAxisSize: MainAxisSize.min`. No container/card background — callers wrap as needed.

### Compact badge (compact: true)

```
[ ● ]   ← 8px circle, Tooltip wraps it
```

Used in the 100px-wide route planner cards. The `Tooltip` message is the full label for accessibility.

### Color constants (defined once in `crowd_badge.dart`)

```dart
static const _colors = {
  CrowdLevel.low:      Colors.green,
  CrowdLevel.moderate: Colors.amber,
  CrowdLevel.high:     Colors.red,
};
static const _labels = {
  CrowdLevel.low:      'Low Crowd',
  CrowdLevel.moderate: 'Moderate',
  CrowdLevel.high:     'High Crowd',
};
```

---

## TempleCalendarScreen Layout

```
AppBar
  title: "{temple.name} — Festivals"
  leading: back arrow

Body: ListView.builder over upcoming events (date >= today, sorted asc)

Each list item:
  ListTile (or custom Row)
  ├── leading: CrowdBadge(level, compact: false)
  ├── title: Text(event.name)
  ├── subtitle: Text(DateFormat('d MMM yyyy').format(event.date))
  └── tileColor: today-highlight color if event.date == today

Empty state:
  Center → Text("No upcoming festivals scheduled.")
```

**Today highlight**: `tileColor: Colors.orange.shade50` when `DateOnly(event.date) == DateOnly(DateTime.now())`.

**Date formatting**: `DateFormat('d MMM yyyy', 'en')` from the `intl` package (already in `pubspec.yaml`).

---

## Integration Spec for Existing Screens

### 1. `lib/screens/temple_list_screen.dart` — `_TempleCard`

Change: add `CrowdBadge` to the existing `Stack` in the image area.

```dart
// Existing Stack children:
//   Center(child: temple icon)
//   Positioned(top:12, right:12, child: rating badge)   ← unchanged

// ADD:
Positioned(
  top: 12,
  left: 12,
  child: Consumer(
    builder: (context, ref, _) {
      final events = ref.watch(templeFestivalsProvider(temple.id));
      final level = computeCrowdLevel(temple.id, DateTime.now(), events);
      return CrowdBadge(level: level);
    },
  ),
),
```

`_TempleCard` becomes a `ConsumerWidget` (or wraps the badge in a `Consumer`). The rating badge at `top:12, right:12` is untouched.

---

### 2. `lib/screens/temple_detail_screen.dart`

Two additions, both inside the existing `Padding > Column`:

**A. Crowd status row** — inserted before the "About" section:

```dart
// ADD before _buildSection('About', ...):
Consumer(builder: (context, ref, _) {
  final events = ref.watch(templeFestivalsProvider(temple.id));
  final level = computeCrowdLevel(temple.id, DateTime.now(), events);
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      CrowdBadge(level: level),
      const SizedBox(width: 8),
      Text(_crowdLabel(level)),   // "Currently Low Crowd" etc.
    ]),
  );
}),
```

**B. Festivals section** — replace the existing `_buildSection('Festivals', ...)` children with:

```dart
_buildSection(
  title: 'Festivals',
  icon: Icons.celebration,
  children: [
    // Existing free-text (unchanged)
    Text(temple.festivals, ...),
    const SizedBox(height: 10),
    // NEW: next 3 upcoming events
    Consumer(builder: (context, ref, _) {
      final events = ref.watch(templeFestivalsProvider(temple.id));
      final upcoming = events
          .where((e) => !e.date.isBefore(DateTime.now()))
          .take(3)
          .toList();
      if (upcoming.isEmpty) {
        return const Text('No upcoming festivals in the next year.');
      }
      return Column(
        children: upcoming.map((e) => Row(children: [
          CrowdBadge(level: computeCrowdLevel(temple.id, e.date, events)),
          const SizedBox(width: 8),
          Text(e.name),
          const Spacer(),
          Text(DateFormat('d MMM yyyy').format(e.date)),
        ])).toList(),
      );
    }),
    const SizedBox(height: 10),
    // NEW: View Festival Calendar button
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TempleCalendarScreen(temple: temple),
        )),
        icon: const Icon(Icons.calendar_month, size: 18),
        label: const Text('View Festival Calendar'),
      ),
    ),
  ],
),
```

All existing sections (About, Darshan Timings, action buttons, FAB) remain in place.

---

### 3. `lib/screens/yatra_planner_screen.dart`

Change: replace `avatar: Icon(Icons.temple_hindu)` in the `FilterChip` with a `CrowdBadge` dot.

The screen must become a `ConsumerStatefulWidget` (it is already a `StatefulWidget`).

```dart
// Replace the FilterChip avatar:
avatar: Consumer(builder: (context, ref, _) {
  final events = ref.watch(templeFestivalsProvider(temple.id));
  final level = computeCrowdLevel(
    temple.id,
    _startDate ?? DateTime.now(),
    events,
  );
  return CrowdBadge(level: level, compact: true);
}),
```

`FilterChip` selection behavior (`onSelected`, `selected`, `selectedColor`, `checkmarkColor`) is unchanged. The `Consumer` only wraps the `avatar` slot.

When `_startDate` changes (inside `setState`), Riverpod re-evaluates `computeCrowdLevel` on the next build automatically because `_startDate` is read at build time.

---

### 4. `lib/screens/route_planner_screen.dart`

Change: add a compact crowd dot below the temple name in the 100px-wide horizontal list cards.

```dart
// Inside the existing Column(mainAxisAlignment: MainAxisAlignment.center) children:
Text('${index + 1}', ...),
const SizedBox(height: 4),
Text(temple.name, maxLines: 2, ...),
// ADD:
const SizedBox(height: 4),
Consumer(builder: (context, ref, _) {
  final events = ref.watch(templeFestivalsProvider(temple.id));
  final date = widget.itinerary?.startDate ?? DateTime.now();
  final level = computeCrowdLevel(temple.id, date, events);
  return CrowdBadge(level: level, compact: true);
}),
if (index <= _currentWaypointIndex)
  Icon(Icons.check_circle, color: Colors.green, size: 12),
```

No changes to route calculation, map rendering, or budget logic.

---

## Data Spec — Sample Festival Events

```dart
// lib/data/festival_data.dart (excerpt)
final List<FestivalEvent> allFestivalEvents = [

  // Chilkur Balaji
  FestivalEvent(
    templeId: 'chilkur_balaji',
    name: 'Brahmotsavam',
    date: DateTime(2026, 2, 14),
    crowdHint: CrowdLevel.high,
  ),
  FestivalEvent(
    templeId: 'chilkur_balaji',
    name: 'Vaikunta Ekadasi',
    date: DateTime(2026, 1, 2),
    crowdHint: CrowdLevel.high,
  ),
  FestivalEvent(
    templeId: 'chilkur_balaji',
    name: 'Sri Rama Navami',
    date: DateTime(2026, 3, 28),
    crowdHint: CrowdLevel.high,
  ),

  // Jagannath Temple Hyderabad
  FestivalEvent(
    templeId: 'jagannath_hyderabad',
    name: 'Rath Yatra',
    date: DateTime(2026, 6, 24),
    crowdHint: CrowdLevel.high,
  ),
  FestivalEvent(
    templeId: 'jagannath_hyderabad',
    name: 'Snana Purnima',
    date: DateTime(2026, 6, 11),
    crowdHint: CrowdLevel.high,
  ),
  FestivalEvent(
    templeId: 'jagannath_hyderabad',
    name: 'Diwali Puja',
    date: DateTime(2026, 10, 20),
    crowdHint: CrowdLevel.high,
  ),

  // Peddamma Thalli
  FestivalEvent(
    templeId: 'peddamma_thalli',
    name: 'Bonalu Festival',
    date: DateTime(2026, 7, 19),
    crowdHint: CrowdLevel.high,
  ),
  FestivalEvent(
    templeId: 'peddamma_thalli',
    name: 'Navratri',
    date: DateTime(2026, 10, 2),
    crowdHint: CrowdLevel.high,
  ),

  // ... (similar entries for all 10 temples)
];
```

Each temple has at least 2 entries. All dates are concrete `DateTime(year, month, day)` values. `crowdHint` is always `CrowdLevel.high` in the mock data (festival days are inherently high-crowd).

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: CrowdLevel Exhaustiveness and Purity

*For any* `templeId` (String), `queryDate` (DateTime), and `events` (List\<FestivalEvent\>), `computeCrowdLevel(templeId, queryDate, events)` shall return a value in `{CrowdLevel.low, CrowdLevel.moderate, CrowdLevel.high}` and calling it twice with the same arguments shall return the same value.

**Validates: Requirements 2.1, 2.6, NFR 2.2**

---

### Property 2: Festival-Day Dominance

*For any* `FestivalEvent` `f` and any list of additional events, `computeCrowdLevel(f.templeId, f.date, [f, ...extras])` shall return `CrowdLevel.high`. Adding more events to the list shall not lower the result below `high`.

**Validates: Requirements 2.2, 2.8**

---

### Property 3: Empty-List Baseline

*For any* `templeId` and `queryDate`, `computeCrowdLevel(templeId, queryDate, [])` shall equal `CrowdLevel.low`.

**Validates: Requirements 2.7**

---

### Property 4: Festival Proximity Yields At Least Moderate

*For any* `FestivalEvent` `f` and offset `d` in `{-2, -1, 1, 2}`, `computeCrowdLevel(f.templeId, f.date.add(Duration(days: d)), [f])` shall return at least `CrowdLevel.moderate` (i.e., not `CrowdLevel.low`).

**Validates: Requirements 2.3**

---

### Property 5: Weekend Yields Moderate When No Festival Nearby

*For any* date `d` whose weekday is Friday, Saturday, or Sunday, and an empty festival list, `computeCrowdLevel(anyTempleId, d, [])` shall return `CrowdLevel.moderate`.

**Validates: Requirements 2.4**

---

### Property 6: Non-Festival Weekday Yields Low

*For any* date `d` whose weekday is Monday through Thursday, and an empty festival list, `computeCrowdLevel(anyTempleId, d, [])` shall return `CrowdLevel.low`.

**Validates: Requirements 2.5**

---

### Property 7: CrowdBadge Content Correctness

*For any* `CrowdLevel` value, rendering `CrowdBadge(level: level)` shall produce a widget tree that contains exactly one colored dot matching the level's color and, when `compact` is false, a text label matching the level's label string. No two distinct `CrowdLevel` values shall produce the same color.

**Validates: Requirements 3.2, 3.3, NFR 2.1**

---

### Property 8: Upcoming Festival Sort Order

*For any* temple, the list of upcoming festivals derived from `templeFestivalsProvider` shall be sorted in ascending order by date — for any two adjacent events `a` and `b`, `a.date.isBefore(b.date) || a.date.isAtSameMomentAs(b.date)` shall hold.

**Validates: Requirements 4.3, 5.1**

---

### Property 9: FestivalEvent Date Immutability

*For any* `DateTime` value `d`, constructing `FestivalEvent(templeId: t, name: n, date: d, crowdHint: h)` and reading back `.date` shall return a value equal to `d` (same year, month, day).

**Validates: Requirements 1.3**

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| Temple has no festival events | `computeCrowdLevel` returns `low`; calendar screen shows empty-state message |
| All events are in the past | Calendar screen shows "No upcoming festivals scheduled." |
| `queryDate` is in the past | `computeCrowdLevel` computes normally — no error thrown |
| Two events on the same date | Both trigger `high`; deduplication not required |
| `allTemples` is empty in tests | `allFestivalEvents` returns empty list; no crash |
| `itinerary.startDate` is null in RoutePlannerScreen | Falls back to `DateTime.now()` |

---

## Testing Strategy

### Unit Tests — `test/crowd_engine_test.dart`

Uses `package:test` (already available in Flutter projects). No widget tree needed.

Tests cover Properties 1–6 and 9:

- **P1** — Call `computeCrowdLevel` with arbitrary inputs; assert result is a valid `CrowdLevel` and two calls return equal results.
- **P2** — Construct a `FestivalEvent` for a known date; assert `computeCrowdLevel` on that exact date returns `high` regardless of extra events.
- **P3** — Assert `computeCrowdLevel(anyId, anyDate, []) == CrowdLevel.low` for a range of dates.
- **P4** — For offsets `[-2, -1, 1, 2]`, assert result is not `low`.
- **P5** — For Friday/Saturday/Sunday with empty list, assert `moderate`.
- **P6** — For Monday–Thursday with empty list, assert `low`.
- **P9** — Construct `FestivalEvent` with a known date; assert `.date` equals the input.

Each test runs with multiple concrete inputs (at minimum 5 representative cases per property). Property-based testing is done with `package:test` parameterized cases; a PBT library such as `package:glados` may be added if desired but is not required for Phase 1.

### Widget Smoke Tests — `test/crowd_badge_test.dart`

Uses `flutter_test`. Tests cover Property 7 and basic rendering:

- Render `CrowdBadge(level: CrowdLevel.low)` — assert green dot and "Low Crowd" text found.
- Render `CrowdBadge(level: CrowdLevel.moderate)` — assert amber dot and "Moderate" text found.
- Render `CrowdBadge(level: CrowdLevel.high)` — assert red dot and "High Crowd" text found.
- Render `CrowdBadge(level: CrowdLevel.low, compact: true)` — assert no text widget, dot present.
- Render inside a `ProviderScope` with overridden `festivalProvider` — assert badge renders without error.

### Test Configuration

Each property-based test must include a comment referencing the design property:

```dart
// Feature: festival-calendar-crowd-indicator, Property 2: Festival-Day Dominance
test('festival day always returns high', () { ... });
```

Minimum 5 concrete cases per property in Phase 1. If `package:glados` is added, configure `Glados` with at least 100 iterations per property.
