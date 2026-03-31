// Route and navigation models

class RouteResult {
  final List<LatLngWrapper> polylinePoints;
  final List<NavigationStep> steps;
  final Duration duration;
  final double distanceInMeters;
  final String summary;

  RouteResult({
    required this.polylinePoints,
    required this.steps,
    required this.duration,
    required this.distanceInMeters,
    required this.summary,
  });

  /// Get distance in kilometers
  double get distanceInKm => distanceInMeters / 1000;

  /// Get formatted duration string
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class LatLngWrapper {
  final double latitude;
  final double longitude;

  LatLngWrapper({required this.latitude, required this.longitude});
}

class NavigationStep {
  final String instruction;
  final String maneuver;
  final double distanceInMeters;
  final Duration duration;
  final LatLngWrapper startLocation;
  final LatLngWrapper endLocation;

  NavigationStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceInMeters,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  String get formattedDistance {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.toInt()} m';
  }
}

enum OptimizationMode {
  shortestDistance,
  leastTime,
  scenic,
  spiritual,
}

enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}
