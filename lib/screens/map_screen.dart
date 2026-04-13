// Interactive map screen showing all temples using Google Maps
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../database/db_providers.dart';
import '../models/temple_model.dart';
import '../services/directions_service.dart';
import 'temple_detail_screen.dart';
import 'route_planner_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  final List<Temple> _selectedTemples = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final DirectionsService _directionsService;
  DirectionsResponse? _directionsResponse;
  bool _isLoadingRoute = false;
  int _routeRequestId = 0;
  bool _markersLoaded = false;

  _MapScreenState()
      : _directionsService = DirectionsService(
            apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
          );

  @override
  void initState() {
    super.initState();
    // _loadTempleMarkersFromList is called from build once allTemplesDbProvider resolves
  }

  void _loadTempleMarkersFromList(List<Temple> temples) {
    // Build markers from the provided list — called once when provider data arrives
    for (int i = 0; i < temples.length; i++) {
      final temple = temples[i];
      _markers.add(
        Marker(
          markerId: MarkerId(temple.id),
          position: LatLng(temple.latitude, temple.longitude),
          infoWindow: InfoWindow(
            title: temple.name,
            snippet: temple.address,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TempleDetailScreen(temple: temple)),
            ),
          ),
          onTap: () => _toggleTempleSelection(temple),
        ),
      );
    }
    setState(() {});
    _fitAllTemples(temples);
  }

  void _toggleTempleSelection(Temple temple) {
    setState(() {
      if (_selectedTemples.contains(temple)) {
        _selectedTemples.remove(temple);
      } else {
        _selectedTemples.add(temple);
      }
      _updateRoutePolyline();
    });
  }

  void _updateRoutePolyline() async {
    // Cancellation token: increment so any in-flight request becomes stale.
    _routeRequestId++;
    final requestId = _routeRequestId;

    if (_selectedTemples.length >= 2) {
      // Try to fetch actual road-based route from Directions API.
      setState(() {
        _isLoadingRoute = true;
      });

      DirectionsResponse? response;
      try {
        response = await _directionsService.getRouteBetweenTemples(
          origin: LatLng(_selectedTemples.first.latitude, _selectedTemples.first.longitude),
          destination: LatLng(_selectedTemples.last.latitude, _selectedTemples.last.longitude),
          waypoints: _selectedTemples.sublist(1, _selectedTemples.length - 1)
              .map((t) => LatLng(t.latitude, t.longitude))
              .toList(),
        );
      } catch (e) {
        debugPrint('Error fetching directions: $e');
        response = null;
      }

      // Discard stale response if a newer request has been issued.
      if (requestId != _routeRequestId) return;

      _directionsResponse = response;

      setState(() {
        _isLoadingRoute = false;
      });

      // Use actual road-based route if available, otherwise fallback to straight lines.
      final List<LatLng> routePoints;
      if (_directionsResponse != null && _directionsResponse!.overviewPolyline.isNotEmpty) {
        routePoints = _directionsResponse!.overviewPolyline;
      } else {
        routePoints = _selectedTemples.map((t) => LatLng(t.latitude, t.longitude)).toList();
      }

      // Atomically replace the old polyline now that the new data has arrived.
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('selected_route'),
          points: routePoints,
          color: Colors.orange,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    } else {
      // Fewer than 2 temples selected — clear any existing polyline.
      setState(() {
        _polylines.clear();
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templesAsync = ref.watch(allTemplesDbProvider);

    // When data arrives for the first time, load markers via postFrameCallback
    templesAsync.whenData((temples) {
      if (!_markersLoaded) {
        _markersLoaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadTempleMarkersFromList(temples);
        });
      }
    });

    final temples = templesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temple Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.route),
            onPressed: _selectedTemples.length >= 2
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutePlannerScreen(selectedTemples: _selectedTemples),
                      ),
                    )
                : null,
            tooltip: 'Plan Route',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(target: LatLng(17.3850, 78.4867), zoom: 11),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              // Fit temples if data is already available when map is created
              if (temples.isNotEmpty) {
                _fitAllTemples(temples);
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: true,
          ),
          if (_selectedTemples.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Row(children: [
                  if (_isLoadingRoute)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_isLoadingRoute)
                    const SizedBox(width: 8),
                  Text('${_selectedTemples.length} temples selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _selectedTemples.clear()), child: const Text('Clear')),
                  ElevatedButton.icon(
                    onPressed: _selectedTemples.length >= 2
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RoutePlannerScreen(selectedTemples: _selectedTemples)),
                            )
                        : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Plan Route'),
                  ),
                ]),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.1,
            maxChildSize: 0.4,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: templesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading temples: $e')),
                  data: (temples) => Column(children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const Text('All Temples', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${temples.length} temples', style: TextStyle(color: Colors.grey[600])),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: temples.length,
                        itemBuilder: (context, index) {
                          final temple = temples[index];
                          final isSelected = _selectedTemples.contains(temple);
                          return GestureDetector(
                            onTap: () {
                              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(temple.latitude, temple.longitude), 14));
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orange[100] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? Colors.orange : Colors.transparent, width: 2),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.temple_hindu, color: isSelected ? Colors.orange : Colors.grey),
                                const SizedBox(height: 4),
                                Text(temple.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                const SizedBox(height: 2),
                                Text(temple.rating?.toStringAsFixed(1) ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
          child: const Icon(Icons.remove),
        ),
      ]),
    );
  }

  void _goToCurrentLocation() {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(17.3850, 78.4867), 12));
  }

  void _fitAllTemples(List<Temple> temples) {
    if (temples.isEmpty) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        temples.map((t) => t.latitude).reduce((a, b) => a < b ? a : b) - 0.02,
        temples.map((t) => t.longitude).reduce((a, b) => a < b ? a : b) - 0.02,
      ),
      northeast: LatLng(
        temples.map((t) => t.latitude).reduce((a, b) => a > b ? a : b) + 0.02,
        temples.map((t) => t.longitude).reduce((a, b) => a > b ? a : b) + 0.02,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }
}
