// Unit Tests: ItineraryExportService
// Tasks 9.1 – 9.2

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra_app/models/smart_itinerary.dart';
import 'package:yatra_app/models/temple_model.dart';
import 'package:yatra_app/services/budget_service.dart';
import 'package:yatra_app/services/itinerary_export_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Temple _makeTemple(String id, String name, double lat, double lng) {
  return Temple(
    id: id,
    name: name,
    placeId: 'place_$id',
    latitude: lat,
    longitude: lng,
    address: '',
    distinctiveFeatures: '',
    festivals: '',
    prasadamInfo: '',
    darshanTimings: '',
    estimatedVisitDurationMinutes: 45,
  );
}

ItineraryRequest _makeRequest(List<Temple> temples, {int numberOfDays = 1}) {
  return ItineraryRequest(
    temples: temples,
    startDate: DateTime(2025, 6, 1),
    numberOfDays: numberOfDays,
    maxBudget: 0,
    travelMode: VehicleType.car,
    startTime: const TimeOfDay(hour: 8, minute: 0),
    maxTemplesPerDay: 3,
  );
}

SmartTempleVisit _makeVisit(Temple temple, int order, DateTime base) {
  final arrival = base.add(Duration(hours: order * 2));
  final departure = arrival.add(const Duration(minutes: 45));
  return SmartTempleVisit(
    temple: temple,
    order: order,
    arrivalTime: arrival,
    departureTime: departure,
    visitDuration: const Duration(minutes: 45),
    travelDistanceKm: order == 0 ? 0.0 : 5.0,
    travelDuration: const Duration(minutes: 15),
    travelCost: order == 0 ? 0.0 : 50.0,
  );
}

const _zeroCost = CostSummary(
  transport: 0,
  stay: 0,
  food: 0,
  templeSpecific: 0,
  misc: 0,
  total: 0,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 9.1 buildPdf returns non-empty Uint8List for a minimal single-day itinerary
  // -------------------------------------------------------------------------
  test('9.1 buildPdf returns non-empty Uint8List for a single-day itinerary', () async {
    final temple = _makeTemple('t1', 'Temple One', 17.4000, 78.4000);
    final date = DateTime(2025, 6, 1);

    final visit = _makeVisit(temple, 0, date.add(const Duration(hours: 8)));

    final day = SmartDayPlan(
      dayNumber: 1,
      date: date,
      visits: [visit],
      dayDistanceKm: 0.0,
      dayDuration: const Duration(minutes: 45),
      dayCost: const DayCost(transport: 0, food: 0, templeSpecific: 0, total: 0),
    );

    final itinerary = SmartItinerary(
      request: _makeRequest([temple]),
      days: [day],
      totalCost: _zeroCost,
      totalDistanceKm: 0.0,
      totalDuration: const Duration(minutes: 45),
      warnings: [],
      generatedAt: DateTime(2025, 6, 1),
    );

    final result = await ItineraryExportService().buildPdf(itinerary);

    expect(result, isA<Uint8List>());
    expect(result.isNotEmpty, isTrue,
        reason: 'PDF bytes must not be empty for a single-day itinerary');
  });

  // -------------------------------------------------------------------------
  // 9.2 buildPdf returns non-empty Uint8List for a multi-day itinerary
  // -------------------------------------------------------------------------
  test('9.2 buildPdf returns non-empty Uint8List for a multi-day itinerary', () async {
    final t1 = _makeTemple('t1', 'Temple One', 17.4000, 78.4000);
    final t2 = _makeTemple('t2', 'Temple Two', 17.4010, 78.4010);
    final t3 = _makeTemple('t3', 'Temple Three', 17.4020, 78.4020);
    final t4 = _makeTemple('t4', 'Temple Four', 17.4030, 78.4030);

    final day1Date = DateTime(2025, 6, 1);
    final day2Date = DateTime(2025, 6, 2);

    final day1 = SmartDayPlan(
      dayNumber: 1,
      date: day1Date,
      visits: [
        _makeVisit(t1, 0, day1Date.add(const Duration(hours: 8))),
        _makeVisit(t2, 1, day1Date.add(const Duration(hours: 8))),
      ],
      dayDistanceKm: 5.0,
      dayDuration: const Duration(hours: 3),
      dayCost: const DayCost(transport: 50, food: 200, templeSpecific: 0, total: 250),
    );

    final day2 = SmartDayPlan(
      dayNumber: 2,
      date: day2Date,
      visits: [
        _makeVisit(t3, 0, day2Date.add(const Duration(hours: 8))),
        _makeVisit(t4, 1, day2Date.add(const Duration(hours: 8))),
      ],
      dayDistanceKm: 5.0,
      dayDuration: const Duration(hours: 3),
      dayCost: const DayCost(transport: 50, food: 200, templeSpecific: 0, total: 250),
    );

    final itinerary = SmartItinerary(
      request: _makeRequest([t1, t2, t3, t4], numberOfDays: 2),
      days: [day1, day2],
      totalCost: const CostSummary(
        transport: 100,
        stay: 500,
        food: 400,
        templeSpecific: 0,
        misc: 50,
        total: 1050,
      ),
      totalDistanceKm: 10.0,
      totalDuration: const Duration(hours: 6),
      warnings: [],
      generatedAt: DateTime(2025, 6, 1),
    );

    final result = await ItineraryExportService().buildPdf(itinerary);

    expect(result, isA<Uint8List>());
    expect(result.isNotEmpty, isTrue,
        reason: 'PDF bytes must not be empty for a multi-day itinerary');
  });
}
