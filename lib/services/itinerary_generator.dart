// Itinerary generator service with date, budget, and time constraints
import 'dart:math';
import '../models/temple_model.dart';
import '../utils/distance_calculator.dart';
/// Darshan style affects how long the user spends at each temple
enum DarshanStyle { quick, standard, full }

/// Constraints for itinerary generation
class ItineraryConstraints {
  final DateTime? startDate;
  final DateTime? endDate;
  final double? maxBudget;
  final int? maxDays;
  final int? maxTemplesPerDay;
  final String? travelMode;

  // New inputs
  final int startHour;    // Hour component of daily start time (0-23)
  final int startMinute;  // Minute component of daily start time
  final DarshanStyle darshanStyle;    // Quick / Standard / Full puja
  final bool avoidHighways;           // Prefer scenic/local roads
  final String? accommodationAddress; // Where user stays (affects day-start point)
  final int groupSize;                // Affects crowd warnings
  final AccommodationPref accommodation;
  final int numberOfNights;
  final double foodBudgetPerDay;
  final double miscBudgetPerDay;
  final double fuelPricePerLiter;

  const ItineraryConstraints({
    this.startDate,
    this.endDate,
    this.maxBudget,
    this.maxDays,
    this.maxTemplesPerDay = 3,
    this.travelMode = 'Car',
    this.startHour = 6,
    this.startMinute = 0,
    this.darshanStyle = DarshanStyle.standard,
    this.avoidHighways = false,
    this.accommodationAddress,
    this.groupSize = 1,
    this.accommodation = AccommodationPref.budget,
    this.numberOfNights = 0,
    this.foodBudgetPerDay = 500,
    this.miscBudgetPerDay = 200,
    this.fuelPricePerLiter = 100,
  });

  /// Darshan duration in minutes based on style and temple rating
  int darshanMinutes(double? rating) {
    final base = switch (darshanStyle) {
      DarshanStyle.quick => 20,
      DarshanStyle.standard => (rating != null && rating > 4.5) ? 60 : 30,
      DarshanStyle.full => (rating != null && rating > 4.5) ? 120 : 90,
    };
    return base;
  }

  /// Average travel speed km/h for the selected mode
  double get speedKmh => switch (travelMode) {
    'Car' => avoidHighways ? 30.0 : 40.0,
    'Bike' => avoidHighways ? 25.0 : 35.0,
    'Bus' => 25.0,
    'Train' => 60.0,
    _ => 40.0,
  };
}

enum AccommodationPref { none, budget, midRange, luxury }

/// Generated itinerary result
class GeneratedItinerary {
  final List<DayPlan> dayPlans;
  final double totalDistance;
  final Duration totalDuration;
  final double estimatedCost;
  final List<String> warnings;

  GeneratedItinerary({
    required this.dayPlans,
    required this.totalDistance,
    required this.totalDuration,
    required this.estimatedCost,
    this.warnings = const [],
  });
}

/// Daily plan with temples to visit
class DayPlan {
  final int dayNumber;
  final DateTime date;
  final List<TempleVisit> visits;
  final double dailyDistance;
  final Duration dailyDuration;
  final double dailyCost;

  DayPlan({
    required this.dayNumber,
    required this.date,
    required this.visits,
    required this.dailyDistance,
    required this.dailyDuration,
    required this.dailyCost,
  });
}

/// Single temple visit in the itinerary
class TempleVisit {
  final Temple temple;
  final int order;
  final String arrivalTime;
  final String departureTime;
  final Duration darshanDuration;
  final double travelDistance;
  final Duration travelTime;
  final double estimatedCost;

  TempleVisit({
    required this.temple,
    required this.order,
    required this.arrivalTime,
    required this.departureTime,
    required this.darshanDuration,
    required this.travelDistance,
    required this.travelTime,
    required this.estimatedCost,
  });
}

/// Main itinerary generator class
class ItineraryGenerator {
  final List<Temple> availableTemples;
  final ItineraryConstraints constraints;

  ItineraryGenerator({
    required this.availableTemples,
    this.constraints = const ItineraryConstraints(),
  });

  GeneratedItinerary generate() {
    final List<String> warnings = [];

    final validTemples = _filterByConstraints(warnings);

    if (validTemples.isEmpty) {
      warnings.add('No temples match the selected criteria');
      return GeneratedItinerary(
        dayPlans: [],
        totalDistance: 0,
        totalDuration: Duration.zero,
        estimatedCost: 0,
        warnings: warnings,
      );
    }

    final orderedTemples = _optimizeRoute(validTemples);
    final dayPlans = _createDailyPlans(orderedTemples, warnings);

    final totalDistance = dayPlans.fold<double>(0, (s, d) => s + d.dailyDistance);
    final totalDuration = dayPlans.fold<Duration>(Duration.zero, (s, d) => s + d.dailyDuration);
    final estimatedCost = dayPlans.fold<double>(0, (s, d) => s + d.dailyCost);

    // Budget check
    if (constraints.maxBudget != null && constraints.maxBudget! > 0) {
      final tripCost = estimatedCost + _accommodationCost() + _travelCost(totalDistance);
      if (tripCost > constraints.maxBudget!) {
        warnings.add(
          'Estimated total ₹${tripCost.toStringAsFixed(0)} exceeds your budget of ₹${constraints.maxBudget!.toStringAsFixed(0)}',
        );
      }
    }

    // Group size crowd warning
    if (constraints.groupSize > 10) {
      warnings.add('Large group (${constraints.groupSize} people) — expect longer queues at popular temples');
    }

    return GeneratedItinerary(
      dayPlans: dayPlans,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      estimatedCost: estimatedCost,
      warnings: warnings,
    );
  }

  List<Temple> _filterByConstraints(List<String> warnings) {
    List<Temple> filtered = List<Temple>.from(availableTemples);

    if (constraints.maxDays != null && constraints.maxTemplesPerDay != null) {
      final maxTotal = constraints.maxDays! * constraints.maxTemplesPerDay!;
      if (filtered.length > maxTotal) {
        warnings.add('Limited to $maxTotal temples based on available days');
        filtered = filtered.take(maxTotal).toList();
      }
    }

    return filtered;
  }

  List<Temple> _optimizeRoute(List<Temple> temples) {
    if (temples.length <= 2) return temples;
    final ordered = _nearestNeighborOrder(temples);
    return _twoOptImprovement(ordered);
  }

  /// Nearest-neighbor TSP starting from the geographically first temple
  /// (no hardcoded Birla Mandir dependency)
  List<Temple> _nearestNeighborOrder(List<Temple> temples) {
    final unvisited = List<Temple>.from(temples);
    final route = <Temple>[];

    // Start from the westernmost temple (lowest longitude) as a neutral anchor
    unvisited.sort((a, b) => a.longitude.compareTo(b.longitude));
    Temple current = unvisited.removeAt(0);
    route.add(current);

    while (unvisited.isNotEmpty) {
      final nearest = _findNearest(current, unvisited);
      unvisited.remove(nearest);
      route.add(nearest);
      current = nearest;
    }

    return route;
  }

  Temple _findNearest(Temple current, List<Temple> candidates) {
    Temple nearest = candidates.first;
    double minDist = double.infinity;
    for (final c in candidates) {
      final d = _dist(current, c);
      if (d < minDist) { minDist = d; nearest = c; }
    }
    return nearest;
  }

  double _dist(Temple a, Temple b) =>
      calculateDistance(a.latitude, a.longitude, b.latitude, b.longitude);

  List<Temple> _twoOptImprovement(List<Temple> route) {
    if (route.length < 4) return route;
    final improved = List<Temple>.from(route);
    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = 1; i < improved.length - 2; i++) {
        for (int j = i + 2; j < improved.length; j++) {
          final before = _dist(improved[i - 1], improved[i]) + _dist(improved[j - 1], improved[j]);
          final after = _dist(improved[i - 1], improved[j - 1]) + _dist(improved[i], improved[j]);
          if (after < before) {
            improved.replaceRange(i, j, improved.sublist(i, j).reversed.toList());
            changed = true;
          }
        }
      }
    }
    return improved;
  }

  List<DayPlan> _createDailyPlans(List<Temple> temples, List<String> warnings) {
    final dayPlans = <DayPlan>[];
    final templesPerDay = constraints.maxTemplesPerDay ?? 3;
    final days = (temples.length / templesPerDay).ceil();
    DateTime currentDate = constraints.startDate ?? DateTime.now();

    for (int day = 0; day < days; day++) {
      final start = day * templesPerDay;
      final end = min(start + templesPerDay, temples.length);
      final dayTemples = temples.sublist(start, end);
      if (dayTemples.isEmpty) break;

      final visits = <TempleVisit>[];
      double dailyDistance = 0;
      Duration dailyDuration = Duration.zero;
      double dailyCost = 0;

      // Day start time from user preference
      String previousDepartureTime = _formatTime(
        constraints.startHour,
        constraints.startMinute,
      );

      for (int i = 0; i < dayTemples.length; i++) {
        final temple = dayTemples[i];

        double travelDistance = 0;
        Duration travelTime = Duration.zero;

        if (i > 0) {
          travelDistance = _dist(dayTemples[i - 1], temple);
          final travelMinutes = (travelDistance / constraints.speedKmh) * 60;
          travelTime = Duration(minutes: travelMinutes.ceil());
          dailyDistance += travelDistance;
        }

        final arrivalTime = _addMinutes(previousDepartureTime, travelTime.inMinutes);
        final darshanMins = constraints.darshanMinutes(temple.rating);
        final darshanDuration = Duration(minutes: darshanMins);
        final departureTime = _addMinutes(arrivalTime, darshanMins);

        final visitCost = _estimateVisitCost(temple);
        dailyCost += visitCost;
        dailyDuration += travelTime + darshanDuration;

        visits.add(TempleVisit(
          temple: temple,
          order: i + 1,
          arrivalTime: arrivalTime,
          departureTime: departureTime,
          darshanDuration: darshanDuration,
          travelDistance: travelDistance,
          travelTime: travelTime,
          estimatedCost: visitCost,
        ));

        previousDepartureTime = departureTime;
      }

      if (dailyDuration.inHours > 10) {
        warnings.add('Day ${day + 1} is quite full (${dailyDuration.inHours}h ${dailyDuration.inMinutes.remainder(60)}m) — consider reducing temples per day');
      }

      dayPlans.add(DayPlan(
        dayNumber: day + 1,
        date: currentDate,
        visits: visits,
        dailyDistance: dailyDistance,
        dailyDuration: dailyDuration,
        dailyCost: dailyCost,
      ));

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dayPlans;
  }

  /// Format hour/minute as "HH:MM AM/PM"
  String _formatTime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Add minutes to a "HH:MM AM/PM" string
  String _addMinutes(String time, int minutes) {
    final parts = time.split(' ');
    final tp = parts[0].split(':');
    int h = int.parse(tp[0]);
    int m = int.parse(tp[1]);
    if (parts[1] == 'PM' && h != 12) h += 12;
    if (parts[1] == 'AM' && h == 12) h = 0;
    final total = h * 60 + m + minutes;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return _formatTime(nh, nm);
  }

  double _estimateVisitCost(Temple temple) {
    // Base: prasadam + offerings estimate
    double cost = 150;
    if (temple.rating != null && temple.rating! > 4.5) cost += 100;
    // Scale by group size
    cost *= max(1, constraints.groupSize * 0.7); // group discount factor
    return cost;
  }

  double _accommodationCost() {
    final perNight = switch (constraints.accommodation) {
      AccommodationPref.none => 0.0,
      AccommodationPref.budget => 600.0,
      AccommodationPref.midRange => 1500.0,
      AccommodationPref.luxury => 5000.0,
    };
    return perNight * constraints.numberOfNights;
  }

  double _travelCost(double distanceKm) {
    return switch (constraints.travelMode) {
      'Car' => (distanceKm / 15) * constraints.fuelPricePerLiter,
      'Bike' => (distanceKm / 50) * constraints.fuelPricePerLiter,
      'Bus' => distanceKm * 2.0,
      _ => (distanceKm / 15) * constraints.fuelPricePerLiter,
    };
  }

  double estimateTravelTime(double distanceKm) =>
      (distanceKm / constraints.speedKmh) * 60;
}
