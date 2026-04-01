import 'package:flutter_test/flutter_test.dart';
import '../lib/models/festival_event.dart';
import '../lib/services/crowd_engine.dart';

void main() {
  // Feature: festival-calendar-crowd-indicator, Property 1: CrowdLevel Exhaustiveness and Purity
  group('P1 — Exhaustiveness and Purity', () {
    final validLevels = CrowdLevel.values.toSet();

    final inputs = [
      ('chilkur_balaji', DateTime(2026, 2, 14), <FestivalEvent>[]),
      ('jagannath_hyderabad', DateTime(2026, 6, 24), [
        FestivalEvent(
          templeId: 'jagannath_hyderabad',
          name: 'Rath Yatra',
          date: DateTime(2026, 6, 24),
          crowdHint: CrowdLevel.high,
        ),
      ]),
      ('peddamma_thalli', DateTime(2025, 3, 10), <FestivalEvent>[]),
      ('birla_mandir_hyderabad', DateTime(2026, 8, 16), [
        FestivalEvent(
          templeId: 'birla_mandir_hyderabad',
          name: 'Janmashtami',
          date: DateTime(2026, 8, 16),
          crowdHint: CrowdLevel.high,
        ),
      ]),
      ('srisailam', DateTime(2026, 9, 5), [
        FestivalEvent(
          templeId: 'srisailam',
          name: 'Brahmotsavam',
          date: DateTime(2026, 9, 5),
          crowdHint: CrowdLevel.high,
        ),
      ]),
    ];

    test('result is always a valid CrowdLevel (never null)', () {
      for (final (templeId, date, events) in inputs) {
        final result = computeCrowdLevel(templeId, date, events);
        expect(validLevels.contains(result), isTrue,
            reason: 'Expected a valid CrowdLevel for $templeId on $date');
      }
    });

    test('calling twice with same args returns equal results (purity)', () {
      for (final (templeId, date, events) in inputs) {
        final first = computeCrowdLevel(templeId, date, events);
        final second = computeCrowdLevel(templeId, date, events);
        expect(first, equals(second),
            reason: 'Expected same result for $templeId on $date');
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 2: Festival-Day Dominance
  group('P2 — Festival-Day Dominance', () {
    final festivals = [
      FestivalEvent(
        templeId: 'chilkur_balaji',
        name: 'Brahmotsavam',
        date: DateTime(2026, 2, 14),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'jagannath_hyderabad',
        name: 'Rath Yatra',
        date: DateTime(2026, 6, 24),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'peddamma_thalli',
        name: 'Bonalu Festival',
        date: DateTime(2026, 7, 19),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'birla_mandir_hyderabad',
        name: 'Janmashtami',
        date: DateTime(2026, 8, 16),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'srisailam',
        name: 'Mahashivaratri',
        date: DateTime(2026, 2, 26),
        crowdHint: CrowdLevel.high,
      ),
    ];

    test('festival day always returns high', () {
      for (final f in festivals) {
        final result = computeCrowdLevel(f.templeId, f.date, [f]);
        expect(result, equals(CrowdLevel.high),
            reason: 'Expected high for ${f.name} on ${f.date}');
      }
    });

    test('adding extra unrelated events does not lower result below high', () {
      final extra = FestivalEvent(
        templeId: 'other_temple',
        name: 'Some Other Festival',
        date: DateTime(2025, 1, 1),
        crowdHint: CrowdLevel.high,
      );
      for (final f in festivals) {
        final result = computeCrowdLevel(f.templeId, f.date, [f, extra]);
        expect(result, equals(CrowdLevel.high),
            reason: 'Extra events should not lower result for ${f.name}');
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 3: Empty-List Baseline
  group('P3 — Empty-List Baseline', () {
    final pairs = [
      ('chilkur_balaji', DateTime(2026, 4, 15)),
      ('jagannath_hyderabad', DateTime(2026, 3, 10)),
      ('peddamma_thalli', DateTime(2026, 5, 20)),
      ('birla_mandir_hyderabad', DateTime(2026, 11, 3)),
      ('srisailam', DateTime(2026, 12, 1)),
    ];

    test('empty event list always returns low', () {
      for (final (templeId, date) in pairs) {
        // Use a Monday to avoid weekend rule
        final monday = _nearestMonday(date);
        final result = computeCrowdLevel(templeId, monday, []);
        expect(result, equals(CrowdLevel.low),
            reason: 'Expected low for $templeId on $monday with empty events');
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 4: Festival Proximity Yields At Least Moderate
  group('P4 — Festival Proximity Yields At Least Moderate', () {
    final baseFestivals = [
      FestivalEvent(
        templeId: 'chilkur_balaji',
        name: 'Brahmotsavam',
        date: DateTime(2026, 2, 14),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'jagannath_hyderabad',
        name: 'Rath Yatra',
        date: DateTime(2026, 6, 24),
        crowdHint: CrowdLevel.high,
      ),
      FestivalEvent(
        templeId: 'peddamma_thalli',
        name: 'Bonalu Festival',
        date: DateTime(2026, 7, 19),
        crowdHint: CrowdLevel.high,
      ),
    ];

    test('offsets [-2, -1, 1, 2] from festival date yield at least moderate', () {
      for (final f in baseFestivals) {
        for (final offset in [-2, -1, 1, 2]) {
          final queryDate = f.date.add(Duration(days: offset));
          final result = computeCrowdLevel(f.templeId, queryDate, [f]);
          expect(result, isNot(equals(CrowdLevel.low)),
              reason:
                  'Expected at least moderate for ${f.name} at offset $offset (date: $queryDate)');
        }
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 5: Weekend Yields Moderate
  group('P5 — Weekend Yields Moderate', () {
    // Known Fridays, Saturdays, Sundays (weekday 5, 6, 7)
    final weekendDates = [
      DateTime(2026, 1, 2),  // Friday
      DateTime(2026, 1, 3),  // Saturday
      DateTime(2026, 1, 4),  // Sunday
      DateTime(2026, 3, 6),  // Friday
      DateTime(2026, 3, 7),  // Saturday
      DateTime(2026, 3, 8),  // Sunday
    ];

    test('Friday/Saturday/Sunday with empty event list returns moderate', () {
      for (final date in weekendDates) {
        expect(date.weekday, greaterThanOrEqualTo(5),
            reason: '$date should be a weekend day');
        final result = computeCrowdLevel('any_temple', date, []);
        expect(result, equals(CrowdLevel.moderate),
            reason: 'Expected moderate for weekend date $date (weekday ${date.weekday})');
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 6: Non-Festival Weekday Yields Low
  group('P6 — Non-Festival Weekday Yields Low', () {
    // Known Mondays through Thursdays (weekday 1–4)
    final weekdayDates = [
      DateTime(2026, 1, 5),   // Monday
      DateTime(2026, 1, 6),   // Tuesday
      DateTime(2026, 1, 7),   // Wednesday
      DateTime(2026, 1, 8),   // Thursday
      DateTime(2026, 3, 9),   // Monday
      DateTime(2026, 3, 10),  // Tuesday
    ];

    test('Monday–Thursday with empty event list returns low', () {
      for (final date in weekdayDates) {
        expect(date.weekday, lessThanOrEqualTo(4),
            reason: '$date should be a weekday (Mon–Thu)');
        final result = computeCrowdLevel('any_temple', date, []);
        expect(result, equals(CrowdLevel.low),
            reason: 'Expected low for weekday $date (weekday ${date.weekday})');
      }
    });
  });

  // Feature: festival-calendar-crowd-indicator, Property 9: FestivalEvent Date Immutability
  group('P9 — FestivalEvent Date Immutability', () {
    final dates = [
      DateTime(2026, 1, 2),
      DateTime(2026, 6, 24),
      DateTime(2026, 10, 20),
      DateTime(2025, 12, 31),
      DateTime(2027, 3, 15),
    ];

    test('FestivalEvent.date equals the input DateTime (year, month, day)', () {
      for (final d in dates) {
        final event = FestivalEvent(
          templeId: 'test_temple',
          name: 'Test Festival',
          date: d,
          crowdHint: CrowdLevel.high,
        );
        expect(event.date.year, equals(d.year));
        expect(event.date.month, equals(d.month));
        expect(event.date.day, equals(d.day));
      }
    });
  });
}

/// Returns the nearest Monday on or after [date] to avoid weekend rule interference.
DateTime _nearestMonday(DateTime date) {
  var d = date;
  while (d.weekday > 4) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
