// Temple list screen showing all temples
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/temples_data.dart';
import '../models/temple_model.dart';
import '../utils/distance_calculator.dart';
import '../widgets/crowd_badge.dart';
import '../providers/festival_provider.dart';
import '../services/crowd_engine.dart';
import 'temple_detail_screen.dart';


class TempleListScreen extends StatefulWidget {
  const TempleListScreen({super.key});

  @override
  State<TempleListScreen> createState() => _TempleListScreenState();
}

class _TempleListScreenState extends State<TempleListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  final List<String> _filters = [
    'All',
    'Featured',
    'Nearby',
    'Favorites',
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTemples = _getFilteredTemples();
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Temples', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF8B0000),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search temples...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter, style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                      )),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF9933),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Temple list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTemples.length,
              itemBuilder: (context, index) {
                final temple = filteredTemples[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TempleCard(temple: temple),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Temple> _getFilteredTemples() {
    var temples = List<Temple>.from(allTemples);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      temples = temples.where((temple) {
        return temple.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            temple.address.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply category filter
    switch (_selectedFilter) {
      case 'Nearby':
        // Sort by distance from center of Hyderabad
        temples.sort((a, b) {
          final distA = calculateDistance(17.3850, 78.4867, a.latitude, a.longitude);
          final distB = calculateDistance(17.3850, 78.4867, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
        break;
      case 'Featured':
        // Show temples with higher ratings first
        temples.sort((a, b) {
          final ratingA = a.rating ?? 0;
          final ratingB = b.rating ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      default:
        break;
    }
    
    return temples;
  }
}

class _TempleCard extends StatelessWidget {
  final Temple temple;

  const _TempleCard({required this.temple});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TempleDetailScreen(temple: temple),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temple image
            Container(
              height: isSmallScreen ? 140 : 160,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF9933), Color(0xFFE67300)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Stack(
                children: [
                  // Center icon
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.temple_hindu,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Crowd badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final events = ref.watch(templeFestivalsProvider(temple.id));
                        final level = computeCrowdLevel(temple.id, DateTime.now(), events);
                        return CrowdBadge(level: level);
                      },
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[400],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            temple.rating?.toStringAsFixed(1) ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Temple info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    temple.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          temple.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      temple.darshanTimings.split('-').first.trim(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
