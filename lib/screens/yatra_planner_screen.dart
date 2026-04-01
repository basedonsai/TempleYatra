// Yatra planner screen with proper temple selection and itinerary generation
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/temple_model.dart';
import '../services/itinerary_generator.dart';
import '../services/crowd_engine.dart';
import '../providers/festival_provider.dart';
import '../widgets/crowd_badge.dart';
import '../database/db_providers.dart';
import 'route_planner_screen.dart';

class YatraPlannerScreen extends ConsumerStatefulWidget {
  final Temple? preselectedTemple;
  const YatraPlannerScreen({super.key, this.preselectedTemple});

  @override
  ConsumerState<YatraPlannerScreen> createState() => _YatraPlannerScreenState();
}

class _YatraPlannerScreenState extends ConsumerState<YatraPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Use actual Temple objects instead of String names
  final List<Temple> _selectedTemples = [];

  // Constraints
  DateTime? _startDate;
  DateTime? _endDate;
  double _budget = 0;
  String _travelMode = 'Car';
  int _numberOfDays = 1;
  int _templesPerDay = 3;

  @override
  void initState() {
    super.initState();
    // Pre-select temple if passed from TempleDetailScreen
    if (widget.preselectedTemple != null) {
      _selectedTemples.add(widget.preselectedTemple!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templesAsync = ref.watch(allTemplesDbProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Yatra'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Your Personalized Yatra',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              
              // Date Range Selection
              _buildDateRangeSelector(),
              const SizedBox(height: 16),
              
              // Budget Input
              _buildBudgetSelector(),
              const SizedBox(height: 16),
              
              // Travel Mode
              _buildTravelModeSelector(),
              const SizedBox(height: 16),
              
              // Number of Days
              _buildDaysSelector(),
              const SizedBox(height: 16),
              
              // Temples per day
              _buildTemplesPerDaySelector(),
              const SizedBox(height: 24),
              
              // Select Temples Section
              Text(
                'Select Temples to Visit (${_selectedTemples.length} selected)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              // Temple selection chips
              templesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading temples: $e'),
                data: (availableTemples) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTemples.map((temple) {
                        final isSelected = _selectedTemples.contains(temple);
                        return FilterChip(
                          label: Text(temple.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTemples.add(temple);
                              } else {
                                _selectedTemples.remove(temple);
                              }
                            });
                          },
                          selectedColor: AppTheme.saffron.withValues(alpha: 0.3),
                          checkmarkColor: AppTheme.maroon,
                          avatar: _TempleCrowdAvatar(
                            templeId: temple.id,
                            date: _startDate ?? DateTime.now(),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Quick actions
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _selectAllTemples(availableTemples),
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () => _clearSelection(),
                          child: const Text('Clear All'),
                        ),
                        TextButton(
                          onPressed: () => _selectTopRated(availableTemples),
                          child: const Text('Top Rated'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Generate Itinerary Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedTemples.isEmpty ? null : _generateItinerary,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Generate Optimized Itinerary'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Reoptimize Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _selectedTemples.isEmpty ? null : _generateItinerary,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Reoptimize Itinerary'),
                ),
              ),
              

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppTheme.maroon),
                const SizedBox(width: 8),
                Text(
                  _startDate != null && _endDate != null
                      ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                      : 'Select Trip Dates',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range),
              label: const Text('Choose Dates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSelector() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Budget (₹)',
        hintText: 'Enter your maximum budget',
        prefixIcon: Icon(Icons.currency_rupee),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      initialValue: _budget > 0 ? _budget.toString() : '',
      onChanged: (value) {
        setState(() {
          _budget = double.tryParse(value) ?? 0;
        });
      },
      onSaved: (value) => _budget = double.tryParse(value ?? '') ?? 0,
    );
  }

  Widget _buildTravelModeSelector() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Travel Mode',
        prefixIcon: Icon(Icons.directions_car),
        border: OutlineInputBorder(),
      ),
      initialValue: _travelMode,
      items: ['Car', 'Bus', 'Train', 'Flight', 'Bike'].map((mode) {
        IconData icon;
        switch (mode) {
          case 'Car': icon = Icons.directions_car; break;
          case 'Bus': icon = Icons.directions_bus; break;
          case 'Train': icon = Icons.train; break;
          case 'Flight': icon = Icons.flight; break;
          case 'Bike': icon = Icons.motorcycle; break;
          default: icon = Icons.directions_car;
        }
        return DropdownMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(mode),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _travelMode = value ?? 'Car';
        });
      },
    );
  }

  Widget _buildDaysSelector() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
        labelText: 'Number of Days',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
      ),
      initialValue: _numberOfDays,
      items: List.generate(10, (index) => index + 1).map((days) {
        return DropdownMenuItem(
          value: days,
          child: Text('$days day${days > 1 ? 's' : ''}'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _numberOfDays = value ?? 1;
          // Auto-adjust temples per day based on total temples
          if (_selectedTemples.length > _numberOfDays * 3) {
            _templesPerDay = (_selectedTemples.length / _numberOfDays).ceil();
          }
        });
      },
    );
  }

  Widget _buildTemplesPerDaySelector() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
        labelText: 'Temples per Day',
        prefixIcon: Icon(Icons.temple_hindu),
        border: OutlineInputBorder(),
      ),
      initialValue: _templesPerDay,
      items: [1, 2, 3, 4, 5].map((count) {
        return DropdownMenuItem(
          value: count,
          child: Text('$count temple${count > 1 ? 's' : ''}'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _templesPerDay = value ?? 3;
        });
      },
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.maroon,
              onPrimary: Colors.white,
              secondary: AppTheme.saffron,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _numberOfDays = range.end.difference(range.start).inDays + 1;
      });
    }
  }

  void _selectAllTemples(List<Temple> availableTemples) {
    setState(() {
      _selectedTemples.clear();
      _selectedTemples.addAll(availableTemples);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTemples.clear();
    });
  }

  void _selectTopRated(List<Temple> availableTemples) {
    setState(() {
      _selectedTemples.clear();
      final sorted = List<Temple>.from(availableTemples)
        ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      _selectedTemples.addAll(sorted.take(5));
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _generateItinerary() {
    // Create constraints
    final constraints = ItineraryConstraints(
      startDate: _startDate,
      endDate: _endDate,
      maxBudget: _budget > 0 ? _budget : null,
      maxDays: _numberOfDays,
      maxTemplesPerDay: _templesPerDay,
      travelMode: _travelMode,
    );
    
    // Generate itinerary
    final generator = ItineraryGenerator(
      availableTemples: _selectedTemples,
      constraints: constraints,
    );
    
    final itinerary = generator.generate();
    
    // Show warnings if any
    if (itinerary.warnings.isNotEmpty) {
      for (final warning in itinerary.warnings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning), backgroundColor: Colors.orange),
        );
      }
    }
    
    // Convert to selected temples for route planner
    final List<Temple> routeTemples = [];
    for (final day in itinerary.dayPlans) {
      for (final visit in day.visits) {
        if (!routeTemples.contains(visit.temple)) {
          routeTemples.add(visit.temple);
        }
      }
    }
    
    // Navigate to route planner
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutePlannerScreen(
          selectedTemples: routeTemples,
          itinerary: itinerary,
        ),
      ),
    );
  }
}

/// Isolated ConsumerWidget for crowd avatar — only this rebuilds on festival changes,
/// not the entire temple chip Wrap.
class _TempleCrowdAvatar extends ConsumerWidget {
  final String templeId;
  final DateTime date;
  const _TempleCrowdAvatar({required this.templeId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(templeFestivalsProvider(templeId));
    final level = computeCrowdLevel(templeId, date, events);
    return CrowdBadge(level: level, compact: true);
  }
}
