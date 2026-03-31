import 'dart:math';

/// Calculate distance between two coordinates using Haversine formula
/// Returns distance in kilometers
double calculateDistance(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadius = 6371.0; // Earth's radius in kilometers

  final lat1 = _toRadians(startLat);
  final lat2 = _toRadians(endLat);
  final deltaLat = _toRadians(endLat - startLat);
  final deltaLng = _toRadians(endLng - startLng);

  final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _toRadians(double degree) {
  return degree * pi / 180;
}

/// Format distance for display
String formatDistance(double distanceKm) {
  if (distanceKm < 1) {
    return '${(distanceKm * 1000).toInt()} m';
  }
  return '${distanceKm.toStringAsFixed(1)} km';
}
