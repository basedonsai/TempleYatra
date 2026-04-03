// Routing engine for multi-temple itinerary optimization
// Simplified to use only the fastest route (leastTime optimization)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/temple_model.dart';
import '../models/route_model.dart';

class RoutingEngine {
  final List<Temple> temples;
  final TravelMode travelMode;
  
  // Fixed to use only fastest route (leastTime) optimization
  static const OptimizationMode defaultMode = OptimizationMode.leastTime;
  
  RoutingEngine({
    required this.temples,
    this.travelMode = TravelMode.driving,
  });

  /// Optimize the order of temples for the itinerary - always uses fastest route
  List<Temple> optimizeRoute() {
    if (temples.length <= 2) return temples;
    return _optimizeForTime();
  }
  
  /// Re-routing: Calculate a new route from current position to next temple
  /// Call this when user deviates from the planned route
  List<Temple> recalculateRoute({Temple? currentLocation, Temple? nextTemple}) {
    if (temples.isEmpty) return [];
    
    // If we have a current location, find the nearest remaining temple by
    // Haversine distance rather than using indexOf with a synthetic temple.
    if (currentLocation != null && nextTemple != null) {
      // Find the index of nextTemple in the list
      final nextIndex = temples.indexWhere((t) => t.id == nextTemple.id);
      if (nextIndex >= 0) {
        // Build route: nextTemple first, then remaining temples after it
        final reordered = <Temple>[nextTemple];
        for (int i = nextIndex + 1; i < temples.length; i++) {
          reordered.add(temples[i]);
        }
        return reordered;
      }
    }
    
    // Default: recalculate using fastest route
    return optimizeRoute();
  }
  
  /// Check if user is off the planned route
  /// Returns true if user's current position is more than thresholdDistance from the route
  bool isOffRoute(LatLng currentPosition, List<LatLng> routePoints, {double thresholdDistance = 0.1}) {
    if (routePoints.isEmpty) return false;
    
    // Find minimum distance from current position to any point on the route
    double minDistance = double.infinity;
    for (final point in routePoints) {
      final distance = _calculateDistance(
        currentPosition.latitude, currentPosition.longitude,
        point.latitude, point.longitude
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance > thresholdDistance;
  }
  
  /// Check if user has reached a waypoint (temple)
  bool hasReachedWaypoint(LatLng currentPosition, LatLng waypointPosition, {double thresholdDistance = 0.05}) {
    final distance = _calculateDistance(
      currentPosition.latitude, currentPosition.longitude,
      waypointPosition.latitude, waypointPosition.longitude
    );
    return distance <= thresholdDistance;
  }
  
  /// Get the next waypoint index based on current position
  int getNextWaypointIndex(LatLng currentPosition, List<LatLng> routePoints, {double thresholdDistance = 0.05}) {
    for (int i = 0; i < routePoints.length; i++) {
      if (!hasReachedWaypoint(currentPosition, routePoints[i], thresholdDistance: thresholdDistance)) {
        return i;
      }
    }
    return routePoints.length - 1; // Return last index if all reached
  }
  
  /// Optimize for least time — nearest-neighbor from westernmost temple,
  /// no hardcoded start point dependency
  List<Temple> _optimizeForTime() {
    final unvisited = List<Temple>.from(temples);
    // Start from westernmost temple as a neutral geographic anchor
    unvisited.sort((a, b) => a.longitude.compareTo(b.longitude));
    final result = <Temple>[unvisited.removeAt(0)];
    while (unvisited.isNotEmpty) {
      final last = result.last;
      Temple nearest = unvisited.first;
      double minDist = double.infinity;
      for (final t in unvisited) {
        final d = _calculateDistance(last.latitude, last.longitude, t.latitude, t.longitude);
        if (d < minDist) { minDist = d; nearest = t; }
      }
      unvisited.remove(nearest);
      result.add(nearest);
    }
    return result;
  }
  
  /// Calculate distance between two coordinates (Haversine)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = pow(sin(dLat / 2), 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLng / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _toRadians(double degree) => degree * pi / 180;
  
  /// Calculate route statistics
  RouteStatistics calculateStatistics(List<Temple> route) {
    if (route.isEmpty) {
      return RouteStatistics(
        totalDistance: 0.0,
        totalDuration: Duration.zero,
        averageDistance: 0.0,
      );
    }
    
    double totalDistance = 0.0;
    Duration totalDuration = Duration.zero;
    
    for (var i = 0; i < route.length - 1; i++) {
      final segmentDistance = _calculateDistance(
        route[i].latitude, route[i].longitude,
        route[i+1].latitude, route[i+1].longitude
      );
      totalDistance += segmentDistance;
      totalDuration += Duration(minutes: (segmentDistance / 50 * 60).round()); // Assume 50 km/h avg
    }
    
    final averageDistance = route.length > 1 
        ? totalDistance / (route.length - 1) 
        : 0.0;
    
    return RouteStatistics(
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      averageDistance: averageDistance,
    );
  }
  
  /// Generate route info - now returns only the fastest route
  /// This method is kept for compatibility but only returns one route
  List<AlternativeRoute> generateRouteInfo(List<Temple> temples) {
    final routes = <AlternativeRoute>[];
    
    // Only generate the fastest route
    final engine = RoutingEngine(temples: temples);
    final route = engine.optimizeRoute();
    final stats = engine.calculateStatistics(route);
    
    routes.add(AlternativeRoute(
      name: 'Fastest Route',
      icon: Icons.timer,
      description: 'Optimized for minimum travel time',
      distance: stats.totalDistance,
      time: stats.totalDuration,
      score: stats.totalDuration.inMinutes.toDouble(),
    ));
    
    return routes;
  }
}

class RouteStatistics {
  final double totalDistance;
  final Duration totalDuration;
  final double averageDistance;

  RouteStatistics({
    required this.totalDistance,
    required this.totalDuration,
    required this.averageDistance,
  });

  String get formattedDistance => '${totalDistance.toStringAsFixed(1)} km';
  
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class AlternativeRoute {
  final String name;
  final IconData icon;
  final String description;
  final double distance;
  final Duration time;
  final double score;

  AlternativeRoute({
    required this.name,
    required this.icon,
    required this.description,
    required this.distance,
    required this.time,
    required this.score,
  });

  String get formattedDistance => '${distance.toStringAsFixed(1)} km';
  
  String get formattedTime {
    final hours = time.inHours;
    final minutes = time.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
