// Route planner screen for multi-temple yatra with budget estimation
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/temple_model.dart';
import '../models/route_model.dart';
import '../services/routing_engine.dart';
import '../services/itinerary_generator.dart';
import '../services/budget_service.dart';
import '../services/directions_service.dart';
import '../services/groq_service.dart';
import '../utils/distance_calculator.dart';
import 'simulation_screen.dart';
import 'itinerary_input_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/crowd_badge.dart';
import '../providers/festival_provider.dart';
import '../database/db_providers.dart';
import '../models/festival_event.dart';
import '../services/crowd_engine.dart';

class RoutePlannerScreen extends StatefulWidget {
  final List<Temple> selectedTemples;
  final GeneratedItinerary? itinerary;
  final String travelMode;
  final bool avoidHighways;
  final double budget;
  final double fuelPrice;
  final int numberOfDays;
  final int numberOfNights;
  final AccommodationType accommodationType;

  const RoutePlannerScreen({
    super.key,
    required this.selectedTemples,
    this.itinerary,
    this.travelMode = 'Car',
    this.avoidHighways = false,
    this.budget = 0,
    this.fuelPrice = 100,
    this.numberOfDays = 1,
    this.numberOfNights = 0,
    this.accommodationType = AccommodationType.budget,
  });

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  // Fixed to use only fastest route (no mode selection needed)
  List<Temple> _optimizedRoute = [];
  RouteStatistics? _statistics;
  bool _isRecalculating = false;
  
  // Re-routing state
  LatLng? _currentUserPosition;
  int _currentWaypointIndex = 0;
  bool _isOffRoute = false;
  Timer? _routeCheckTimer;
  StreamSubscription<Position>? _positionSubscription;
  
  // Debouncing re-routing
  DateTime? _lastReRouteTime;
  LatLng? _lastCheckedPosition;
  bool _isReRoutingInProgress = false;
  Timer? _autoRerouteTimer;   // fires 20s after off-route detected if not dismissed
  bool _rerouteDismissed = false; // user dismissed the banner

  // Day-by-day view
  int _selectedDay = 0; // 0 = overview, 1..N = day tabs

  // Budget and vehicle state — derived from widget props, not hardcoded
  VehicleType _selectedVehicle = VehicleType.car;

  // Convenience getters — read from widget, never hardcoded
  AccommodationType get _selectedAccommodation => widget.accommodationType;
  int get _numberOfNights => widget.numberOfNights;
  int get _numberOfDays => widget.numberOfDays;
  double get _maxBudget => widget.budget;
  double get _fuelPrice => widget.fuelPrice;
  
  // Budget service
  late BudgetService _budgetService;
  BudgetEstimate? _budgetEstimate;
  // Cached per-vehicle fuel estimates — computed once when route/stats change
  Map<VehicleType, String> _vehicleFuelLabels = {};
  
  // Directions service (for route visualization)
  late DirectionsService _directionsService;
  DirectionsResponse? _directionsResponse;
  
  // Groq service for public transport (future use)
  late GroqService? _groqService;
  bool _isLoadingTransport = false;
  PublicTransportInfo? _transportInfo;
  bool _showTransportInfo = false;
  
  // Map controller
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    // Initialise vehicle from the travel mode passed by YatraPlannerScreen
    _selectedVehicle = switch (widget.travelMode) {
      'Bike' => VehicleType.bike,
      'Bus' => VehicleType.bus,
      _ => VehicleType.car,
    };
    _budgetService = BudgetService();
    _directionsService = DirectionsService(
      apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
    );
    _groqService = dotenv.env['GROQ_API_KEY'] != null 
        ? GroqService(apiKey: dotenv.env['GROQ_API_KEY']!)
        : null;
    _calculateRoute();
    if (!kIsWeb) {
      _startRouteMonitoring();
      _startGpsTracking();
    }
  }

  void _startGpsTracking() async {
    // Check and request location permission before starting stream
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      // Can't get location — route monitoring will use manual re-route only
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).handleError((error) {
      // Swallow location errors gracefully — app works without GPS
      debugPrint('Location stream error: $error');
    }).listen((Position position) {
      if (mounted) {
        _updateUserPosition(LatLng(position.latitude, position.longitude));
      }
    });
  }

  @override
  void dispose() {
    _routeCheckTimer?.cancel();
    _autoRerouteTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _calculateRoute() async {
    setState(() {
      _isRecalculating = true;
    });

    // RoutingEngine now only uses fastest route (leastTime)
    final engine = RoutingEngine(
      temples: widget.selectedTemples,
    );

    final route = engine.optimizeRoute();
    final stats = engine.calculateStatistics(route);
    
    setState(() {
      _optimizedRoute = route;
      _statistics = stats;
      _isRecalculating = false;
      _isOffRoute = false;
      _currentWaypointIndex = 0;
    });
    
    // Calculate budget with selected vehicle
    _calculateBudget();
    
    // Fetch directions for route visualization
    if (route.length >= 2) {
      _fetchDirections(route);
    }
  }
  
  /// Start monitoring user position for re-routing
  void _startRouteMonitoring() {
    _routeCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkRouteDeviation(),
    );
  }
  
  /// Check if user has deviated from the planned route
  void _checkRouteDeviation() {
    // Don't check if already re-routing
    if (_isReRoutingInProgress) return;
    
    // Debounce: Don't re-route more than once every 30 seconds
    if (_lastReRouteTime != null) {
      final elapsed = DateTime.now().difference(_lastReRouteTime!);
      if (elapsed.inSeconds < 30) return;
    }
    
    if (_currentUserPosition == null || _optimizedRoute.isEmpty) return;
    
    // Check if user has actually moved significantly (at least 50 meters)
    if (_lastCheckedPosition != null) {
      final movement = calculateDistance(
        _currentUserPosition!.latitude, _currentUserPosition!.longitude,
        _lastCheckedPosition!.latitude, _lastCheckedPosition!.longitude
      );
      if (movement < 0.05) {
        // User hasn't moved significantly, skip check
        return;
      }
    }
    _lastCheckedPosition = _currentUserPosition;
    
    // Only check deviation from current waypoint onwards (ignore route behind user)
    final remainingWaypoints = _optimizedRoute.sublist(_currentWaypointIndex);
    final routePoints = remainingWaypoints.map((t) => LatLng(t.latitude, t.longitude)).toList();
    
    if (routePoints.isEmpty) return;
    
    final engine = RoutingEngine(temples: remainingWaypoints);
    
    // Use 0.5 km threshold for more lenient detection
    if (engine.isOffRoute(_currentUserPosition!, routePoints, thresholdDistance: 0.5)) {
      if (!_isOffRoute) {
        setState(() {
          _isOffRoute = true;
          _rerouteDismissed = false;
        });
        // Auto-reroute after 20 seconds if user doesn't dismiss
        _autoRerouteTimer?.cancel();
        _autoRerouteTimer = Timer(const Duration(seconds: 20), () {
          if (mounted && _isOffRoute && !_rerouteDismissed) {
            _triggerReRouting();
          }
        });
      }
    } else {
      if (_isOffRoute) {
        _autoRerouteTimer?.cancel();
        setState(() { _isOffRoute = false; });
      }
    }
  }
  
  /// Trigger re-routing when user deviates from route
  void _triggerReRouting() {
    if (_currentUserPosition == null || _optimizedRoute.isEmpty || _isReRoutingInProgress) return;
    
    // Set re-routing in progress flag
    _isReRoutingInProgress = true;
    _lastReRouteTime = DateTime.now();
    
    // Find the nearest remaining temple by Haversine distance from current position.
    // This replaces the buggy indexOf(syntheticTemple) approach.
    final remaining = _optimizedRoute.sublist(_currentWaypointIndex);
    if (remaining.isEmpty) {
      _isReRoutingInProgress = false;
      return;
    }

    int nearestIndex = _currentWaypointIndex;
    double minDistance = double.infinity;
    for (int i = 0; i < remaining.length; i++) {
      final temple = remaining[i];
      final dist = calculateDistance(
        _currentUserPosition!.latitude, _currentUserPosition!.longitude,
        temple.latitude, temple.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestIndex = _currentWaypointIndex + i;
      }
    }

    final newRoute = _optimizedRoute.sublist(nearestIndex);
    
    setState(() {
      _optimizedRoute = newRoute;
      _currentWaypointIndex = 0;
      _isReRoutingInProgress = false;
      _isOffRoute = false;
    });
    
    _fetchDirections(newRoute);
    
    // Show re-routing notification
    _showReRoutingNotification();
  }
  
  void _showReRoutingNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Route recalculated! Finding new path...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Update current user position from map
  void _updateUserPosition(LatLng position) {
    setState(() {
      _currentUserPosition = position;
    });
    _checkRouteDeviation();
    
    // Check if user reached a waypoint
    if (_optimizedRoute.isNotEmpty && _currentWaypointIndex < _optimizedRoute.length) {
      final nextTemple = _optimizedRoute[_currentWaypointIndex];
      final engine = RoutingEngine(temples: _optimizedRoute);
      
      if (engine.hasReachedWaypoint(
        position, 
        LatLng(nextTemple.latitude, nextTemple.longitude),
        thresholdDistance: 0.05,
      )) {
        // User reached the waypoint, move to next
        if (_currentWaypointIndex < _optimizedRoute.length - 1) {
          setState(() {
            _currentWaypointIndex++;
          });
        }
      }
    }
  }
  
  void _calculateBudget() {
    final distance = _statistics?.totalDistance ?? 0;
    final bounds = _calculateBounds(_optimizedRoute);

    // Cache fuel labels for all vehicle types — avoids 3x recalc per build
    _vehicleFuelLabels = {
      for (final v in VehicleType.values)
        v: _budgetService.calculateBudget(
          routeDetails: DirectionsResponse(
            overviewPolyline: [], totalDistance: distance,
            totalDuration: Duration.zero, bounds: bounds, steps: [], temples: _optimizedRoute,
          ),
          preferences: BudgetPreferences(
            vehicleType: v, accommodationType: _selectedAccommodation,
            numberOfNights: _numberOfNights, numberOfDays: _numberOfDays,
            fuelPricePerLiter: _fuelPrice,
          ),
        ).formattedFuel,
    };

    final preferences = BudgetPreferences(
      vehicleType: _selectedVehicle,
      accommodationType: _selectedAccommodation,
      numberOfNights: _numberOfNights,
      numberOfDays: _numberOfDays,
      maxBudget: _maxBudget,
      fuelPricePerLiter: _fuelPrice,
    );
    
    final routeDetails = DirectionsResponse(
      overviewPolyline: [], totalDistance: distance,
      totalDuration: Duration.zero, bounds: bounds, steps: [], temples: _optimizedRoute,
    );
    
    setState(() {
      _budgetEstimate = _budgetService.calculateBudget(
        routeDetails: routeDetails,
        preferences: preferences,
      );
    });
  }
  
  LatLngBounds _calculateBounds(List<Temple> temples) {
    if (temples.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(17.0, 78.0),
        northeast: const LatLng(17.5, 78.5),
      );
    }
    final lats = temples.map((t) => t.latitude);
    final lngs = temples.map((t) => t.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.01, lngs.reduce((a, b) => a < b ? a : b) - 0.01),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.01, lngs.reduce((a, b) => a > b ? a : b) + 0.01),
    );
  }
  
  Future<void> _fetchDirections(List<Temple> route) async {
    if (route.length < 2) return;
    
    try {
      _directionsResponse = await _directionsService.getRouteBetweenTemples(
        origin: LatLng(route.first.latitude, route.first.longitude),
        destination: LatLng(route.last.latitude, route.last.longitude),
        waypoints: route.sublist(1, route.length - 1).map((t) => LatLng(t.latitude, t.longitude)).toList(),
        travelMode: TravelMode.driving,
      );
      
      // Update map with markers and polylines
      _updateMapMarkers();
      _updateRoutePolyline();
    } on CorsException catch (e) {
      debugPrint('Directions CORS: ${e.message}');
      _directionsResponse = _generateEstimatedRouteForRoute(route);
      _updateMapMarkers();
      _updateRoutePolyline();
    } on GoogleMapsApiException catch (e) {
      // REQUEST_DENIED = API not enabled in Cloud Console; fall back silently
      debugPrint('Directions API error (${e.code}): ${e.message}');
      _directionsResponse = _generateEstimatedRouteForRoute(route);
      _updateMapMarkers();
      _updateRoutePolyline();
    } catch (e) {
      debugPrint('Error fetching directions: $e');
      _directionsResponse = _generateEstimatedRouteForRoute(route);
      _updateMapMarkers();
      _updateRoutePolyline();
    }
  }
  
  /// Generate estimated route for a list of temples (fallback for CORS)
  DirectionsResponse _generateEstimatedRouteForRoute(List<Temple> route) {
    if (route.length < 2) {
      return DirectionsResponse(
        overviewPolyline: [],
        totalDistance: 0,
        totalDuration: Duration.zero,
        bounds: LatLngBounds(
          southwest: const LatLng(17.0, 78.0),
          northeast: const LatLng(17.5, 78.5),
        ),
        steps: [],
        temples: [],
        isEstimated: true,
      );
    }
    
    // Generate estimated route between all temples
    final points = <LatLng>[];
    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    const averageSpeedKmH = 40.0;
    
    for (int i = 0; i < route.length - 1; i++) {
      final origin = LatLng(route[i].latitude, route[i].longitude);
      final dest = LatLng(route[i + 1].latitude, route[i + 1].longitude);
      
      // Add intermediate points
      points.add(origin);
      
      // Calculate distance for this segment
      final segmentDistance = DirectionsService.calculateHaversineDistance(origin, dest);
      totalDistance += segmentDistance;
      
      // Estimate duration
      totalDuration += Duration(hours: (segmentDistance / averageSpeedKmH * 60).round());
    }
    
    // Add final point
    if (route.isNotEmpty) {
      points.add(LatLng(route.last.latitude, route.last.longitude));
    }
    
    // Calculate bounds
    final lats = route.map((t) => t.latitude);
    final lngs = route.map((t) => t.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.01, lngs.reduce((a, b) => a < b ? a : b) - 0.01),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.01, lngs.reduce((a, b) => a > b ? a : b) + 0.01),
    );
    
    return DirectionsResponse(
      overviewPolyline: points,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      bounds: bounds,
      steps: [
        RouteStep(
          distance: totalDistance,
          duration: totalDuration,
          instructions: 'Estimated route (${totalDistance.toStringAsFixed(1)} km)',
          polylinePoints: points,
        ),
      ],
      temples: route,
      isEstimated: true,
    );
  }
  
  void _updateMapMarkers() {
    _markers = {};
    for (int i = 0; i < _optimizedRoute.length; i++) {
      final temple = _optimizedRoute[i];
      _markers.add(
        Marker(
          markerId: MarkerId('temple_$i'),
          position: LatLng(temple.latitude, temple.longitude),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${temple.name}',
            snippet: temple.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0 ? BitmapDescriptor.hueGreen : (i == _optimizedRoute.length - 1 ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange),
          ),
        ),
      );
    }
    // Build polylines in the same pass — single setState below
    _polylines = {};
    if (_optimizedRoute.length >= 2) {
      final List<LatLng> routePoints;
      if (_directionsResponse != null && _directionsResponse!.overviewPolyline.isNotEmpty) {
        routePoints = _directionsResponse!.overviewPolyline;
      } else {
        routePoints = _optimizedRoute.map((t) => LatLng(t.latitude, t.longitude)).toList();
      }
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: _isOffRoute ? Colors.orange : Colors.blue,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _updateRoutePolyline() {} // no-op: _updateMapMarkers handles polylines
  
  void _fitMapToRoute() {
    if (_mapController == null || _optimizedRoute.isEmpty) return;
    
    final lats = _optimizedRoute.map((t) => t.latitude).toList();
    final lngs = _optimizedRoute.map((t) => t.longitude).toList();
    
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.01, lngs.reduce((a, b) => a < b ? a : b) - 0.01),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.01, lngs.reduce((a, b) => a > b ? a : b) + 0.01),
    );
    
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }
  
  LatLng _getMapCenter() {
    if (_optimizedRoute.isEmpty) {
      return const LatLng(17.3850, 78.4867); // Hyderabad center
    }
    final avgLat = _optimizedRoute.map((t) => t.latitude).reduce((a, b) => a + b) / _optimizedRoute.length;
    final avgLng = _optimizedRoute.map((t) => t.longitude).reduce((a, b) => a + b) / _optimizedRoute.length;
    return LatLng(avgLat, avgLng);
  }
  
  Future<void> _fetchPublicTransportInfo() async {
    if (_groqService == null || _optimizedRoute.isEmpty) return;
    
    setState(() {
      _isLoadingTransport = true;
      _showTransportInfo = false;
    });
    
    try {
      _transportInfo = await _groqService!.getPublicTransportInfo(
        origin: _optimizedRoute.first.name,
        destination: _optimizedRoute.last.name,
        travelDate: DateTime.now().add(const Duration(days: 1)),
      );
      setState(() {
        _showTransportInfo = true;
      });
    } catch (e) {
      debugPrint('Error fetching transport info: $e');
      _showTransportInfo = false;
    } finally {
      setState(() {
        _isLoadingTransport = false;
      });
    }
  }
  
  /// Close transport info panel
  void _closeTransportInfo() {
    setState(() {
      _showTransportInfo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Yatra'),
        actions: [
          if (_optimizedRoute.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Generate Itinerary',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItineraryInputScreen(
                      selectedTemples: _optimizedRoute,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateRoute,
            tooltip: 'Recalculate',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Vehicle type selector
            _buildVehicleSelector(),
            
            // Re-routing notification banner
            if (_isOffRoute) _buildReRoutingBanner(),

            // Route statistics and budget
            _buildStatisticsRow(),

            // Route visualization - Google Map with markers and polylines
            SizedBox(
              height: 300,
              child: _isRecalculating
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: CameraPosition(
                        target: _getMapCenter(),
                        zoom: 11,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _fitMapToRoute();
                      },
                      onCameraMove: (position) {
                        // Camera movement does NOT update GPS position.
                        // Only the Geolocator stream updates _currentUserPosition.
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
            ),

            // Temple list below map
            if (_optimizedRoute.isNotEmpty)
            SizedBox(
              height: 122,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: _optimizedRoute.length,
                itemBuilder: (context, index) {
                  final temple = _optimizedRoute[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: index <= _currentWaypointIndex ? Colors.green[50] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: index == _currentWaypointIndex
                            ? Colors.green
                            : AppTheme.borderColor,
                        width: index == _currentWaypointIndex ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${index + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(
                              temple.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 3),
                            Consumer(builder: (context, ref, _) {
                              final festivalsAsync =
                                  ref.watch(templeFestivalsDbProvider(temple.id));
                              final date =
                                  widget.itinerary?.dayPlans.firstOrNull?.date ??
                                      DateTime.now();
                              return festivalsAsync.when(
                                loading: () => const CrowdBadge(
                                    level: CrowdLevel.low, compact: true),
                                error: (e, _) => CrowdBadge(
                                    level: computeCrowdLevel(temple.id, date, []),
                                    compact: true),
                                data: (events) => CrowdBadge(
                                    level: computeCrowdLevel(temple.id, date, events),
                                    compact: true),
                              );
                            }),
                            if (index <= _currentWaypointIndex)
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Day-by-day itinerary plan
          if (widget.itinerary != null && widget.itinerary!.dayPlans.isNotEmpty)
            _buildDayByDayPlan(),

          // Transport Info Panel
          if (_showTransportInfo && _transportInfo != null) _buildTransportInfoPanel(),

          // Budget summary card - only show when temples are selected
          if (_budgetEstimate != null && _optimizedRoute.isNotEmpty) _buildBudgetSummary(),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingTransport ? null : _fetchPublicTransportInfo,
                    icon: _isLoadingTransport
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.directions_bus, size: 18),
                    label: Text(_isLoadingTransport ? 'Loading...' : 'Bus Info'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.maroon,
                      side: const BorderSide(color: AppTheme.maroon),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startSimulation,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Simulate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ), // SingleChildScrollView
  );
}

  Widget _buildDayByDayPlan() {
    final days = widget.itinerary!.dayPlans;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with day tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              const Icon(Icons.calendar_month, color: AppTheme.maroon, size: 18),
              const SizedBox(width: 6),
              const Text('Travel Plan',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${days.length} day${days.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          const SizedBox(height: 10),

          // Day selector tabs
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final selected = _selectedDay == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.maroon : AppTheme.softGrey,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppTheme.maroon : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      'Day ${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Selected day content
          _buildDayDetail(days[_selectedDay]),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDayDetail(DayPlan day) {
    final dateStr =
        '${day.date.day}/${day.date.month}/${day.date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day summary row
          Row(children: [
            const Icon(Icons.today, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(dateStr,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            const Icon(Icons.route, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('${day.dailyDistance.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${day.dailyDuration.inHours}h ${day.dailyDuration.inMinutes.remainder(60)}m',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ]),
          const SizedBox(height: 10),

          // Visit timeline
          ...day.visits.asMap().entries.map((entry) {
            final i = entry.key;
            final visit = entry.value;
            final isLast = i == day.visits.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line + dot
                  SizedBox(
                    width: 24,
                    child: Column(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? Colors.green
                              : (isLast ? AppTheme.maroon : AppTheme.saffron),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.borderColor,
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(visit.temple.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Text(
                              '${visit.arrivalTime} – ${visit.departureTime}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            if (visit.travelDistance > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${visit.travelDistance.toStringAsFixed(1)} km travel',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ]),
                          Text(
                            '₹${visit.estimatedCost.toStringAsFixed(0)} est.',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          // Day cost
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(
              'Day total: ₹${day.dailyCost.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.maroon),
            ),
          ]),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildReRoutingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border(left: BorderSide(color: Colors.orange[600]!, width: 4)),
      ),
      child: Row(children: [
        Icon(Icons.alt_route, color: Colors.orange[700], size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Off route — auto-rerouting in 20s',
            style: TextStyle(
                color: Colors.orange[800], fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () {
            _autoRerouteTimer?.cancel();
            setState(() { _isOffRoute = false; _rerouteDismissed = true; });
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: _triggerReRouting,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Re-route Now'),
        ),
      ]),
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Type',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: VehicleType.values.map((vehicle) {
              final selected = _selectedVehicle == vehicle;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedVehicle = vehicle);
                    _calculateBudget();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.maroon : AppTheme.softGrey,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppTheme.maroon : AppTheme.borderColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getVehicleIcon(vehicle),
                          color: selected ? Colors.white : AppTheme.warmGrey,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getVehicleName(vehicle),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? Colors.white : AppTheme.warmGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: VehicleType.values.map((vehicle) {
              final selected = _selectedVehicle == vehicle;
              return Text(
                _vehicleFuelLabels[vehicle] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.maroon : Colors.grey[500],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getVehicleIcon(VehicleType vehicle) {
    switch (vehicle) {
      case VehicleType.car: return Icons.directions_car;
      case VehicleType.bike: return Icons.two_wheeler;
      case VehicleType.bus: return Icons.directions_bus;
    }
  }

  String _getVehicleName(VehicleType vehicle) {
    switch (vehicle) {
      case VehicleType.car: return 'Car';
      case VehicleType.bike: return 'Bike';
      case VehicleType.bus: return 'Bus';
    }
  }

  Widget _buildStatisticsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(
            icon: Icons.route,
            value: _statistics?.formattedDistance ?? '0 km',
            label: 'Distance',
          )),
          Container(width: 1, height: 40, color: AppTheme.borderColor),
          Expanded(child: _buildStatCard(
            icon: Icons.access_time,
            value: _statistics?.formattedDuration ?? '0h',
            label: 'Est. Time',
          )),
          Container(width: 1, height: 40, color: AppTheme.borderColor),
          Expanded(child: _buildStatCard(
            icon: Icons.location_on,
            value: '${_optimizedRoute.length}',
            label: 'Stops',
          )),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sandalwoodBeige,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.maroon, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Cost Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedVehicle == VehicleType.bus)
            _buildBudgetRow('Bus Ticket', _budgetEstimate!.formattedBus)
          else
            _buildBudgetRow('Fuel/Transport', _budgetEstimate!.formattedFuel),
          _buildBudgetRow('Tolls', _budgetEstimate!.formattedToll),
          _buildBudgetRow('Accommodation', _budgetEstimate!.formattedAccommodation),
          _buildBudgetRow('Food', _budgetEstimate!.formattedFood),
          const SizedBox(height: 6),
          Text(
            '* Temple offerings are user-dependent and not included',
            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Estimate', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text(
                _budgetEstimate!.formattedTotal,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.maroon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String value, required String label, Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.maroon, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildTransportInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Public Transport Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                onPressed: _closeTransportInfo,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._transportInfo!.options.map((option) => _buildTransportOption(option)),
          const SizedBox(height: 12),
          if (_transportInfo!.cheapestOption.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cheapest Option', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(_transportInfo!.cheapestOption, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (_transportInfo!.routeTips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _transportInfo!.routeTips.map((tip) => 
                Chip(label: Text(tip, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.white)
              ).toList(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTransportOption(TransportOption option) {
    final typeIcon = switch (option.type) {
      'bus' => Icons.directions_bus,
      'train' => Icons.train,
      'metro' => Icons.subway,
      'shared' => Icons.local_taxi,
      _ => Icons.directions_transit,
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(typeIcon, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.operator, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${option.departureTime} - ${option.arrivalTime} | ${option.durationHours}hrs', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('₹${option.costPerPerson}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          if (option.bookingRequired && option.bookingUrl != null)
            TextButton(
              onPressed: () async {
                final url = Uri.parse(option.bookingUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('Book', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }
  
  void _startSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimulationScreen(initialRoute: _optimizedRoute),
      ),
    );
  }
}
