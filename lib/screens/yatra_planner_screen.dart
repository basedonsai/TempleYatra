import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/temple_model.dart';
import '../models/festival_event.dart';
import '../services/itinerary_generator.dart';
import '../services/budget_service.dart';
import '../services/crowd_engine.dart';
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
  final List<Temple> _selectedTemples = [];

  // Basic trip details
  DateTime? _startDate;
  DateTime? _endDate;
  double _budget = 0;
  String _travelMode = 'Car';
  int _numberOfDays = 1;
  int _templesPerDay = 3;

  // New inputs
  int _startHour = 6;
  int _startMinute = 0;
  DarshanStyle _darshanStyle = DarshanStyle.standard;
  bool _avoidHighways = false;
  int _groupSize = 1;
  AccommodationPref _accommodation = AccommodationPref.none;
  int _numberOfNights = 0;
  double _foodBudgetPerDay = 500;
  double _fuelPrice = 100;

  // Wizard state
  int _step = 1;
  String? _regionFilter; // null = All India, 'Nearby' = by distance, else = state name
  String? _deityFilter;  // null = no preference, else = deity keyword

  @override
  void initState() {
    super.initState();
    if (widget.preselectedTemple != null) {
      _selectedTemples.add(widget.preselectedTemple!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templesAsync = ref.watch(allTemplesDbProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightBeige,
      appBar: AppBar(
        title: const Text('Plan Your Yatra'),
        leading: _step > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: templesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (temples) {
                return switch (_step) {
                  1 => _buildStep1(temples),
                  2 => _buildStep2(),
                  3 => _buildStep3(),
                  4 => _buildStep4(temples),
                  _ => _buildStep1(temples),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['Region', 'Duration', 'Deity', 'Plan'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(4, (i) {
          final stepNum = i + 1;
          final isActive = _step == stepNum;
          final isDone = _step > stepNum;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppTheme.maroon
                              : isActive
                                  ? AppTheme.saffron
                                  : AppTheme.softGrey,
                          border: Border.all(
                            color: isActive ? AppTheme.saffron : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '$stepNum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.white : AppTheme.warmGrey,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                          color: isActive ? AppTheme.maroon : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: _step > stepNum ? AppTheme.maroon : AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: Region ────────────────────────────────────────────────────────

  Widget _buildStep1(List<Temple> allTemples) {
    // Extract unique states from temple regions
    final states = allTemples
        .map((t) => t.region ?? '')
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Where do you want to go?', Icons.explore),
          const SizedBox(height: 20),
          _wizardOptionCard(
            icon: Icons.near_me,
            title: 'Nearby',
            subtitle: 'Temples close to you',
            selected: _regionFilter == 'Nearby',
            onTap: () => setState(() => _regionFilter = 'Nearby'),
          ),
          const SizedBox(height: 12),
          _wizardOptionCard(
            icon: Icons.map,
            title: 'By State',
            subtitle: _regionFilter != null && _regionFilter != 'Nearby'
                ? _regionFilter!
                : 'Choose a state',
            selected: _regionFilter != null &&
                _regionFilter != 'Nearby' &&
                _regionFilter != null,
            onTap: () => _showStateBottomSheet(states),
          ),
          const SizedBox(height: 12),
          _wizardOptionCard(
            icon: Icons.temple_hindu,
            title: 'All India',
            subtitle: 'No region filter',
            selected: _regionFilter == null,
            onTap: () => setState(() => _regionFilter = null),
          ),
          const SizedBox(height: 32),
          _nextButton('Next: Duration', () => setState(() => _step = 2)),
        ],
      ),
    );
  }

  void _showStateBottomSheet(List<String> states) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose a State',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: states.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(states[i]),
                trailing: _regionFilter == states[i]
                    ? const Icon(Icons.check_circle, color: AppTheme.maroon)
                    : null,
                onTap: () {
                  setState(() => _regionFilter = states[i]);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Duration ──────────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('How many days?', Icons.calendar_today),
          const SizedBox(height: 20),
          _wizardOptionCard(
            icon: Icons.wb_sunny,
            title: '1 Day',
            subtitle: 'Quick pilgrimage',
            selected: _numberOfDays == 1,
            onTap: () => setState(() => _numberOfDays = 1),
          ),
          const SizedBox(height: 12),
          _wizardOptionCard(
            icon: Icons.calendar_view_week,
            title: '2 Days',
            subtitle: 'Weekend yatra',
            selected: _numberOfDays == 2,
            onTap: () => setState(() => _numberOfDays = 2),
          ),
          const SizedBox(height: 12),
          _wizardOptionCard(
            icon: Icons.date_range,
            title: '3+ Days',
            subtitle: _numberOfDays >= 3 ? '$_numberOfDays days selected' : 'Extended pilgrimage',
            selected: _numberOfDays >= 3,
            onTap: () => _showDaysStepper(),
          ),
          const SizedBox(height: 32),
          _nextButton('Next: Deity Preference', () => setState(() => _step = 3)),
        ],
      ),
    );
  }

  void _showDaysStepper() {
    int tempDays = _numberOfDays >= 3 ? _numberOfDays : 3;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Number of Days',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.maroon, size: 32),
                    onPressed: tempDays > 3 ? () => setLocal(() => tempDays--) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$tempDays',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.maroon),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.maroon, size: 32),
                    onPressed: tempDays < 7 ? () => setLocal(() => tempDays++) : null,
                  ),
                ],
              ),
              const Text('days', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _numberOfDays = tempDays);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 3: Deity Preference ──────────────────────────────────────────────

  Widget _buildStep3() {
    const deities = ['Shiva', 'Vishnu', 'Devi', 'Ganesha', 'Hanuman'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Any deity preference?', Icons.auto_awesome),
          const SizedBox(height: 6),
          const Text(
            'Optional — we\'ll filter temples by deity',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...deities.map((deity) {
                final selected = _deityFilter == deity;
                return GestureDetector(
                  onTap: () => setState(() => _deityFilter = selected ? null : deity),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.maroon : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: selected ? AppTheme.maroon : AppTheme.borderColor,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected ? AppTheme.cardShadow : null,
                    ),
                    child: Text(
                      deity,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => setState(() => _deityFilter = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _deityFilter == null ? AppTheme.saffron.withValues(alpha: 0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _deityFilter == null ? AppTheme.saffron : AppTheme.borderColor,
                      width: _deityFilter == null ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    'No Preference',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _deityFilter == null ? FontWeight.bold : FontWeight.normal,
                      color: _deityFilter == null ? AppTheme.maroon : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _nextButton(
            'See Suggested Yatra',
            () {
              final allTemples = ref.read(allTemplesDbProvider).valueOrNull ?? [];
              _applyFiltersAndSuggest(allTemples);
              setState(() => _step = 4);
            },
          ),
        ],
      ),
    );
  }

  // ── Step 4: Confirmation ──────────────────────────────────────────────────

  Widget _buildStep4(List<Temple> allTemples) {
    final remaining = allTemples
        .where((t) => !_selectedTemples.contains(t))
        .take(10)
        .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Suggested Yatra card
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.saffron, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your Suggested Yatra',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddMoreBottomSheet(remaining),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add More'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.maroon,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_selectedTemples.length} temples selected based on your preferences',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedTemples.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'No temples matched your filters.\nTap "Add More" to pick manually.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_selectedTemples.length, (i) {
                          final t = _selectedTemples[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.saffron.withValues(alpha: 0.15),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.maroon,
                                ),
                              ),
                            ),
                            title: Text(
                              t.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              t.region ?? t.address,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                              onPressed: () => setState(() => _selectedTemples.removeAt(i)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Trip details
                _sectionLabel('Trip Details', Icons.tune),
                const SizedBox(height: 10),
                _buildDateRow(),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _buildDaysSelector()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTemplesPerDaySelector()),
                ]),
                const SizedBox(height: 10),
                _buildTravelModeSelector(),
                const SizedBox(height: 10),
                _buildBudgetRow(),
                const SizedBox(height: 20),

                // Preferences
                _sectionLabel('Preferences', Icons.settings_suggest),
                const SizedBox(height: 10),
                _buildStartTimeRow(),
                const SizedBox(height: 10),
                _buildDarshanStyleSelector(),
                const SizedBox(height: 10),
                _buildGroupSizeRow(),
                const SizedBox(height: 10),
                _buildAccommodationRow(),
                const SizedBox(height: 10),
                _buildToggleRow(
                  label: 'Avoid Highways',
                  subtitle: 'Prefer local/scenic roads',
                  icon: Icons.alt_route,
                  value: _avoidHighways,
                  onChanged: (v) => setState(() => _avoidHighways = v),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        _stickyButton(_selectedTemples.isNotEmpty),
      ],
    );
  }

  void _showAddMoreBottomSheet(List<Temple> remaining) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add More Temples',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Showing up to 10 temples not yet selected',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: remaining.length,
                itemBuilder: (_, i) {
                  final t = remaining[i];
                  final checked = _selectedTemples.contains(t);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(t.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      t.region ?? t.address,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    activeColor: AppTheme.maroon,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTemples.add(t);
                        } else {
                          _selectedTemples.remove(t);
                        }
                      });
                      setLocal(() {});
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter & Suggest ──────────────────────────────────────────────────────

  void _applyFiltersAndSuggest(List<Temple> all) {
    List<Temple> filtered = List<Temple>.from(all);

    // Region filter
    if (_regionFilter == 'Nearby') {
      // Sort by distance — use a central India lat/lng as fallback since we
      // don't have actual device location here; temples closer to center first
      const centerLat = 20.5937;
      const centerLng = 78.9629;
      filtered.sort((a, b) {
        final da = _haversine(a.latitude, a.longitude, centerLat, centerLng);
        final db = _haversine(b.latitude, b.longitude, centerLat, centerLng);
        return da.compareTo(db);
      });
    } else if (_regionFilter != null) {
      filtered = filtered
          .where((t) =>
              (t.region ?? '').toLowerCase() == _regionFilter!.toLowerCase())
          .toList();
    }

    // Deity filter
    if (_deityFilter != null) {
      filtered = filtered
          .where((t) =>
              (t.deityInfo ?? '').toLowerCase().contains(_deityFilter!.toLowerCase()))
          .toList();
    }

    // Sort by rating descending
    filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    // Take top 8
    final suggested = filtered.take(8).toList();

    setState(() {
      _selectedTemples.clear();
      _selectedTemples.addAll(suggested);
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;
  double _sin2(double x) => _sin(x) * _sin(x);
  double _sin(double x) {
    // Simple sin approximation via dart:math is fine but we avoid import
    // Use the built-in via identical trick — just use dart:math directly
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  double _asin(double x) => x + (x * x * x) / 6 + (3 * x * x * x * x * x) / 40;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
    return r;
  }

  // ── Shared Wizard Widgets ─────────────────────────────────────────────────

  Widget _wizardOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.maroon.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.maroon : AppTheme.borderColor,
            width: selected ? 2 : 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.maroon.withValues(alpha: 0.12)
                    : AppTheme.saffron.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? AppTheme.maroon : AppTheme.saffron,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.maroon : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.maroon, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _nextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.maroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  // ── Existing Widgets (unchanged) ──────────────────────────────────────────

  Widget _sectionLabel(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.maroon),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    ]);
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildDateRow() {
    final hasDate = _startDate != null && _endDate != null;
    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(12),
      child: _card(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.saffron.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today, color: AppTheme.saffron, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trip Dates',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(
                hasDate
                    ? '${_fmt(_startDate!)}  →  ${_fmt(_endDate!)}'
                    : 'Tap to choose dates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                  color: hasDate ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ]),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  Widget _buildBudgetRow() {
    return _card(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.currency_rupee, color: AppTheme.saffron, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Max Budget (₹)',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextFormField(
              initialValue: _budget > 0 ? _budget.toStringAsFixed(0) : '',
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'No limit',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _budget = double.tryParse(v) ?? 0,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStartTimeRow() {
    return InkWell(
      onTap: _pickStartTime,
      borderRadius: BorderRadius.circular(12),
      child: _card(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.saffron.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule, color: AppTheme.saffron, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Daily Start Time',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(
                TimeOfDay(hour: _startHour, minute: _startMinute).format(context),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  Widget _buildGroupSizeRow() {
    return _card(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.group, color: AppTheme.saffron, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Group Size',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.maroon),
          onPressed: _groupSize > 1 ? () => setState(() => _groupSize--) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$_groupSize',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppTheme.maroon),
          onPressed: () => setState(() => _groupSize++),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildAccommodationRow() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Accommodation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AccommodationPref.values.map((p) {
            final label = switch (p) {
              AccommodationPref.none => 'None',
              AccommodationPref.budget => 'Budget',
              AccommodationPref.midRange => 'Mid-Range',
              AccommodationPref.luxury => 'Luxury',
            };
            final selected = _accommodation == p;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _accommodation = p),
              selectedColor: AppTheme.maroon,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(color: selected ? AppTheme.maroon : AppTheme.borderColor),
            );
          }).toList(),
        ),
        if (_accommodation != AccommodationPref.none) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('Nights: ', style: TextStyle(fontSize: 13)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.maroon),
              onPressed: _numberOfNights > 0 ? () => setState(() => _numberOfNights--) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$_numberOfNights',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.maroon),
              onPressed: () => setState(() => _numberOfNights++),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildDarshanStyleSelector() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Darshan Style',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Affects time spent at each temple',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(children: DarshanStyle.values.map((s) {
          final label = switch (s) {
            DarshanStyle.quick => 'Quick\n~20 min',
            DarshanStyle.standard => 'Standard\n~30-60 min',
            DarshanStyle.full => 'Full Puja\n~90-120 min',
          };
          final selected = _darshanStyle == s;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _darshanStyle = s),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.maroon : AppTheme.softGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppTheme.maroon : AppTheme.borderColor,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }

  Widget _buildTravelModeSelector() {
    const modes = ['Car', 'Bike', 'Bus', 'Train'];
    const icons = [Icons.directions_car, Icons.two_wheeler, Icons.directions_bus, Icons.train];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Travel Mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(modes.length, (i) {
            final selected = _travelMode == modes[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _travelMode = modes[i]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.maroon : AppTheme.softGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppTheme.maroon : AppTheme.borderColor,
                    ),
                  ),
                  child: Column(children: [
                    Icon(icons[i],
                        size: 18,
                        color: selected ? Colors.white : AppTheme.warmGrey),
                    const SizedBox(height: 3),
                    Text(modes[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.white : AppTheme.warmGrey,
                        )),
                  ]),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildDaysSelector() {
    return DropdownButtonFormField<int>(
      decoration: _inputDeco('Days', Icons.today),
      value: _numberOfDays,
      items: List.generate(14, (i) => i + 1)
          .map((d) => DropdownMenuItem(value: d, child: Text('$d day${d > 1 ? 's' : ''}')))
          .toList(),
      onChanged: (v) => setState(() => _numberOfDays = v ?? 1),
    );
  }

  Widget _buildTemplesPerDaySelector() {
    return DropdownButtonFormField<int>(
      decoration: _inputDeco('Per Day', Icons.temple_hindu),
      value: _templesPerDay,
      items: [1, 2, 3, 4, 5]
          .map((c) => DropdownMenuItem(value: c, child: Text('$c temple${c > 1 ? 's' : ''}')))
          .toList(),
      onChanged: (v) => setState(() => _templesPerDay = v ?? 3),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.saffron, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.maroon,
        ),
      ]),
    );
  }

  // Keep _buildTempleSelector for reference — not called in wizard flow
  Widget _buildTempleSelector(List<Temple> available) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available.map((temple) {
            final isSelected = _selectedTemples.contains(temple);
            return FilterChip(
              label: Text(
                temple.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppTheme.maroon : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (sel) => setState(() {
                if (sel) _selectedTemples.add(temple);
                else _selectedTemples.remove(temple);
              }),
              selectedColor: AppTheme.saffron.withValues(alpha: 0.18),
              backgroundColor: Colors.white,
              checkmarkColor: AppTheme.maroon,
              side: BorderSide(
                color: isSelected ? AppTheme.saffron : Colors.grey.shade400,
                width: isSelected ? 1.5 : 1,
              ),
              avatar: _TempleCrowdAvatar(
                templeId: temple.id,
                date: _startDate ?? DateTime.now(),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(children: [
          _pill('Select All', Icons.select_all, () => setState(() {
            _selectedTemples..clear()..addAll(available);
          })),
          const SizedBox(width: 8),
          _pill('Clear', Icons.clear, () => setState(() => _selectedTemples.clear())),
          const SizedBox(width: 8),
          _pill('Top Rated', Icons.star, () {
            final sorted = List<Temple>.from(available)
              ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
            setState(() { _selectedTemples..clear()..addAll(sorted.take(5)); });
          }),
        ]),
      ]),
    );
  }

  Widget _pill(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.sandalwoodBeige,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppTheme.maroon),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.maroon, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _stickyButton(bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: enabled ? _generateItinerary : null,
            icon: const Icon(Icons.route, size: 20),
            label: Text(
              enabled
                  ? 'Generate Itinerary  (${_selectedTemples.length} temples)'
                  : 'Select temples to continue',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? AppTheme.maroon : Colors.grey.shade300,
              foregroundColor: enabled ? Colors.white : Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: enabled ? 2 : 0,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.saffron, size: 18),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.maroon,
            onPrimary: Colors.white,
            secondary: AppTheme.saffron,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _numberOfDays = range.end.difference(range.start).inDays + 1;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startHour, minute: _startMinute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.maroon),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _startHour = picked.hour; _startMinute = picked.minute; });
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  AccommodationType _accommodationToType(AccommodationPref pref) {
    return switch (pref) {
      AccommodationPref.none => AccommodationType.none,
      AccommodationPref.budget => AccommodationType.budget,
      AccommodationPref.midRange => AccommodationType.midRange,
      AccommodationPref.luxury => AccommodationType.luxury,
    };
  }

  void _generateItinerary() {
    final constraints = ItineraryConstraints(
      startDate: _startDate,
      endDate: _endDate,
      maxBudget: _budget > 0 ? _budget : null,
      maxDays: _numberOfDays,
      maxTemplesPerDay: _templesPerDay,
      travelMode: _travelMode,
      startHour: _startHour,
      startMinute: _startMinute,
      darshanStyle: _darshanStyle,
      avoidHighways: _avoidHighways,
      groupSize: _groupSize,
      accommodation: _accommodation,
      numberOfNights: _numberOfNights,
      foodBudgetPerDay: _foodBudgetPerDay,
      fuelPricePerLiter: _fuelPrice,
    );

    final itinerary = ItineraryGenerator(
      availableTemples: _selectedTemples,
      constraints: constraints,
    ).generate();

    for (final w in itinerary.warnings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(w), backgroundColor: Colors.orange),
      );
    }

    final routeTemples = <Temple>[];
    for (final day in itinerary.dayPlans) {
      for (final visit in day.visits) {
        if (!routeTemples.contains(visit.temple)) routeTemples.add(visit.temple);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutePlannerScreen(
          selectedTemples: routeTemples,
          itinerary: itinerary,
          travelMode: _travelMode,
          avoidHighways: _avoidHighways,
          budget: _budget,
          fuelPrice: _fuelPrice,
          numberOfDays: _numberOfDays,
          numberOfNights: _numberOfNights,
          accommodationType: _accommodationToType(_accommodation),
        ),
      ),
    );
  }
}

class _TempleCrowdAvatar extends ConsumerWidget {
  final String templeId;
  final DateTime date;
  const _TempleCrowdAvatar({required this.templeId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(templeFestivalsDbProvider(templeId)).when(
      loading: () => CrowdLevel.low,
      error: (_, __) => CrowdLevel.low,
      data: (events) => computeCrowdLevel(templeId, date, events),
    );
    return CrowdBadge(level: level, compact: true);
  }
}
