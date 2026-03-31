// Budget estimation service for yatra cost calculation
// NOTE: Temple offerings are user-dependent and NOT included in estimates
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'directions_service.dart';
import '../models/temple_model.dart';

enum VehicleType { car, bike, bus }
enum AccommodationType { budget, midRange, luxury, none }

class BudgetPreferences {
  final VehicleType vehicleType;
  final AccommodationType accommodationType;
  final int numberOfNights;
  final int numberOfDays;
  final double maxBudget;
  final double foodBudgetPerDay;
  final double miscBudgetPerDay;
  final double fuelPricePerLiter;
  
  const BudgetPreferences({
    this.vehicleType = VehicleType.car,
    this.accommodationType = AccommodationType.budget,
    this.numberOfNights = 0,
    this.numberOfDays = 1,
    this.maxBudget = 5000,
    this.foodBudgetPerDay = 500,
    this.miscBudgetPerDay = 200,
    this.fuelPricePerLiter = 100,
  });
  
  double get defaultMileage => switch (vehicleType) {
    VehicleType.car => 15.0,
    VehicleType.bike => 50.0,
    VehicleType.bus => 8.0,
  };
  
  BudgetPreferences copyWith({
    VehicleType? vehicleType,
    AccommodationType? accommodationType,
    int? numberOfNights,
    int? numberOfDays,
    double? maxBudget,
    double? foodBudgetPerDay,
    double? miscBudgetPerDay,
    double? fuelPricePerLiter,
  }) {
    return BudgetPreferences(
      vehicleType: vehicleType ?? this.vehicleType,
      accommodationType: accommodationType ?? this.accommodationType,
      numberOfNights: numberOfNights ?? this.numberOfNights,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      maxBudget: maxBudget ?? this.maxBudget,
      foodBudgetPerDay: foodBudgetPerDay ?? this.foodBudgetPerDay,
      miscBudgetPerDay: miscBudgetPerDay ?? this.miscBudgetPerDay,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
    );
  }
}

class BudgetEstimate {
  final double fuelCost;
  final double tollCost;
  final double busCost;
  final double accommodationCost;
  final double foodCost;
  final double miscCost;
  final double totalCost;
  final BudgetBreakdown breakdown;
  double maxBudget = 0;
  
  BudgetEstimate({
    required this.fuelCost,
    required this.tollCost,
    required this.busCost,
    required this.accommodationCost,
    required this.foodCost,
    required this.miscCost,
    required this.totalCost,
    required this.breakdown,
  });
  
  String get formattedTotal => '₹${totalCost.toStringAsFixed(0)}';
  
  String get formattedFuel => '₹${fuelCost.toStringAsFixed(0)}';
  
  String get formattedToll => '₹${tollCost.toStringAsFixed(0)}';
  
  String get formattedBus => '₹${busCost.toStringAsFixed(0)}';
  
  String get formattedAccommodation => '₹${accommodationCost.toStringAsFixed(0)}';
  
  String get formattedFood => '₹${foodCost.toStringAsFixed(0)}';
  
  String get formattedMisc => '₹${miscCost.toStringAsFixed(0)}';
  
  bool isWithinBudget(double max) => totalCost <= max;
  
  double get remainingBudget => maxBudget - totalCost;
  
  double get budgetUtilization => maxBudget > 0 ? (totalCost / maxBudget) * 100 : 0;
}

class BudgetBreakdown {
  final Map<String, String> categories;
  
  BudgetBreakdown({required this.categories});
  
  String formatCategory(String key) => categories[key] ?? key;
}

class BudgetService extends ChangeNotifier {
  // Constants
  static const double defaultFuelPrice = 100.0;
  static const double tollPerKm = 0.5;
  static const double budgetAccommodationCost = 500;
  static const double midRangeAccommodationCost = 1500;
  static const double luxuryAccommodationCost = 5000;
  // NOTE: Offerings are user-dependent and not included in estimates
  
  // State
  BudgetEstimate? _currentEstimate;
  BudgetPreferences _preferences = const BudgetPreferences();
  List<Temple> _currentTemples = [];
  double _currentDistance = 0;
  bool _hasTemples = false; // Track if temples are selected
  
  // Getters
  BudgetEstimate? get currentEstimate => _currentEstimate;
  BudgetPreferences get preferences => _preferences;
  List<Temple> get currentTemples => _currentTemples;
  double get currentDistance => _currentDistance;
  bool get hasTemples => _hasTemples;
  
  /// Update preferences and recalculate
  void updatePreferences(BudgetPreferences prefs) {
    _preferences = prefs;
    if (_currentTemples.isNotEmpty) {
      recalculateBudget();
    }
  }
  
  /// Update route and recalculate budget
  void updateRoute(List<Temple> temples, double totalDistance) {
    _currentTemples = temples;
    _currentDistance = totalDistance;
    _hasTemples = temples.isNotEmpty;
    recalculateBudget();
  }
  
  /// Add a temple to the route and recalculate
  void addTemple(Temple temple) {
    _currentTemples.add(temple);
    recalculateBudget();
  }
  
  /// Remove a temple from the route and recalculate
  void removeTemple(Temple temple) {
    _currentTemples.remove(temple);
    recalculateBudget();
  }
  
  /// Recalculate budget based on current state
  void recalculateBudget() {
    // Only calculate if temples are selected
    if (_currentTemples.isEmpty || !_hasTemples) {
      _currentEstimate = null;
      notifyListeners();
      return;
    }
    
    final routeDetails = _buildRouteDetails();
    _currentEstimate = calculateBudget(
      routeDetails: routeDetails,
      preferences: _preferences,
    );
    notifyListeners();
  }
  
  DirectionsResponse _buildRouteDetails() {
    return DirectionsResponse(
      overviewPolyline: [],
      totalDistance: _currentDistance,
      totalDuration: Duration.zero,
      bounds: _calculateBounds(),
      steps: [],
      temples: _currentTemples,
    );
  }
  
  LatLngBounds _calculateBounds() {
    if (_currentTemples.isEmpty) {
      return LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
    }
    
    final lats = _currentTemples.map((t) => t.latitude).toList();
    final lngs = _currentTemples.map((t) => t.longitude).toList();
    
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
  }
  
  BudgetEstimate calculateBudget({
    required DirectionsResponse routeDetails,
    required BudgetPreferences preferences,
  }) {
    final fuelCost = _calculateFuelCost(totalDistance: routeDetails.totalDistance, preferences: preferences);
    final tollCost = _calculateTollCost(routeDetails: routeDetails, preferences: preferences);
    final busCost = _calculateBusTicketCost(totalDistance: routeDetails.totalDistance, preferences: preferences);
    final accommodationCost = _calculateAccommodationCost(nights: preferences.numberOfNights, type: preferences.accommodationType);
    final foodCost = preferences.foodBudgetPerDay * preferences.numberOfDays;
    final miscCost = preferences.miscBudgetPerDay * preferences.numberOfDays;
    // NOTE: Offerings removed - user-dependent
    final totalCost = fuelCost + tollCost + busCost + accommodationCost + foodCost + miscCost;
    
    final breakdown = BudgetBreakdown(categories: {
      'fuel': 'Fuel & Transportation',
      'toll': 'Toll Charges',
      'bus': 'Bus Ticket Fare',
      'accommodation': 'Accommodation',
      'food': 'Food & Dining',
      'misc': 'Miscellaneous & Tips',
    });
    
    final estimate = BudgetEstimate(
      fuelCost: fuelCost,
      tollCost: tollCost,
      busCost: busCost,
      accommodationCost: accommodationCost,
      foodCost: foodCost,
      miscCost: miscCost,
      totalCost: totalCost,
      breakdown: breakdown,
    );
    estimate.maxBudget = preferences.maxBudget;
    
    return estimate;
  }
  
  double _calculateBusTicketCost({required double totalDistance, required BudgetPreferences preferences}) {
    // For bus, calculate ticket fare based on distance
    if (preferences.vehicleType != VehicleType.bus) return 0;
    
    // Use the estimateBusFare method for bus ticket cost
    final busFare = LivePriceEstimator.estimateBusFare(totalDistance);
    return busFare.min; // Use minimum fare as estimate
  }
  
  double _calculateFuelCost({required double totalDistance, required BudgetPreferences preferences}) {
    // Bus is public transport - no fuel cost, only ticket costs
    if (preferences.vehicleType == VehicleType.bus) return 0;
    final mileage = preferences.defaultMileage;
    if (mileage == double.infinity) return 0;
    return (totalDistance / mileage) * preferences.fuelPricePerLiter;
  }
  
  double _calculateTollCost({required DirectionsResponse routeDetails, required BudgetPreferences preferences}) {
    // Bus has higher toll rate
    final tollRate = preferences.vehicleType == VehicleType.bus ? 1.0 : tollPerKm;
    return routeDetails.totalDistance * 0.1 * tollRate;
  }
  
  double _calculateAccommodationCost({required int nights, required AccommodationType type}) {
    final costPerNight = switch (type) {
      AccommodationType.budget => budgetAccommodationCost,
      AccommodationType.midRange => midRangeAccommodationCost,
      AccommodationType.luxury => luxuryAccommodationCost,
      AccommodationType.none => 0,
    };
    return costPerNight * nights.toDouble();
  }
  
  /// Calculate cost comparison for all vehicle types
  Map<VehicleType, VehicleCostComparison> calculateCostByVehicleType({
    required double totalDistance,
    required BudgetPreferences preferences,
    int templeCount = 1,
  }) {
    final comparisons = <VehicleType, VehicleCostComparison>{};
    
    for (final type in VehicleType.values) {
      final prefs = preferences.copyWith(vehicleType: type);
      final estimate = calculateBudget(
        routeDetails: _emptyRoute(totalDistance),
        preferences: prefs,
      );
      
      comparisons[type] = VehicleCostComparison(
        vehicleType: type,
        totalCost: estimate.totalCost,
        fuelCost: estimate.fuelCost,
        tollCost: estimate.tollCost,
        timeEstimate: _estimateTravelTime(totalDistance, type),
      );
    }
    
    return comparisons;
  }
  
  /// Estimate travel time based on vehicle type
  Duration _estimateTravelTime(double distanceKm, VehicleType type) {
    final speedKmh = switch (type) {
      VehicleType.car => 50.0,
      VehicleType.bike => 45.0,
      VehicleType.bus => 40.0,
    };
    return Duration(minutes: (distanceKm / speedKmh * 60).round());
  }
  
  DirectionsResponse _emptyRoute(double totalDistance) {
    return DirectionsResponse(
      overviewPolyline: [],
      totalDistance: totalDistance,
      totalDuration: Duration.zero,
      bounds: LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0)),
      steps: [],
      temples: [],
    );
  }
  
  /// Get formatted cost summary for display
  String getCostSummary() {
    if (_currentEstimate == null) return 'No route planned';
    return 'Total: ${_currentEstimate!.formattedTotal}';
  }
  
  /// Get budget status (under, near, over)
  BudgetStatus getBudgetStatus() {
    if (_currentEstimate == null) return BudgetStatus.none;
    final utilization = _currentEstimate!.budgetUtilization;
    if (utilization >= 100) return BudgetStatus.over;
    if (utilization >= 80) return BudgetStatus.near;
    return BudgetStatus.under;
  }
}

enum BudgetStatus { none, under, near, over }

class VehicleCostComparison {
  final VehicleType vehicleType;
  final double totalCost;
  final double fuelCost;
  final double tollCost;
  final Duration timeEstimate;
  
  VehicleCostComparison({
    required this.vehicleType,
    required this.totalCost,
    required this.fuelCost,
    required this.tollCost,
    required this.timeEstimate,
  });
  
  String get formattedCost => '₹${totalCost.toStringAsFixed(0)}';
  
  String get formattedTime {
    final hours = timeEstimate.inHours;
    final minutes = timeEstimate.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
  
  String get vehicleName => switch (vehicleType) {
    VehicleType.car => 'Car',
    VehicleType.bike => 'Bike',
    VehicleType.bus => 'Bus',
  };
}

/// Live price estimation based on location and current market rates
class LivePriceEstimator {
  // Base prices (can be updated from API in future)
  static const double baseFuelPrice = 100.0; // ₹/L
  static const double tollPerKm = 0.5; // ₹/km
  
  // Hyderabad region accommodation estimates
  static const Map<AccommodationType, PriceRange> accommodationRanges = {
    AccommodationType.budget: PriceRange(min: 300, max: 800, label: 'Budget Hotels'),
    AccommodationType.midRange: PriceRange(min: 800, max: 2000, label: 'Mid-Range Hotels'),
    AccommodationType.luxury: PriceRange(min: 2000, max: 8000, label: 'Luxury Hotels'),
    AccommodationType.none: PriceRange(min: 0, max: 0, label: 'No Accommodation'),
  };
  
  // Food estimates per meal
  static const PriceRange foodPerMeal = PriceRange(min: 50, max: 300, label: 'Per Meal');
  
  // Bus fare estimates (per km for inter-city)
  static const double busFarePerKm = 2.0; // ₹/km
  
  /// Get estimated accommodation range for given nights
  static PriceRange estimateAccommodation(int nights, AccommodationType type) {
    final range = accommodationRanges[type]!;
    return PriceRange(
      min: range.min * nights,
      max: range.max * nights,
      label: range.label,
    );
  }
  
  /// Get estimated food cost for given days
  static PriceRange estimateFood(int days, int mealsPerDay) {
    return PriceRange(
      min: foodPerMeal.min * mealsPerDay * days,
      max: foodPerMeal.max * mealsPerDay * days,
      label: '$mealsPerDay meals/day for $days days',
    );
  }
  
  /// Get estimated bus fare for given distance
  static PriceRange estimateBusFare(double distanceKm) {
    // Government buses are cheaper, private AC buses are more expensive
    final governmentBus = distanceKm * 1.5; // ₹/km
    final privateBus = distanceKm * 3.0; // ₹/km
    return PriceRange(
      min: governmentBus.roundToDouble(),
      max: privateBus.roundToDouble(),
      label: 'Bus Fare (Govt to Private)',
    );
  }
  
  /// Estimate total trip cost with ranges
  static TripCostEstimate estimateTripCost({
    required double distanceKm,
    required VehicleType vehicleType,
    required AccommodationType accommodationType,
    required int numberOfNights,
    required int numberOfDays,
    int mealsPerDay = 3,
  }) {
    // Fuel/travel cost
    final travelCostRange = switch (vehicleType) {
      VehicleType.car => PriceRange(
          min: distanceKm / 15 * baseFuelPrice,
          max: distanceKm / 15 * baseFuelPrice * 1.2, // 20% variation
          label: 'Fuel',
        ),
      VehicleType.bike => PriceRange(
          min: distanceKm / 50 * baseFuelPrice,
          max: distanceKm / 50 * baseFuelPrice * 1.2,
          label: 'Fuel',
        ),
      VehicleType.bus => estimateBusFare(distanceKm),
    };
    
    // Toll cost
    final toll = distanceKm * 0.1 * tollPerKm;
    
    // Accommodation cost
    final accommodation = estimateAccommodation(numberOfNights, accommodationType);
    
    // Food cost
    final food = estimateFood(numberOfDays, mealsPerDay);
    
    // Total range
    final totalMin = travelCostRange.min + toll + accommodation.min + food.min;
    final totalMax = travelCostRange.max + toll + accommodation.max + food.max;
    
    return TripCostEstimate(
      travelCost: travelCostRange,
      tollCost: toll,
      accommodationCost: accommodation,
      foodCost: food,
      totalMin: totalMin,
      totalMax: totalMax,
    );
  }
}

/// Price range for estimates
class PriceRange {
  final double min;
  final double max;
  final String label;
  
  const PriceRange({
    required this.min,
    required this.max,
    required this.label,
  });
  
  String get formatted => '₹${min.round()} - ₹${max.round()}';
  
  double get average => (min + max) / 2;
}

/// Complete trip cost estimate with ranges
class TripCostEstimate {
  final dynamic travelCost; // double or PriceRange
  final double tollCost;
  final PriceRange accommodationCost;
  final PriceRange foodCost;
  final double totalMin;
  final double totalMax;
  
  TripCostEstimate({
    required this.travelCost,
    required this.tollCost,
    required this.accommodationCost,
    required this.foodCost,
    required this.totalMin,
    required this.totalMax,
  });
  
  String get formattedTotal => '₹${totalMin.round()} - ₹${totalMax.round()}';
  
  String get formattedTravel => travelCost is PriceRange 
      ? travelCost.formatted 
      : '₹${travelCost.round()}';
}
