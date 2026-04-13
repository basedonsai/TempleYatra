// Google Maps widget with error handling and fallback
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

/// Wrapper for GoogleMap widget with error handling
class SafeGoogleMap extends StatefulWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng initialCenter;
  final double initialZoom;
  final Function(GoogleMapController)? onMapCreated;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  
  const SafeGoogleMap({
    super.key,
    required this.markers,
    required this.polylines,
    required this.initialCenter,
    this.initialZoom = 11,
    this.onMapCreated,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
  });
  
  @override
  State<SafeGoogleMap> createState() => _SafeGoogleMapState();
}

class _SafeGoogleMapState extends State<SafeGoogleMap> {
  bool _hasError = false;
  String _errorMessage = '';
  GoogleMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorFallback();
    }
    
    try {
      return GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(
          target: widget.initialCenter,
          zoom: widget.initialZoom,
        ),
        markers: widget.markers,
        polylines: widget.polylines,
        onMapCreated: _handleMapCreated,
        myLocationEnabled: widget.myLocationEnabled,
        myLocationButtonEnabled: widget.myLocationButtonEnabled,
        onCameraMove: (_) {},
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Map initialization failed: ${e.toString()}';
          });
        }
      });
      return _buildLoadingPlaceholder();
    }
  }
  
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorFallback() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: Colors.orange[400]),
            const SizedBox(height: 16),
            const Text(
              'Map Unavailable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
    widget.onMapCreated?.call(controller);
  }
  
  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

/// Fallback static map widget when Google Maps is unavailable
class FallbackMapWidget extends StatelessWidget {
  final List<LatLng> routePoints;
  final Set<Marker> markers;
  
  const FallbackMapWidget({
    super.key,
    required this.routePoints,
    required this.markers,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background representation
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue[50]!,
                        Colors.blue[100]!,
                      ],
                    ),
                  ),
                ),
                // Route lines
                CustomPaint(
                  size: Size.infinite,
                  painter: RoutePainter(
                    routePoints: routePoints,
                    markers: markers,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Showing simplified route view. Enable internet for full map.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for route visualization
class RoutePainter extends CustomPainter {
  final List<LatLng> routePoints;
  final Set<Marker> markers;
  
  RoutePainter({required this.routePoints, required this.markers});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;
    
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final points = routePoints.map((p) => Offset(
      (p.longitude - 78.3) * 10000,
      (17.3 - p.latitude) * 10000,
    )).toList();
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) =>
      oldDelegate.routePoints != routePoints || oldDelegate.markers != markers;
}

/// Utility class for Google Maps initialization
class GoogleMapsHelper {
  /// Check if Google Maps is properly initialized
  static bool isInitialized = false;
  
  /// Initialize Google Maps SDK
  static Future<bool> initialize() async {
    try {
      // Perform any initialization checks here
      isInitialized = true;
      return true;
    } catch (e) {
      isInitialized = false;
      return false;
    }
  }
  
  /// Get map configuration based on device type
  static MapType getMapType() {
    return MapType.normal;
  }
  
  /// Calculate bounds for a list of points
  static LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(17.0, 78.0),
        northeast: const LatLng(17.5, 78.5),
      );
    }
    
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    
    return LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b) - 0.01,
        lngs.reduce((a, b) => a < b ? a : b) - 0.01,
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b) + 0.01,
        lngs.reduce((a, b) => a > b ? a : b) + 0.01,
      ),
    );
  }
  
  /// Format camera update for smooth animation
  static CameraUpdate fitBoundsWithPadding(
    LatLngBounds bounds, {
    double padding = 50,
  }) {
    return CameraUpdate.newLatLngBounds(bounds, padding);
  }
}
