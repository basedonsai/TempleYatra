import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/smart_itinerary.dart';

/// Thrown when PDF generation or export fails.
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}

class ItineraryExportService {
  /// Builds a PDF document from [itinerary] and returns the raw bytes.
  Future<Uint8List> buildPdf(SmartItinerary itinerary) async {
    try {
      final doc = pw.Document();
      final req = itinerary.request;

      final dateFormat = DateFormat('d MMM yyyy');
      final timeFormat = DateFormat('HH:mm');

      final startDateStr = dateFormat.format(req.startDate);
      final endDate = req.startDate.add(Duration(days: itinerary.days.length - 1));
      final endDateStr = dateFormat.format(endDate);
      final dateRange = itinerary.days.length == 1
          ? startDateStr
          : '$startDateStr – $endDateStr';

      final tripTitle = 'Temple Yatra — ${itinerary.days.length} Day${itinerary.days.length == 1 ? '' : 's'}';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(tripTitle, dateRange),
          footer: (context) => pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.right,
          ),
          build: (context) => [
            pw.SizedBox(height: 16),
            ..._buildDaySections(itinerary, timeFormat),
            pw.SizedBox(height: 16),
            _buildCostSummary(itinerary.totalCost),
          ],
        ),
      );

      return doc.save();
    } catch (e) {
      throw ExportException('Failed to build PDF: $e');
    }
  }

  /// Shares the itinerary as a PDF using the native share sheet.
  /// Falls back to [saveToFile] when the share sheet is unavailable.
  Future<void> shareAsPdf(SmartItinerary itinerary) async {
    final bytes = await buildPdf(itinerary);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/itinerary.pdf');
    await file.writeAsBytes(bytes);

    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'My Temple Yatra Itinerary',
      );
    } catch (_) {
      await saveToFile(itinerary);
    }
  }

  /// Saves the PDF to the app documents directory and returns the file name.
  Future<String> saveToFile(SmartItinerary itinerary) async {
    final bytes = await buildPdf(itinerary);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'itinerary_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return fileName;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  pw.Widget _buildHeader(String tripTitle, String dateRange) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Temple Yatra',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepOrange,
              ),
            ),
            pw.Text(
              dateRange,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          tripTitle,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(thickness: 1, color: PdfColors.deepOrange),
      ],
    );
  }

  List<pw.Widget> _buildDaySections(
    SmartItinerary itinerary,
    DateFormat timeFormat,
  ) {
    final widgets = <pw.Widget>[];

    for (final day in itinerary.days) {
      final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(day.date);

      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.orange50),
          child: pw.Text(
            'Day ${day.dayNumber} — $dateLabel',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 6));

      for (final visit in day.visits) {
        final arrival = timeFormat.format(visit.arrivalTime);
        final departure = timeFormat.format(visit.departureTime);
        final durationMin = visit.visitDuration.inMinutes;
        final distKm = visit.travelDistanceKm.toStringAsFixed(1);
        final cost = visit.travelCost.toStringAsFixed(0);

        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  visit.temple.name,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '$arrival → $departure  ($durationMin min)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Distance: ${distKm} km   Travel cost: ₹$cost',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        );
      }

      widgets.add(pw.SizedBox(height: 10));
    }

    return widgets;
  }

  pw.Widget _buildCostSummary(CostSummary cost) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          'Cost Summary',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _costRow('Transport', cost.transport),
        _costRow('Accommodation', cost.stay),
        _costRow('Food', cost.food),
        _costRow('Temple-specific', cost.templeSpecific),
        _costRow('Miscellaneous', cost.misc),
        pw.Divider(thickness: 0.5),
        _costRow('Total', cost.total, bold: true),
      ],
    );
  }

  pw.Widget _costRow(String label, double amount, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
        : const pw.TextStyle(fontSize: 11);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text('₹${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
