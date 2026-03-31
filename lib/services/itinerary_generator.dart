// Itinerary generator service with date, budget, and time constraints
import 'dart:math';
import '../models/temple_model.dart';
import '../data/temples_data.dart';
import '../utils/distance_calculator.dart';

/// Constraints for itinerary generation
class ItineraryConstraints {
  final DateTime? startDate;
  final DateTime? endDate;
  final double? maxBudget;
  final int? maxDays;
  final int? maxTemplesPerDay;
  final String? travelMode;

  const ItineraryConstraints({
    this.startDate,
    this.endDate,
    this.maxBudget,
    this.maxDays,
    this.maxTemplesPerDay = 3,
    this.travelMode = 'Car',
  });
}

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

  /// Generate a complete itinerary based on constraints
  GeneratedItinerary generate() {
    final List<String> warnings = [];
    
    // Filter temples by constraints
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

    // Optimize route for the temples
    final orderedTemples = _optimizeRoute(validTemples);
    
    // Split into daily plans
    final dayPlans = _createDailyPlans(orderedTemples, warnings);
    
    // Calculate totals
    final totalDistance = dayPlans.fold<double>(
      0, 
      (sum, day) => sum + day.dailyDistance
    );
    final totalDuration = dayPlans.fold<Duration>(
      Duration.zero,
      (sum, day) => sum + day.dailyDuration,
    );
    final estimatedCost = dayPlans.fold<double>(
      0,
      (sum, day) => sum + day.dailyCost,
    );

    return GeneratedItinerary(
      dayPlans: dayPlans,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      estimatedCost: estimatedCost,
      warnings: warnings,
    );
  }

  /// Filter temples based on all constraints
  List<Temple> _filterByConstraints(List<String> warnings) {
    List<Temple> filtered = List<Temple>.from(availableTemples);

    // Filter by budget if set
    if (constraints.maxBudget != null && constraints.maxBudget! > 0) {
      final affordableTemples = filtered.where((t) {
        final cost = _estimateTempleCost(t);
        return cost <= constraints.maxBudget!;
      }).toList();
      
      if (affordableTemples.length < filtered.length) {
        warnings.add('${filtered.length - affordableTemples.length} temples excluded due to budget constraints');
      }
      filtered = affordableTemples;
    }

    // Filter by date availability if set
    if (constraints.startDate != null && constraints.endDate != null) {
      final availableTemples = filtered.where((t) {
        return _isTempleAvailable(t, constraints.startDate!, constraints.endDate!);
      }).toList();
      
      if (availableTemples.length < filtered.length) {
        warnings.add('${filtered.length - availableTemples.length} temples not available on selected dates');
      }
      filtered = availableTemples;
    }

    // Limit number of temples if max days is set
    if (constraints.maxDays != null && constraints.maxTemplesPerDay != null) {
      final maxTotalTemples = constraints.maxDays! * constraints.maxTemplesPerDay!;
      if (filtered.length > maxTotalTemples) {
        warnings.add('Limited to $maxTotalTemples temples based on available days');
        filtered = filtered.take(maxTotalTemples).toList();
      }
    }

    return filtered;
  }

  /// Check if temple is available during date range
  bool _isTempleAvailable(Temple temple, DateTime start, DateTime end) {
    // Check if temple has valid timings
    if (temple.darshanTimings.isEmpty) return true;
    
    // In a real app, this would check festival schedules, special events, etc.
    // For now, all temples are considered available
    return true;
  }

  /// Optimize route using TSP algorithm
  List<Temple> _optimizeRoute(List<Temple> temples) {
    if (temples.length <= 2) return temples;

    // Use nearest neighbor + 2-opt improvement
    final ordered = _nearestNeighborOrder(temples);
    return _twoOptImprovement(ordered);
  }

  /// Nearest neighbor algorithm for initial ordering
  List<Temple> _nearestNeighborOrder(List<Temple> temples) {
    final List<Temple> unvisited = List<Temple>.from(temples);
    final List<Temple> route = [];
    
    // Start with temple closest to Hyderabad center
    final origin = allTemples.firstWhere((t) => t.id == 'birla_mandir_hyderabad');
    Temple current = origin;
    
    while (unvisited.isNotEmpty) {
      unvisited.remove(current);
      if (!route.contains(current)) {
        route.add(current);
      }
      
      if (unvisited.isNotEmpty) {
        current = _findNearest(current, unvisited);
      }
    }
    
    return route;
  }

  /// Find the nearest temple to the current one
  Temple _findNearest(Temple current, List<Temple> candidates) {
    Temple nearest = candidates.first;
    double minDistance = double.infinity;
    
    for (final candidate in candidates) {
      final distance = _getDistance(current, candidate);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = candidate;
      }
    }
    
    return nearest;
  }

  /// Get distance between two temples
  double _getDistance(Temple a, Temple b) {
    return calculateDistance(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  /// Estimate travel time in minutes based on distance
  double estimateTravelTime(double distanceKm) {
    // Average speed assumptions (km/h)
    const speeds = {
      'Car': 40.0,
      'Bike': 35.0,
      'Bus': 25.0,
      'Walking': 5.0,
    };
    final speed = speeds[constraints.travelMode] ?? 40.0;
    return (distanceKm / speed) * 60; // Convert hours to minutes
  }

  /// 2-opt improvement algorithm
  List<Temple> _twoOptImprovement(List<Temple> route) {
    if (route.length < 4) return route;
    
    List<Temple> improved = List<Temple>.from(route);
    bool improvement = true;
    
    while (improvement) {
      improvement = false;
      
      for (var i = 1; i < improved.length - 2; i++) {
        for (var j = i + 2; j < improved.length; j++) {
          final currentDistance = _getDistance(improved[i - 1], improved[i]) +
              _getDistance(improved[j - 1], improved[j]);
          final newDistance = _getDistance(improved[i - 1], improved[j - 1]) +
              _getDistance(improved[i], improved[j]);
          
          if (newDistance < currentDistance) {
            final segment = improved.sublist(i, j);
            final reversed = segment.reversed.toList();
            improved.replaceRange(i, j, reversed);
            improvement = true;
          }
        }
      }
    }
    
    return improved;
  }

  /// Create daily plans from optimized temple list
  List<DayPlan> _createDailyPlans(List<Temple> temples, List<String> warnings) {
    final List<DayPlan> dayPlans = [];
    final templesPerDay = constraints.maxTemplesPerDay ?? 3;
    final days = (temples.length / templesPerDay).ceil();
    
    DateTime currentDate = constraints.startDate ?? DateTime.now();
    
    for (int day = 0; day < days; day++) {
      final startIndex = day * templesPerDay;
      final endIndex = min(startIndex + templesPerDay, temples.length);
      final dayTemples = temples.sublist(startIndex, endIndex);
      
      if (dayTemples.isEmpty) break;

      final visits = <TempleVisit>[];
      double dailyDistance = 0;
      Duration dailyDuration = Duration.zero;
      double dailyCost = 0;
      
      String previousArrivalTime = '08:00 AM';
      
      for (int i = 0; i < dayTemples.length; i++) {
        final temple = dayTemples[i];
        final order = i + 1;
        
        // Calculate arrival time
        final arrivalTime = _calculateArrivalTime(previousArrivalTime, dailyDuration);
        
        // Darshan duration (minimum 30 minutes, varies by temple popularity)
        final darshanDuration = Duration(minutes: temple.rating != null && temple.rating! > 4.5 ? 60 : 30);
        final departureTime = _calculateDepartureTime(arrivalTime, darshanDuration);
        
        // Travel distance and time
        double travelDistance = 0;
        Duration travelTime = Duration.zero;
        
        if (i > 0) {
          final prevTemple = dayTemples[i - 1];
          travelDistance = _getDistance(prevTemple, temple);
          travelTime = Duration(minutes: estimateTravelTime(travelDistance).toInt());
          dailyDistance += travelDistance;
        }
        
        // Estimate cost
        final visitCost = _estimateTempleCost(temple);
        dailyCost += visitCost;
        
        visits.add(TempleVisit(
          temple: temple,
          order: order,
          arrivalTime: arrivalTime,
          departureTime: departureTime,
          darshanDuration: darshanDuration,
          travelDistance: travelDistance,
          travelTime: travelTime,
          estimatedCost: visitCost,
        ));
        
        previousArrivalTime = departureTime;
        dailyDuration += travelTime + darshanDuration;
      }
      
      // Check if daily plan exceeds reasonable hours
      if (dailyDuration.inHours > 10) {
        warnings.add('Day ${day + 1} itinerary is quite full ($dailyDuration)');
      }
      
      dayPlans.add(DayPlan(
        dayNumber: day + 1,
        date: currentDate,
        visits: visits,
        dailyDistance: dailyDistance,
        dailyDuration: dailyDuration,
        dailyCost: dailyCost,
      ));
      
      // Move to next day
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Check budget
    if (constraints.maxBudget != null) {
      final totalCost = dayPlans.fold<double>(0, (sum, day) => sum + day.dailyCost);
      if (totalCost > constraints.maxBudget!) {
        warnings.add('Total cost (₹${totalCost.toStringAsFixed(0)}) exceeds budget (₹${constraints.maxBudget})');
      }
    }
    
    return dayPlans;
  }

  /// Calculate arrival time based on previous activities
  String _calculateArrivalTime(String previousTime, Duration elapsed) {
    final parts = previousTime.split(' ');
    final timeParts = parts[0].split(':');
    int hours = int.parse(timeParts[0]);
    int minutes = int.parse(timeParts[1]);
    
    if (parts[1] == 'PM' && hours != 12) hours += 12;
    if (parts[1] == 'AM' && hours == 12) hours = 0;
    
    final totalMinutes = hours * 60 + minutes + elapsed.inMinutes;
    final newHours = (totalMinutes / 60).floor() % 24;
    final newMinutes = totalMinutes % 60;
    
    final period = newHours < 12 ? 'AM' : 'PM';
    final displayHours = newHours > 12 ? newHours - 12 : (newHours == 0 ? 12 : newHours);
    
    return '${displayHours.toString().padLeft(2, '0')}:${newMinutes.toString().padLeft(2, '0')} $period';
  }

  /// Calculate departure time after darshan
  String _calculateDepartureTime(String arrivalTime, Duration darshanDuration) {
    final parts = arrivalTime.split(' ');
    final timeParts = parts[0].split(':');
    int hours = int.parse(timeParts[0]);
    int minutes = int.parse(timeParts[1]);
    
    if (parts[1] == 'PM' && hours != 12) hours += 12;
    if (parts[1] == 'AM' && hours == 12) hours = 0;
    
    final totalMinutes = hours * 60 + minutes + darshanDuration.inMinutes;
    final newHours = (totalMinutes / 60).floor() % 24;
    final newMinutes = totalMinutes % 60;
    
    final period = newHours < 12 ? 'AM' : 'PM';
    final displayHours = newHours > 12 ? newHours - 12 : (newHours == 0 ? 12 : newHours);
    
    return '${displayHours.toString().padLeft(2, '0')}:${newMinutes.toString().padLeft(2, '0')} $period';
  }

  /// Estimate cost for visiting a temple
  double _estimateTempleCost(Temple temple) {
    // Base cost for offerings and prasadam
    double cost = 100; // Base cost
    
    // Add more for popular temples
    if (temple.rating != null && temple.rating! > 4.5) {
      cost += 100;
    }
    
    // Travel cost (simplified - would be more complex in real app)
    cost += 50;
    
    return cost;
  }
}
