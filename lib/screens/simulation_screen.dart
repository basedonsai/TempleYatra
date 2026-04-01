// Enhanced simulation screen with Google Maps for dynamic yatra rerouting
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/temple_model.dart';
import '../services/simulation_controller.dart';
import 'temple_detail_screen.dart';

class SimulationScreen extends StatefulWidget {
  final List<Temple> initialRoute;

  const SimulationScreen({super.key, required this.initialRoute});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  late SimulationController _controller;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _controller = SimulationController()..initializeRoute(widget.initialRoute);
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _updateMapBounds();
  }

  void _updateMapBounds() {
    if (_mapController == null || _controller.currentRoute.isEmpty) return;
    if (_controller.currentRoute.length >= 2) {
      _fitMapToRoute();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yatra Simulation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.resetSimulation,
            tooltip: 'Reset',
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showStatistics,
            tooltip: 'Statistics',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                if (_controller.isSimulating && _controller.currentRoute.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildCurrentTempleCard(),
                  ),
              ],
            ),
          ),
          _buildRouteList(),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final stats = _controller.getStatistics();
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(Icons.check_circle, 'Visited', '${stats.visitedCount}/${stats.totalTemples}', Colors.green),
          _buildStatusItem(Icons.skip_next, 'Skipped', '${stats.skippedCount}', Colors.orange),
          _buildStatusItem(Icons.schedule, 'Duration', stats.formattedDuration, Colors.blue),
          _buildStatusItem(Icons.route, 'Distance', stats.formattedDistance, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(target: _getCenter(), zoom: 11),
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToRoute();
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  LatLng _getCenter() {
    if (widget.initialRoute.isEmpty) return const LatLng(17.3850, 78.4867);
    final avgLat = widget.initialRoute.map((t) => t.latitude).reduce((a, b) => a + b) / widget.initialRoute.length;
    final avgLng = widget.initialRoute.map((t) => t.longitude).reduce((a, b) => a + b) / widget.initialRoute.length;
    return LatLng(avgLat, avgLng);
  }

  void _fitMapToRoute() {
    if (_mapController == null || widget.initialRoute.isEmpty) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        widget.initialRoute.map((t) => t.latitude).reduce((a, b) => a < b ? a : b) - 0.02,
        widget.initialRoute.map((t) => t.longitude).reduce((a, b) => a < b ? a : b) - 0.02,
      ),
      northeast: LatLng(
        widget.initialRoute.map((t) => t.latitude).reduce((a, b) => a > b ? a : b) + 0.02,
        widget.initialRoute.map((t) => t.longitude).reduce((a, b) => a > b ? a : b) + 0.02,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (int i = 0; i < _controller.currentRoute.length; i++) {
      final temple = _controller.currentRoute[i];
      markers.add(
        Marker(
          markerId: MarkerId('temple_$i'),
          position: LatLng(temple.latitude, temple.longitude),
          infoWindow: InfoWindow(
            title: temple.name,
            snippet: '${i + 1}. ${temple.address}',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TempleDetailScreen(temple: temple))),
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_controller.currentRoute.length < 2) return {};
    final points = _controller.currentRoute.map((t) => LatLng(t.latitude, t.longitude)).toList();
    return {
      Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.orange, width: 5),
    };
  }

  Widget _buildCurrentTempleCard() {
    if (_controller.currentRoute.isEmpty) return const SizedBox.shrink();
    final current = _controller.currentRoute.first;
    final arrivalTime = _controller.getEstimatedArrival(current);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle), child: const Icon(Icons.location_on, color: Colors.green)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current: ${current.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (arrivalTime != null) Text('Est. arrival: ${_formatTime(arrivalTime)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _controller.skipCurrentTemple();
              _showSkipFeedback();
            },
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text('Skip'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[100], foregroundColor: Colors.orange[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
          const Text('Route Order', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(_controller.statusMessage, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ])),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _controller.currentRoute.length,
            itemBuilder: (context, index) {
              final temple = _controller.currentRoute[index];
              final isCurrent = index == 0;
              final arrivalTime = _controller.getEstimatedArrival(temple);
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCurrent ? Colors.green : Colors.transparent, width: 2),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: isCurrent ? Colors.green : Colors.orange, shape: BoxShape.circle), child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
                      const Spacer(),
                      if (isCurrent) const Icon(Icons.play_arrow, color: Colors.green, size: 16),
                    ]),
                    const SizedBox(height: 6),
                    Text(temple.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    const SizedBox(height: 4),
                    if (arrivalTime != null) Text(_formatTime(arrivalTime), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    TextButton.icon(
                      onPressed: isCurrent
                        ? () { _controller.skipCurrentTemple(); _showSkipFeedback(); }
                        : () { _controller.skipTempleAtIndex(index); _showSkipFeedback(); },
                      icon: const Icon(Icons.skip_next, size: 14),
                      label: const Text('Skip', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _controller.isSimulating
                    ? (_controller.isPaused ? _controller.resumeSimulation : _controller.pauseSimulation)
                    : _controller.startSimulation,
                icon: Icon(_controller.isPaused
                    ? Icons.play_arrow
                    : (_controller.isSimulating ? Icons.pause : Icons.play_arrow)),
                label: Text(_controller.isPaused
                    ? 'Resume'
                    : (_controller.isSimulating ? 'Pause' : 'Start')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _controller.isSimulating
                      ? (_controller.isPaused ? Colors.green : Colors.orange)
                      : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _controller.resetSimulation,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              if (_controller.currentRoute.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _openInGoogleMaps(_controller.currentRoute.first),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Speed:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _controller.simulationSpeed,
                onChanged: (value) {
                  if (value != null) _controller.setSimulationSpeed(value);
                },
                items: [1, 2, 5, 10]
                    .map((speed) => DropdownMenuItem(
                          value: speed,
                          child: Text('${speed}x'),
                        ))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Open Google Maps navigation to a temple
  Future<void> _openInGoogleMaps(Temple temple) async {
    final url = Uri.parse('google.navigation:q=${temple.latitude},${temple.longitude}&mode=d');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to Google Maps web URL
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${temple.latitude},${temple.longitude}&travelmode=driving');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open navigation')),
          );
        }
      }
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _showSkipFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_controller.statusMessage),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showStatistics() {
    final stats = _controller.getStatistics();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulation Statistics'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStatRow('Total Temples', '${stats.totalTemples}'),
          _buildStatRow('Visited', '${stats.visitedCount}'),
          _buildStatRow('Skipped', '${stats.skippedCount}'),
          _buildStatRow('Remaining', '${stats.remainingCount}'),
          const Divider(),
          _buildStatRow('Total Distance', stats.formattedDistance),
          _buildStatRow('Total Duration', stats.formattedDuration),
          const Divider(),
          LinearProgressIndicator(value: stats.completionPercentage / 100, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
          const SizedBox(height: 8),
          Text('Completion: ${stats.completionPercentage.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
  }
}
