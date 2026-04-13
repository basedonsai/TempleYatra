import 'dart:math';
import 'package:flutter/material.dart';
import '../models/smart_itinerary.dart';
import '../models/temple_model.dart';
import '../services/routing_engine.dart';
import '../services/budget_service.dart';

/// Core scheduling engine: allocates temples to days, computes timings, estimates costs.
class SmartSchedulerService {
  static const int _maxMinutesPerDay = 10 * 60; // 10-hour cap

  // Speed map (km/h) per vehicle type
  static const Map<VehicleType, double> _speedKmh = {
    VehicleType.car: 40.0,
    VehicleType.bike: 35.0,
    VehicleType.bus: 25.0,
  };

  // Accommodation rate per night (₹)
  static const Map<AccommodationType, double> _accommodationRate = {
    AccommodationType.budget: 500.0,
    AccommodationType.midRange: 1500.0,
    AccommodationType.luxury: 5000.0,
    AccommodationType.none: 0.0,
  };

  /// Entry point: generate a full SmartItinerary from the given request.
  SmartItinerary generate(ItineraryRequest request) {
    // Step 1: Optimise route order via RoutingEngine
    final engine = RoutingEngine(temples: request.temples);
    final orderedTemples = engine.optimizeRoute();

    // Step 2: Allocate temples to days
    final days = _allocateDays(orderedTemples, request);

    // Step 3: Compute per-visit timings
    for (final day in days) {
      _computeTimings(day, request.startTime, request.travelMode);
    }

    // Step 4: Estimate costs
    final warnings = <String>[];
    final costSummary = _estimateCosts(days, request, warnings);

    // Step 5: Aggregate totals
    final totalDistanceKm = days.fold<double>(
      0.0, (sum, d) => sum + d.dayDistanceKm);
    final totalDuration = days.fold<Duration>(
      Duration.zero, (sum, d) => sum + d.dayDuration);

    return SmartItinerary(
      request: request,
      days: days,
      totalCost: costSummary,
      totalDistanceKm: totalDistanceKm,
      totalDuration: totalDuration,
      warnings: warnings,
      generatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // _allocateDays
  // ---------------------------------------------------------------------------

  List<SmartDayPlan> _allocateDays(
      List<Temple> orderedTemples, ItineraryRequest request) {
    final days = <SmartDayPlan>[];
    var currentTemples = <Temple>[];
    var currentDayMinutes = 0.0;
    var dayIndex = 0;
    final maxTemplesPerDay = request.maxTemplesPerDay;

    for (int i = 0; i < orderedTemples.length; i++) {
      final temple = orderedTemples[i];
      final visitMinutes = (temple.estimatedVisitDurationMinutes ?? 45).toDouble();
      final prevTemple = currentTemples.isNotEmpty ? currentTemples.last : null;
      final travelMinutes = prevTemple != null
          ? _travelMinutes(prevTemple, temple, request.travelMode)
          : 0.0;
      final totalMinutes = visitMinutes + travelMinutes;

      // Flush current day if adding this temple would overflow
      if (currentTemples.isNotEmpty &&
          (currentTemples.length >= maxTemplesPerDay ||
              currentDayMinutes + totalMinutes > _maxMinutesPerDay)) {
        days.add(_buildDayPlan(dayIndex, currentTemples, request));
        dayIndex++;
        currentTemples = [];
        currentDayMinutes = 0.0;

        if (dayIndex >= request.numberOfDays) break;

        // First temple of new day has no travel cost
        currentTemples.add(temple);
        currentDayMinutes = visitMinutes;
        continue;
      }

      currentTemples.add(temple);
      currentDayMinutes += totalMinutes;
    }

    // Flush remaining temples
    if (currentTemples.isNotEmpty && dayIndex < request.numberOfDays) {
      days.add(_buildDayPlan(dayIndex, currentTemples, request));
    }

    return days;
  }

  /// Build a SmartDayPlan shell (visits without timings yet).
  SmartDayPlan _buildDayPlan(
      int dayIndex, List<Temple> temples, ItineraryRequest request) {
    final date = request.startDate.add(Duration(days: dayIndex));
    final visits = <SmartTempleVisit>[];
    var dayDistanceKm = 0.0;

    for (int i = 0; i < temples.length; i++) {
      final temple = temples[i];
      final distKm =
          i == 0 ? 0.0 : _haversineKm(temples[i - 1], temple);
      dayDistanceKm += distKm;
      final travelDur = _travelDuration(distKm, request.travelMode);
      final visitDur = Duration(
          minutes: temple.estimatedVisitDurationMinutes ?? 45);

      // Placeholder times — will be overwritten by _computeTimings
      final placeholder = DateTime(2000);
      visits.add(SmartTempleVisit(
        temple: temple,
        order: i,
        arrivalTime: placeholder,
        departureTime: placeholder,
        visitDuration: visitDur,
        travelDistanceKm: distKm,
        travelDuration: travelDur,
        travelCost: 0.0,
      ));
    }

    final dayDuration = visits.fold<Duration>(
        Duration.zero, (s, v) => s + v.visitDuration + v.travelDuration);

    return SmartDayPlan(
      dayNumber: dayIndex + 1,
      date: date,
      visits: visits,
      dayDistanceKm: dayDistanceKm,
      dayDuration: dayDuration,
      dayCost: const DayCost(
          transport: 0, food: 0, templeSpecific: 0, total: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // _computeTimings
  // ---------------------------------------------------------------------------

  void _computeTimings(
      SmartDayPlan day, TimeOfDay startTime, VehicleType travelMode) {
    var currentTime = DateTime(
      day.date.year,
      day.date.month,
      day.date.day,
      startTime.hour,
      startTime.minute,
    );

    for (int i = 0; i < day.visits.length; i++) {
      final visit = day.visits[i];

      // Travel from previous temple (or zero for first)
      final travelDur = i == 0 ? Duration.zero : visit.travelDuration;
      currentTime = currentTime.add(travelDur);

      final arrival = currentTime;
      final departure = arrival.add(visit.visitDuration);
      currentTime = departure;

      // Replace immutable visit with updated times
      day.visits[i] = SmartTempleVisit(
        temple: visit.temple,
        order: visit.order,
        arrivalTime: arrival,
        departureTime: departure,
        visitDuration: visit.visitDuration,
        travelDistanceKm: visit.travelDistanceKm,
        travelDuration: visit.travelDuration,
        travelCost: visit.travelCost,
      );
    }

    // Postcondition assertions (debug)
    assert(() {
      for (int i = 0; i < day.visits.length; i++) {
        final v = day.visits[i];
        assert(v.arrivalTime.isBefore(v.departureTime),
            'arrivalTime must be before departureTime at visit $i');
        if (i > 0) {
          assert(!day.visits[i - 1].departureTime.isAfter(v.arrivalTime),
              'departureTime[${i - 1}] must be <= arrivalTime[$i]');
        }
      }
      return true;
    }());
  }

  // ---------------------------------------------------------------------------
  // _estimateCosts
  // ---------------------------------------------------------------------------

  CostSummary _estimateCosts(
      List<SmartDayPlan> days, ItineraryRequest request, List<String> warnings) {
    var totalTransport = 0.0;
    var totalTempleSpecific = 0.0;

    for (int di = 0; di < days.length; di++) {
      final day = days[di];
      var dayTransport = 0.0;

      for (int vi = 0; vi < day.visits.length; vi++) {
        final visit = day.visits[vi];

        final legCost = _legTransportCost(
          visit.travelDistanceKm, request.travelMode,
          fuelPricePerLiter: request.fuelPricePerLiter,
        );
        dayTransport += legCost;
        totalTransport += legCost;

        // Temple-specific cost (prasadam / offerings estimate)
        const templeCost = 150.0;
        totalTempleSpecific += templeCost;

        day.visits[vi] = SmartTempleVisit(
          temple: visit.temple,
          order: visit.order,
          arrivalTime: visit.arrivalTime,
          departureTime: visit.departureTime,
          visitDuration: visit.visitDuration,
          travelDistanceKm: visit.travelDistanceKm,
          travelDuration: visit.travelDuration,
          travelCost: legCost,
        );
      }

      final dayFood = request.foodBudgetPerDay;
      final dayTempleSpecific = day.visits.length * 150.0;
      final dayTotal = dayTransport + dayFood + dayTempleSpecific;

      days[di] = SmartDayPlan(
        dayNumber: day.dayNumber,
        date: day.date,
        visits: day.visits,
        dayDistanceKm: day.dayDistanceKm,
        dayDuration: day.dayDuration,
        dayCost: DayCost(
          transport: dayTransport,
          food: dayFood,
          templeSpecific: dayTempleSpecific,
          total: dayTotal,
        ),
      );
    }

    // Accommodation: use request's accommodation type and nights
    final nights = request.numberOfNights.clamp(0, request.numberOfDays);
    final totalStay = nights * (_accommodationRate[request.accommodationType] ?? 500.0);

    final totalFood = request.foodBudgetPerDay * request.numberOfDays;
    final totalMisc = request.miscBudgetPerDay * request.numberOfDays;

    final total = totalTransport + totalStay + totalFood + totalTempleSpecific + totalMisc;

    if (request.maxBudget > 0 && total > request.maxBudget) {
      final excess = (total - request.maxBudget).toStringAsFixed(0);
      warnings.add('Estimated cost exceeds budget by ₹$excess');
    }

    return CostSummary(
      transport: totalTransport,
      stay: totalStay,
      food: totalFood,
      templeSpecific: totalTempleSpecific,
      misc: totalMisc,
      total: total,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Haversine distance in km between two temples.
  double _haversineKm(Temple a, Temple b) {
    return _haversineKmCoords(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  double _haversineKmCoords(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final a = sinDLat * sinDLat +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sinDLon * sinDLon;
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  /// Travel time in minutes between two temples.
  double _travelMinutes(Temple from, Temple to, VehicleType mode) {
    final distKm = _haversineKm(from, to);
    final speedKmh = _speedKmh[mode] ?? 40.0;
    return (distKm / speedKmh) * 60.0;
  }

  /// Travel duration between two temples.
  Duration _travelDuration(double distKm, VehicleType mode) {
    final speedKmh = _speedKmh[mode] ?? 40.0;
    final minutes = (distKm / speedKmh) * 60.0;
    return Duration(seconds: (minutes * 60).round());
  }

  /// Transport cost for a single leg (fuel or bus fare).
  double _legTransportCost(double distKm, VehicleType mode,
      {double fuelPricePerLiter = 100.0}) {
    if (distKm <= 0) return 0.0;
    switch (mode) {
      case VehicleType.car:
        return (distKm / 15.0) * fuelPricePerLiter;
      case VehicleType.bike:
        return (distKm / 50.0) * fuelPricePerLiter;
      case VehicleType.bus:
        return distKm * 1.5;
    }
  }
}
