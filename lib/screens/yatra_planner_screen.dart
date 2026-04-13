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
    final canGenerate = _selectedTemples.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.lightBeige,
      appBar: AppBar(title: const Text('Plan Your Yatra')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _header(),
                  const SizedBox(height: 20),

                  // Trip basics
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
                  const SizedBox(height: 20),

                  // Temple selection
                  _sectionLabel(
                    'Select Temples  (${_selectedTemples.length} selected)',
                    Icons.location_on,
                  ),
                  const SizedBox(height: 10),
                  templesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: _buildTempleSelector,
                  ),
                  const SizedBox(height: 80), // space for sticky button
                ],
              ),
            ),
          ),

          // Sticky generate button
          _stickyButton(canGenerate),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.maroon, AppTheme.deepMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.temple_hindu, color: AppTheme.saffron, size: 28),
        const SizedBox(height: 6),
        const Text('Create Your Personalized Yatra',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text('Select temples, set preferences, get an optimized route',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ]),
    );
  }

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

  /// Map AccommodationPref (itinerary generator enum) → AccommodationType (budget service enum)
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
