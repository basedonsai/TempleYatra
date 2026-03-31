import 'package:flutter/material.dart';
import 'temple_model.dart';
import '../services/budget_service.dart';

/// Request object carrying all user inputs for itinerary generation.
class ItineraryRequest {
  final List<Temple> temples;
  final DateTime startDate;
  final int numberOfDays; // 1–14
  final double maxBudget; // ₹; 0 = no limit
  final VehicleType travelMode;
  final List<String> optionalStops;
  final TimeOfDay startTime; // default 08:00
  final int maxTemplesPerDay; // default 3

  ItineraryRequest({
    required this.temples,
    required this.startDate,
    required this.numberOfDays,
    required this.maxBudget,
    required this.travelMode,
    List<String>? optionalStops,
    TimeOfDay? startTime,
    int? maxTemplesPerDay,
  })  : optionalStops = optionalStops ?? const [],
        startTime = startTime ?? const TimeOfDay(hour: 8, minute: 0),
        maxTemplesPerDay = maxTemplesPerDay ?? 3 {
    if (temples.isEmpty) {
      throw ArgumentError('temples must not be empty');
    }
    if (numberOfDays < 1 || numberOfDays > 14) {
      throw ArgumentError('numberOfDays must be between 1 and 14, got $numberOfDays');
    }
    if (maxBudget < 0) {
      throw ArgumentError('maxBudget must be >= 0, got $maxBudget');
    }
  }
}

/// Cost breakdown for a single day.
class DayCost {
  final double transport;
  final double food;
  final double templeSpecific;
  final double total;

  const DayCost({
    required this.transport,
    required this.food,
    required this.templeSpecific,
    required this.total,
  });
}

/// Full cost summary for the entire trip.
class CostSummary {
  final double transport;
  final double stay;
  final double food;
  final double templeSpecific;
  final double misc;
  final double total;

  const CostSummary({
    required this.transport,
    required this.stay,
    required this.food,
    required this.templeSpecific,
    required this.misc,
    required this.total,
  });

  /// Returns true when total is within the given budget (0 = no limit).
  bool isWithinBudget(double maxBudget) =>
      maxBudget <= 0 || total <= maxBudget;
}

/// A single temple visit within a day plan.
class SmartTempleVisit {
  final Temple temple;
  final int order;
  final DateTime arrivalTime;
  final DateTime departureTime;
  final Duration visitDuration;
  final double travelDistanceKm;
  final Duration travelDuration;
  final double travelCost;

  const SmartTempleVisit({
    required this.temple,
    required this.order,
    required this.arrivalTime,
    required this.departureTime,
    required this.visitDuration,
    required this.travelDistanceKm,
    required this.travelDuration,
    required this.travelCost,
  });
}

/// A single day within the generated itinerary.
class SmartDayPlan {
  final int dayNumber;
  final DateTime date;
  final List<SmartTempleVisit> visits;
  final double dayDistanceKm;
  final Duration dayDuration;
  final DayCost dayCost;

  const SmartDayPlan({
    required this.dayNumber,
    required this.date,
    required this.visits,
    required this.dayDistanceKm,
    required this.dayDuration,
    required this.dayCost,
  });
}

/// The fully generated itinerary returned by SmartSchedulerService.
class SmartItinerary {
  final ItineraryRequest request;
  final List<SmartDayPlan> days;
  final CostSummary totalCost;
  final double totalDistanceKm;
  final Duration totalDuration;
  final List<String> warnings;
  final DateTime generatedAt;

  const SmartItinerary({
    required this.request,
    required this.days,
    required this.totalCost,
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.warnings,
    required this.generatedAt,
  });
}
