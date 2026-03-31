// Directions API service for real route calculations
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/temple_model.dart';
import '../models/route_model.dart';

/// Exception for CORS-related errors
class CorsException implements Exception {
  final String message;
  CorsException(this.message);
  @override
  String toString() => 'CorsException: $message';
}

/// Exception for Google Maps API errors
class GoogleMapsApiException implements Exception {
  final String code;
  final String message;
  GoogleMapsApiException(this.code, this.message);
  @override
  String toString() => 'GoogleMapsApiException: $code - $message';
}

class DirectionsService {
  final String _apiKey;
  final http.Client _client;
  final int _maxRetries;
  final Duration _retryDelay;
  
  DirectionsService({String? apiKey, http.Client? client, int? maxRetries})
      : _apiKey = apiKey ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
        _client = client ?? http.Client(),
        _maxRetries = maxRetries ?? 3,
        _retryDelay = const Duration(seconds: 2);
  
  Future<DirectionsResponse> getDirections({
    required LatLng origin,
    required LatLng destination,
    TravelMode travelMode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=${_getTravelModeString(travelMode)}'
      '&avoid=tolls${avoidTolls ? '|highways' : ''}'
      '&key=$_apiKey',
    );
    
    return _executeWithRetry(() => _fetchDirections(url, origin, destination));
  }
  
  Future<DirectionsResponse> _fetchDirections(Uri url, LatLng origin, LatLng destination) async {
    try {
      final response = await _client.get(url);
      
      // Handle CORS errors specifically
      if (response.statusCode == 0 || 
          response.body.isEmpty ||
          response.statusCode >= 500) {
        throw CorsException('CORS or server error: Status ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return _parseDirectionsResponse(data);
        } else if (data['status'] == 'OVER_QUERY_LIMIT') {
          throw GoogleMapsApiException('OVER_QUERY_LIMIT', 'API quota exceeded');
        } else if (data['status'] == 'ZERO_RESULTS') {
          throw GoogleMapsApiException('ZERO_RESULTS', 'No route found');
        } else {
          throw GoogleMapsApiException(data['status'] ?? 'UNKNOWN_ERROR', data['error_message']);
        }
      } else {
        throw Exception('Failed to fetch directions: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw CorsException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw CorsException('Client error: ${e.message}');
    }
  }
  
  Future<DirectionsResponse> _executeWithRetry(Future<DirectionsResponse> Function() fetchFn) async {
    int attempt = 0;
    Exception? lastException;
    
    while (attempt < _maxRetries) {
      try {
        return await fetchFn();
      } on CorsException catch (e) {
        // CORS errors should not be retried - they're browser security issues
        throw CorsException('${e.message} (This is a CORS error - use Android device for testing)');
      } on GoogleMapsApiException catch (e) {
        // API errors may be transient
        attempt++;
        if (attempt >= _maxRetries) {
          rethrow;
        }
        await Future.delayed(_retryDelay * attempt);
        lastException = e;
      } on Exception catch (e) {
        attempt++;
        if (attempt >= _maxRetries) {
          rethrow;
        }
        await Future.delayed(_retryDelay * attempt);
        lastException = e;
      }
    }
    
    throw lastException ?? Exception('Unknown error');
  }
  
  /// Get estimated route without API call (fallback for CORS)
  static DirectionsResponse getEstimatedRoute({
    required LatLng origin,
    required LatLng destination,
    double averageSpeedKmH = 40,
  }) {
    // Calculate straight-line distance
    final distanceKm = calculateHaversineDistance(origin, destination);
    
    // Estimate duration based on average speed
    final durationHours = distanceKm / averageSpeedKmH;
    final duration = Duration(hours: (durationHours * 60).round());
    
    // Generate approximate polyline points
    final points = _generateApproximatePolyline(origin, destination);
    
    // Calculate bounds
    final bounds = LatLngBounds(
      southwest: LatLng(
        origin.latitude < destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude < destination.longitude ? origin.longitude : destination.longitude,
      ),
      northeast: LatLng(
        origin.latitude > destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude > destination.longitude ? origin.longitude : destination.longitude,
      ),
    );
    
    return DirectionsResponse(
      overviewPolyline: points,
      totalDistance: distanceKm,
      totalDuration: duration,
      bounds: bounds,
      steps: [
        RouteStep(
          distance: distanceKm,
          duration: duration,
          instructions: 'Estimated route (${distanceKm.toStringAsFixed(1)} km)',
          polylinePoints: points,
        ),
      ],
      temples: [],
      isEstimated: true,
    );
  }
  
  /// Calculate distance between two points using Haversine formula
  static double calculateHaversineDistance(LatLng origin, LatLng destination) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(destination.latitude - origin.latitude);
    final dLng = _degToRad(destination.longitude - origin.longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(origin.latitude)) * math.cos(_degToRad(destination.latitude)) * math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
  
  static double _degToRad(double deg) => deg * math.pi / 180;
  
  static List<LatLng> _generateApproximatePolyline(LatLng origin, LatLng destination) {
    final points = <LatLng>[];
    final steps = 10;
    for (int i = 1; i < steps; i++) {
      final fraction = i / steps;
      points.add(LatLng(
        origin.latitude + (destination.latitude - origin.latitude) * fraction,
        origin.longitude + (destination.longitude - origin.longitude) * fraction,
      ));
    }
    return points;
  }
  
  Future<DirectionsResponse> getRouteBetweenTemples({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    TravelMode travelMode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    if (waypoints.isEmpty) {
      return getDirections(
        origin: origin,
        destination: destination,
        travelMode: travelMode,
        avoidTolls: avoidTolls,
        avoidHighways: avoidHighways,
      );
    }
    
    final waypointsStr = waypoints.map((w) => '${w.latitude},${w.longitude}').join('|');
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&waypoints=optimize:true|$waypointsStr'
      '&mode=${_getTravelModeString(travelMode)}'
      '&avoid=${_getAvoidString(avoidTolls, avoidHighways)}'
      '&key=$_apiKey',
    );
    
    return _executeWithRetry(() => _fetchDirections(url, origin, destination));
  }
  
  Future<DirectionsResponse> getMultiPointRoute({
    required List<Temple> temples,
    TravelMode travelMode = TravelMode.driving,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    if (temples.length < 2) {
      throw Exception('At least 2 temples required for route');
    }
    
    final origin = LatLng(temples.first.latitude, temples.first.longitude);
    final destination = LatLng(temples.last.latitude, temples.last.longitude);
    
    // Build waypoints string
    final waypoints = temples.length > 2
        ? '&waypoints=optimize:true|${temples.sublist(1, temples.length - 1).map((t) => '${t.latitude},${t.longitude}').join('|')}'
        : '';
    
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '$waypoints'
      '&mode=${_getTravelModeString(travelMode)}'
      '&avoid=${_getAvoidString(avoidTolls, avoidHighways)}'
      '&key=$_apiKey',
    );
    
    return _executeWithRetry(() => _fetchDirections(url, origin, destination));
  }
  
  DirectionsResponse _parseDirectionsResponse(Map<String, dynamic> data) {
    final route = data['routes'][0];
    final leg = route['legs'][0];
    
    final overviewPolyline = _decodePolyline(route['overview_polyline']['points']);
    final bounds = route['bounds'];
    
    final distance = leg['distance']['value'] / 1000.0; // km
    final duration = Duration(seconds: leg['duration']['value']);
    
    final steps = <RouteStep>[];
    for (final step in leg['steps']) {
      steps.add(RouteStep(
        distance: step['distance']['value'] / 1000.0,
        duration: Duration(seconds: step['duration']['value']),
        instructions: step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ''),
        polylinePoints: _decodePolyline(step['polyline']['points']),
      ));
    }
    
    return DirectionsResponse(
      overviewPolyline: overviewPolyline,
      totalDistance: distance,
      totalDuration: duration,
      bounds: LatLngBounds(
        southwest: LatLng(bounds['southwest']['lat'], bounds['southwest']['lng']),
        northeast: LatLng(bounds['northeast']['lat'], bounds['northeast']['lng']),
      ),
      steps: steps,
      temples: [],
    );
  }
  
  DirectionsResponse _parseMultiPointResponse(Map<String, dynamic> data, List<Temple> temples) {
    final route = data['routes'][0];
    final legs = route['legs'];
    
    final overviewPolyline = _decodePolyline(route['overview_polyline']['points']);
    final bounds = route['bounds'];
    
    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    final steps = <RouteStep>[];
    final tollSegments = <TollSegment>[];
    
    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      totalDistance += leg['distance']['value'] / 1000.0;
      totalDuration += Duration(seconds: leg['duration']['value']);
      
      for (final step in leg['steps']) {
        steps.add(RouteStep(
          distance: step['distance']['value'] / 1000.0,
          duration: Duration(seconds: step['duration']['value']),
          instructions: step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ''),
          polylinePoints: _decodePolyline(step['polyline']['points']),
        ));
      }
    }
    
    return DirectionsResponse(
      overviewPolyline: overviewPolyline,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      bounds: LatLngBounds(
        southwest: LatLng(bounds['southwest']['lat'], bounds['southwest']['lng']),
        northeast: LatLng(bounds['northeast']['lat'], bounds['northeast']['lng']),
      ),
      steps: steps,
      temples: temples,
      tollSegments: tollSegments,
    );
  }
  
  String _getTravelModeString(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving: return 'driving';
      case TravelMode.walking: return 'walking';
      case TravelMode.bicycling: return 'bicycling';
      case TravelMode.transit: return 'transit';
    }
  }
  
  String _getAvoidString(bool avoidTolls, bool avoidHighways) {
    final avoidList = <String>[];
    if (avoidTolls) avoidList.add('tolls');
    if (avoidHighways) avoidList.add('highways');
    return avoidList.isEmpty ? '' : avoidList.join('|');
  }
  
  List<LatLng> _decodePolyline(String encoded) {
    final polyline = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    
    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      
      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    
    return polyline;
  }
}

class DirectionsResponse {
  final List<LatLng> overviewPolyline;
  final double totalDistance;
  final Duration totalDuration;
  final LatLngBounds bounds;
  final List<RouteStep> steps;
  final List<Temple> temples;
  final List<TollSegment> tollSegments;
  final bool isEstimated;
  
  DirectionsResponse({
    required this.overviewPolyline,
    required this.totalDistance,
    required this.totalDuration,
    required this.bounds,
    required this.steps,
    required this.temples,
    this.tollSegments = const [],
    this.isEstimated = false,
  });
  
  String get formattedDistance => '${totalDistance.toStringAsFixed(1)} km';
  
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class RouteStep {
  final double distance;
  final Duration duration;
  final String instructions;
  final List<LatLng> polylinePoints;
  
  RouteStep({
    required this.distance,
    required this.duration,
    required this.instructions,
    required this.polylinePoints,
  });
}

class TollSegment {
  final String id;
  final String name;
  final double cost;
  final List<LatLng> polylinePoints;
  
  TollSegment({
    required this.id,
    required this.name,
    required this.cost,
    required this.polylinePoints,
  });
}
