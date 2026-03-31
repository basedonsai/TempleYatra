import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/smart_itinerary.dart';
import '../services/itinerary_export_service.dart';

class ItineraryPreviewScreen extends StatefulWidget {
  final SmartItinerary itinerary;

  const ItineraryPreviewScreen({super.key, required this.itinerary});

  @override
  State<ItineraryPreviewScreen> createState() => _ItineraryPreviewScreenState();
}

class _ItineraryPreviewScreenState extends State<ItineraryPreviewScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting…'), duration: Duration(seconds: 1)),
    );

    try {
      final service = ItineraryExportService();
      await service.shareAsPdf(widget.itinerary);
    } on ExportException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinerary Preview'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Export PDF',
                  onPressed: _exportPdf,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.itinerary.warnings.isNotEmpty)
            _WarningsBanner(warnings: widget.itinerary.warnings),
          ...widget.itinerary.days.map((day) => _DayCard(day: day)),
          const SizedBox(height: 8),
          _CostSummaryCard(cost: widget.itinerary.totalCost),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _WarningsBanner extends StatelessWidget {
  final List<String> warnings;

  const _WarningsBanner({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map((w) => Text(w, style: const TextStyle(fontSize: 13)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final SmartDayPlan day;

  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM').format(day.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              'Day ${day.dayNumber} — $dateLabel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...day.visits.map((visit) => _VisitTile(visit: visit)),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final SmartTempleVisit visit;

  const _VisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    final arrival = DateFormat('HH:mm').format(visit.arrivalTime);
    final departure = DateFormat('HH:mm').format(visit.departureTime);
    final durationMin = visit.visitDuration.inMinutes;
    final distanceKm = visit.travelDistanceKm.toStringAsFixed(1);
    final cost = visit.travelCost.toStringAsFixed(0);

    return ListTile(
      leading: const Icon(Icons.temple_hindu, color: Colors.deepOrange),
      title: Text(visit.temple.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$arrival → $departure  ($durationMin min)'),
          Text('Distance: ${distanceKm} km   Cost: ₹$cost'),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _CostSummaryCard extends StatelessWidget {
  final CostSummary cost;

  const _CostSummaryCard({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _CostRow(label: 'Transport', amount: cost.transport),
            _CostRow(label: 'Accommodation', amount: cost.stay),
            _CostRow(label: 'Food', amount: cost.food),
            _CostRow(label: 'Temple-specific', amount: cost.templeSpecific),
            _CostRow(label: 'Miscellaneous', amount: cost.misc),
            const Divider(height: 20),
            _CostRow(label: 'Total', amount: cost.total, bold: true),
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _CostRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
