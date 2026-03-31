// Simulation controller for dynamic yatra rerouting
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/temple_model.dart';
import 'routing_engine.dart';

/// Controller for managing the yatra simulation with dynamic rerouting
class SimulationController extends ChangeNotifier {
  List<Temple> _originalRoute = [];
  List<Temple> _currentRoute = [];
  List<Temple> _visitedTemples = [];
  List<Temple> _skippedTemples = [];
  int _currentIndex = 0;
  bool _isSimulating = false;
  bool _isPaused = false;
  int _simulationSpeed = 1;
  String _statusMessage = 'Ready to start';
  
  // Time tracking
  DateTime _startTime = DateTime.now();
  DateTime? _currentTime;
  Map<Temple, DateTime> _arrivalTimes = {};
  Map<Temple, DateTime> _departureTimes = {};
  
  // Default visit duration (45 minutes)
  static const int _defaultVisitDurationMinutes = 45;
  
  // Average speed for time estimation (30 km/h in city)
  static const double _averageSpeedKmH = 30.0;
  
  /// Constructor with initial route
  SimulationController({List<Temple>? initialRoute}) {
    if (initialRoute != null && initialRoute.isNotEmpty) {
      _originalRoute = List<Temple>.from(initialRoute);
      _currentRoute = List<Temple>.from(initialRoute);
      _calculateArrivalTimes();
    }
  }
  
  // Getters
  List<Temple> get currentRoute => _currentRoute;
  List<Temple> get visitedTemples => _visitedTemples;
  List<Temple> get skippedTemples => _skippedTemples;
  List<Temple> get remainingTemples => _currentRoute;
  int get currentIndex => _currentIndex;
  bool get isSimulating => _isSimulating;
  bool get isPaused => _isPaused;
  int get simulationSpeed => _simulationSpeed;
  String get statusMessage => _statusMessage;
  int get totalTemples => _originalRoute.length;
  int get visitedCount => _visitedTemples.length;
  int get skippedCount => _skippedTemples.length;
  int get remainingCount => _currentRoute.length;
  
  DateTime? get currentTime => _currentTime;
  DateTime? get estimatedArrival => _currentRoute.isNotEmpty 
      ? _arrivalTimes[_currentRoute.first] 
      : null;
  
  /// Initialize with a new route
  void initializeRoute(List<Temple> route) {
    _originalRoute = List<Temple>.from(route);
    _currentRoute = List<Temple>.from(route);
    _visitedTemples = [];
    _skippedTemples = [];
    _currentIndex = 0;
    _isSimulating = false;
    _isPaused = false;
    _statusMessage = 'Ready to start';
    _arrivalTimes = {};
    _departureTimes = {};
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Start the simulation
  void startSimulation() {
    if (_currentRoute.isEmpty) {
      _statusMessage = 'No route to simulate';
      notifyListeners();
      return;
    }
    
    _isSimulating = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _currentTime = _startTime;
    _statusMessage = 'Simulation started';
    notifyListeners();
  }
  
  /// Pause the simulation
  void pauseSimulation() {
    _isPaused = true;
    _statusMessage = 'Simulation paused';
    notifyListeners();
  }
  
  /// Resume the simulation
  void resumeSimulation() {
    _isPaused = false;
    _statusMessage = 'Simulation resumed';
    notifyListeners();
  }
  
  /// Reset the simulation to original route
  void resetSimulation() {
    _currentRoute = List<Temple>.from(_originalRoute);
    _visitedTemples = [];
    _skippedTemples = [];
    _currentIndex = 0;
    _isSimulating = false;
    _isPaused = false;
    _statusMessage = 'Simulation reset';
    _arrivalTimes = {};
    _departureTimes = {};
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Set simulation speed (1x, 2x, 5x, 10x)
  void setSimulationSpeed(int speed) {
    _simulationSpeed = speed;
    _statusMessage = 'Speed set to ${speed}x';
    notifyListeners();
  }
  
  /// Skip the current temple and recalculate route
  void skipCurrentTemple() {
    if (_currentRoute.isEmpty) return;
    
    final skipped = _currentRoute.removeAt(0);
    _skippedTemples.add(skipped);
    _visitedTemples.add(skipped);
    
    if (_currentIndex >= _currentRoute.length) {
      _currentIndex = _currentRoute.length - 1;
    }
    
    _statusMessage = 'Skipped ${skipped.name}. Recalculating route...';
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Skip a specific temple by index
  void skipTempleAtIndex(int index) {
    if (index < 0 || index >= _currentRoute.length) return;
    
    final skipped = _currentRoute.removeAt(index);
    _skippedTemples.add(skipped);
    
    if (index < _currentIndex) {
      _currentIndex = max(0, _currentIndex - 1);
    }
    
    _statusMessage = 'Skipped ${skipped.name}. Route recalculated.';
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Mark current temple as visited and move to next
  void visitCurrentTemple() {
    if (_currentRoute.isEmpty) return;
    
    final visited = _currentRoute.removeAt(0);
    _visitedTemples.add(visited);
    
    if (_currentIndex >= _currentRoute.length) {
      _currentIndex = _currentRoute.isEmpty ? 0 : _currentRoute.length - 1;
    }
    
    if (_currentRoute.isEmpty) {
      _statusMessage = 'Yatra completed! All temples visited.';
      _isSimulating = false;
    } else {
      _statusMessage = 'Visited ${visited.name}. Moving to next...';
    }
    
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Add extra time for visit at current temple
  void addExtraVisitTime(int minutes) {
    if (_currentRoute.isEmpty) return;
    
    final current = _currentRoute.first;
    final currentArrival = _arrivalTimes[current] ?? DateTime.now();
    _departureTimes[current] = currentArrival.add(Duration(minutes: minutes));
    
    _statusMessage = 'Added $minutes min to ${current.name} visit';
    _calculateArrivalTimes();
    notifyListeners();
  }
  
  /// Recalculate the entire route based on remaining temples
  List<Temple> recalculateRoute() {
    if (_currentRoute.length <= 2) return _currentRoute;
    
    // RoutingEngine now only uses fastest route
    final engine = RoutingEngine(temples: _currentRoute);
    
    final optimized = engine.optimizeRoute();
    _currentRoute = optimized;
    
    // Adjust current index if needed
    if (_currentIndex >= _currentRoute.length) {
      _currentIndex = _currentRoute.isEmpty ? 0 : _currentRoute.length - 1;
    }
    
    _calculateArrivalTimes();
    notifyListeners();
    
    return optimized;
  }
  
  /// Calculate arrival times for all remaining temples
  void _calculateArrivalTimes() {
    _arrivalTimes = {};
    _departureTimes = {};
    
    if (_currentRoute.isEmpty) return;
    
    DateTime currentTime = _startTime;
    
    for (int i = 0; i < _currentRoute.length; i++) {
      final temple = _currentRoute[i];
      
      // Add travel time from previous location
      if (i > 0) {
        final previous = _currentRoute[i - 1];
        final distance = _calculateDistance(previous, temple);
        final travelTimeMinutes = (distance / _averageSpeedKmH * 60).round();
        currentTime = currentTime.add(Duration(minutes: travelTimeMinutes));
      }
      
      _arrivalTimes[temple] = currentTime;
      
      // Add visit duration
      final visitDuration = temple.estimatedVisitDurationMinutes ?? _defaultVisitDurationMinutes;
      currentTime = currentTime.add(Duration(minutes: visitDuration));
      _departureTimes[temple] = currentTime;
    }
  }
  
  /// Calculate distance between two temples
  double _calculateDistance(Temple a, Temple b) {
    return _haversineDistance(a.latitude, a.longitude, b.latitude, b.longitude);
  }
  
  /// Get estimated arrival time for a specific temple
  DateTime? getEstimatedArrival(Temple temple) {
    return _arrivalTimes[temple];
  }
  
  /// Get total estimated duration
  Duration getTotalEstimatedDuration() {
    if (_arrivalTimes.isEmpty) return Duration.zero;
    
    final lastTemple = _currentRoute.last;
    final lastArrival = _arrivalTimes[lastTemple];
    final lastDeparture = _departureTimes[lastTemple];
    
    if (lastArrival == null) return Duration.zero;
    return lastDeparture?.difference(_startTime) ?? Duration.zero;
  }
  
  /// Get route statistics
  SimulationStatistics getStatistics() {
    return SimulationStatistics(
      totalTemples: totalTemples,
      visitedCount: visitedCount,
      skippedCount: skippedCount,
      remainingCount: remainingCount,
      totalDistance: _calculateTotalDistance(),
      totalDuration: getTotalEstimatedDuration(),
    );
  }
  
  /// Calculate total distance of current route
  double _calculateTotalDistance() {
    double total = 0.0;
    for (int i = 0; i < _currentRoute.length - 1; i++) {
      // Using Haversine formula approximation
      final a = _currentRoute[i];
      final b = _currentRoute[i + 1];
      total += _haversineDistance(
        a.latitude, a.longitude,
        b.latitude, b.longitude,
      );
    }
    return total;
  }
  
  /// Haversine distance calculation
  double _haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) + 
        cos(_toRadians(lat1)) * 
        cos(_toRadians(lat2)) * 
        pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }
  
  /// Export simulation summary
  SimulationSummary getSummary() {
    return SimulationSummary(
      originalRoute: _originalRoute,
      visitedTemples: List<Temple>.from(_visitedTemples),
      skippedTemples: List<Temple>.from(_skippedTemples),
      remainingTemples: List<Temple>.from(_currentRoute),
      arrivalTimes: Map<Temple, DateTime>.from(_arrivalTimes),
      statistics: getStatistics(),
    );
  }
}

/// Statistics for simulation
class SimulationStatistics {
  final int totalTemples;
  final int visitedCount;
  final int skippedCount;
  final int remainingCount;
  final double totalDistance;
  final Duration totalDuration;
  
  SimulationStatistics({
    required this.totalTemples,
    required this.visitedCount,
    required this.skippedCount,
    required this.remainingCount,
    required this.totalDistance,
    required this.totalDuration,
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
  
  double get completionPercentage {
    if (totalTemples == 0) return 0.0;
    return (visitedCount / totalTemples) * 100;
  }
}

/// Summary of simulation results
class SimulationSummary {
  final List<Temple> originalRoute;
  final List<Temple> visitedTemples;
  final List<Temple> skippedTemples;
  final List<Temple> remainingTemples;
  final Map<Temple, DateTime> arrivalTimes;
  final SimulationStatistics statistics;
  
  SimulationSummary({
    required this.originalRoute,
    required this.visitedTemples,
    required this.skippedTemples,
    required this.remainingTemples,
    required this.arrivalTimes,
    required this.statistics,
  });
}
