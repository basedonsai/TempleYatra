// Temple list screen showing all temples
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_providers.dart';
import '../models/temple_model.dart';
import '../utils/distance_calculator.dart';
import '../widgets/crowd_badge.dart';
import '../providers/festival_provider.dart';
import '../models/festival_event.dart';
import '../services/crowd_engine.dart';
import 'temple_detail_screen.dart';


class TempleListScreen extends ConsumerStatefulWidget {
  final String initialFilter;

  const TempleListScreen({super.key, this.initialFilter = 'All'});

  @override
  ConsumerState<TempleListScreen> createState() => _TempleListScreenState();
}

class _TempleListScreenState extends ConsumerState<TempleListScreen> {
  String _searchQuery = '';
  late String _selectedFilter;
  String? _selectedState;
  bool _showAll = false;

  final List<String> _filters = ['All', 'Popular', 'By State', 'Nearby'];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final templesAsync = ref.watch(allTemplesDbProvider);
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
                  _showAll = false;
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
                          _selectedState = null;
                          _showAll = false;
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

          // State picker row (shown only when filter == 'By State')
          if (_selectedFilter == 'By State')
            templesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (allTemples) {
                final states = allTemples
                    .map((t) => t.region ?? '')
                    .where((r) => r.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                if (states.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Colors.grey[50],
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: states.length,
                      itemBuilder: (context, index) {
                        final state = states[index];
                        final isSelected = _selectedState == state;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(state, style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                            )),
                            selected: isSelected,
                            selectedColor: const Color(0xFF800020),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedState = selected ? state : null;
                                _showAll = false;
                              });
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 8),

          // Temple list
          Expanded(
            child: templesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error loading temples: $error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (allTemples) {
                final filteredTemples = _getFilteredTemples(allTemples);
                final displayTemples = (!_showAll && filteredTemples.length > 8)
                    ? filteredTemples.take(8).toList()
                    : filteredTemples;
                final hasMore = !_showAll && filteredTemples.length > 8;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayTemples.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayTemples.length) {
                      // "View All" button
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showAll = true),
                          child: Text('View All (${filteredTemples.length} temples)'),
                        ),
                      );
                    }
                    final temple = displayTemples[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TempleCard(temple: temple),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Temple> _getFilteredTemples(List<Temple> source) {
    var temples = List<Temple>.from(source);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      temples = temples.where((temple) {
        return temple.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            temple.address.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply category filter
    switch (_selectedFilter) {
      case 'Popular':
        temples.sort((a, b) {
          final ratingA = a.rating ?? 0;
          final ratingB = b.rating ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case 'Nearby':
        temples.sort((a, b) {
          final distA = calculateDistance(17.3850, 78.4867, a.latitude, a.longitude);
          final distB = calculateDistance(17.3850, 78.4867, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
        break;
      case 'By State':
        if (_selectedState != null) {
          temples = temples.where((t) => t.region == _selectedState).toList();
        }
        break;
      default:
        break;
    }

    return temples;
  }
}

// Fix 1: Extract crowd badge into its own ConsumerWidget so only the badge
// rebuilds on festival data changes, not the entire card.
class _TempleCrowdBadge extends ConsumerWidget {
  final String templeId;
  const _TempleCrowdBadge({required this.templeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(templeFestivalsDbProvider(templeId)).when(
      loading: () => CrowdLevel.low,
      error: (_, __) => CrowdLevel.low,
      data: (events) => computeCrowdLevel(templeId, DateTime.now(), events),
    );
    return CrowdBadge(level: level);
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
                    child: _TempleCrowdBadge(templeId: temple.id),
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
