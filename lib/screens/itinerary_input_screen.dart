import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/temple_model.dart';
import '../models/smart_itinerary.dart';
import '../providers/itinerary_provider.dart';
import '../services/budget_service.dart';
import 'itinerary_preview_screen.dart';

class ItineraryInputScreen extends ConsumerStatefulWidget {
  final List<Temple> selectedTemples;

  const ItineraryInputScreen({
    super.key,
    required this.selectedTemples,
  });

  @override
  ConsumerState<ItineraryInputScreen> createState() =>
      _ItineraryInputScreenState();
}

class _ItineraryInputScreenState extends ConsumerState<ItineraryInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController(text: '0');
  final _stopsController = TextEditingController();

  DateTime? _startDate;
  int _numberOfDays = 2;
  VehicleType _travelMode = VehicleType.car;

  String? _dateError;
  String? _templesError;

  @override
  void dispose() {
    _budgetController.dispose();
    _stopsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _dateError = null;
      });
    }
  }

  bool _validate() {
    bool valid = true;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_startDate == null) {
      setState(() => _dateError = 'Please select a start date.');
      valid = false;
    } else if (_startDate!.isBefore(todayDate)) {
      setState(() => _dateError = 'Start date cannot be in the past.');
      valid = false;
    } else {
      setState(() => _dateError = null);
    }

    if (widget.selectedTemples.isEmpty) {
      setState(() => _templesError = 'No temples selected. Please go back and select temples.');
      valid = false;
    } else {
      setState(() => _templesError = null);
    }

    return valid;
  }

  Future<void> _onGenerate() async {
    if (!_validate()) return;

    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
    final stops = _stopsController.text.trim().isEmpty
        ? <String>[]
        : _stopsController.text.trim().split(',').map((s) => s.trim()).toList();

    final request = ItineraryRequest(
      temples: widget.selectedTemples,
      startDate: _startDate!,
      numberOfDays: _numberOfDays,
      maxBudget: budget,
      travelMode: _travelMode,
      optionalStops: stops,
    );

    await ref.read(itineraryProvider.notifier).generate(request);
  }

  @override
  Widget build(BuildContext context) {
    final itineraryState = ref.watch(itineraryProvider);

    // Navigate when generation succeeds
    ref.listen<AsyncValue<SmartItinerary?>>(itineraryProvider, (prev, next) {
      next.whenData((itinerary) {
        if (itinerary != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ItineraryPreviewScreen(itinerary: itinerary),
            ),
          );
        }
      });
    });

    final isLoading = itineraryState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Yatra'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selected temples summary
              _SectionLabel(label: 'Selected Temples (${widget.selectedTemples.length})'),
              if (_templesError != null)
                _ErrorText(message: _templesError!),
              if (widget.selectedTemples.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.selectedTemples
                      .map((t) => Chip(label: Text(t.name)))
                      .toList(),
                ),
              const SizedBox(height: 20),

              // Start date
              _SectionLabel(label: 'Travel Start Date'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _startDate == null
                          ? 'No date selected'
                          : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: isLoading ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              if (_dateError != null)
                _ErrorText(message: _dateError!),
              const SizedBox(height: 20),

              // Number of days stepper
              _SectionLabel(label: 'Number of Days'),
              Row(
                children: [
                  IconButton(
                    onPressed: isLoading || _numberOfDays <= 1
                        ? null
                        : () => setState(() => _numberOfDays--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_numberOfDays',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: isLoading || _numberOfDays >= 14
                        ? null
                        : () => setState(() => _numberOfDays++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Text(
                    _numberOfDays == 1 ? '1 day' : '$_numberOfDays days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Budget field
              _SectionLabel(label: 'Maximum Budget (₹)'),
              TextFormField(
                controller: _budgetController,
                enabled: !isLoading,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0 = no limit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Travel mode selector
              _SectionLabel(label: 'Travel Mode'),
              SegmentedButton<VehicleType>(
                segments: const [
                  ButtonSegment(
                    value: VehicleType.car,
                    label: Text('Car'),
                    icon: Icon(Icons.directions_car),
                  ),
                  ButtonSegment(
                    value: VehicleType.bike,
                    label: Text('Bike'),
                    icon: Icon(Icons.two_wheeler),
                  ),
                  ButtonSegment(
                    value: VehicleType.bus,
                    label: Text('Bus'),
                    icon: Icon(Icons.directions_bus),
                  ),
                ],
                selected: {_travelMode},
                onSelectionChanged: isLoading
                    ? null
                    : (selection) =>
                        setState(() => _travelMode = selection.first),
              ),
              const SizedBox(height: 20),

              // Optional stops
              _SectionLabel(label: 'Optional Stops (comma-separated)'),
              TextFormField(
                controller: _stopsController,
                enabled: !isLoading,
                decoration: const InputDecoration(
                  hintText: 'e.g. Lunch at Dhaba, Roadside temple',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Error from provider
              if (itineraryState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ErrorText(
                    message: 'Generation failed: ${itineraryState.error}',
                  ),
                ),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : _onGenerate,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(isLoading ? 'Generating…' : 'Generate Itinerary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}
