import '../models/festival_event.dart';

/// Computes the crowd level for a given temple on a given date,
/// based on festival events. Rules are evaluated in priority order;
/// the first match wins.
CrowdLevel computeCrowdLevel(
  String templeId,
  DateTime queryDate,
  List<FestivalEvent> events,
) {
  // Normalize queryDate to midnight for date-only comparison
  final qDay = DateTime(queryDate.year, queryDate.month, queryDate.day);

  // Filter events to this temple only
  final templeEvents = events.where((e) => e.templeId == templeId);

  // Rule 1 — Festival Day (highest priority)
  for (final event in templeEvents) {
    final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
    if (eventDay == qDay) {
      return CrowdLevel.high;
    }
  }

  // Rule 2 — Festival Proximity (±1 or ±2 calendar days)
  for (final event in templeEvents) {
    final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
    if ((eventDay.difference(qDay)).inDays.abs() <= 2) {
      return CrowdLevel.moderate;
    }
  }

  // Rule 3 — Weekend (Friday=5, Saturday=6, Sunday=7)
  if (queryDate.weekday >= 5) {
    return CrowdLevel.moderate;
  }

  // Rule 4 — Default
  return CrowdLevel.low;
}
