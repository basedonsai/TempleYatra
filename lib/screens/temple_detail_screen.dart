import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/temple_model.dart';
import '../utils/distance_calculator.dart';
import 'storytelling_screen.dart';
import 'chatbot_screen.dart';
import '../theme/app_theme.dart';

class TempleDetailScreen extends StatelessWidget {
  final Temple temple;

  const TempleDetailScreen({super.key, required this.temple});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final expandedHeight = isSmallScreen ? 200.0 : 250.0;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: expandedHeight,
              pinned: true,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  temple.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.orange[400]!,
                        Colors.orange[700]!,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.temple_hindu,
                      size: isSmallScreen ? 80 : 100,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rating and distance
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        temple.rating?.toStringAsFixed(1) ?? 'N/A',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${temple.userRatingsTotal ?? 0})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  _getDistanceText(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        
                        // Address
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                temple.address,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Timings
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                temple.darshanTimings,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 18),
                        
                        // Quick actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openDirections(),
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('Directions', style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: temple.phoneNumber != null
                                    ? () => _makeCall()
                                    : null,
                                icon: const Icon(Icons.phone, size: 18),
                                label: const Text('Call', style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // About section
                        _buildSection(
                          title: 'About',
                          icon: Icons.info,
                          children: [
                            Text(
                              temple.distinctiveFeatures,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                              ),
                              maxLines: isSmallScreen ? 4 : 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StorytellingScreen(
                                        templeId: temple.id,
                                        temple: temple,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.record_voice_over, size: 18),
                                label: const Text('Listen to Temple Stories', style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[50],
                                  foregroundColor: Colors.orange[800],
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 14),
                        
                        // Festivals
                        _buildSection(
                          title: 'Festivals',
                          icon: Icons.celebration,
                          children: [
                            Text(
                              temple.festivals,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 14),
                        
                        // Opening Hours
                        _buildSection(
                          title: 'Darshan Timings',
                          icon: Icons.schedule,
                          children: [
                            Text(
                              temple.darshanTimings,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Add to itinerary button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${temple.name} to your yatra'),
                                  action: SnackBarAction(
                                    label: 'View',
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add to Yatra', style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button for Chatbot
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 16, bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatbotScreen(initialTemple: temple),
              ),
            );
          },
          backgroundColor: AppTheme.saffron,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.chat, size: 20),
          label: const Text('Ask AI', style: TextStyle(fontSize: 13)),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  String _getDistanceText() {
    final distance = calculateDistance(
      17.3850, 78.4867, // Hyderabad center
      temple.latitude, temple.longitude,
    );
    return formatDistance(distance);
  }

  Future<void> _openDirections() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${temple.latitude},${temple.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall() async {
    if (temple.phoneNumber != null) {
      final url = Uri.parse('tel:${temple.phoneNumber}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }
}
