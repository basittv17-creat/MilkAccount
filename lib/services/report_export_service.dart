import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportExportService {
  Future<Uint8List> createPdf({
    required String title,
    required List<String> lines,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 18),
          ...lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  Uint8List createExcelReport({
    required String period,
    required Map<String, int> summary,
    required List<Map<String, Object?>> customers,
    required List<Map<String, Object?>> daily,
  }) {
    final workbook = Excel.createExcel();
    final summarySheet = workbook['Summary'];
    summarySheet.appendRow([TextCellValue('Milk Account Monthly Report')]);
    summarySheet.appendRow([TextCellValue('Period'), TextCellValue(period)]);
    summarySheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    final metrics = <(String, int)>[
      ('Milk amount (Rs.)', summary['milk_amount_paisa'] ?? 0),
      ('Balance (Rs.)', summary['balance_paisa'] ?? 0),
      ('Advance given (Rs.)', summary['advance_given_paisa'] ?? 0),
      ('Milk quantity (kg)', summary['milk_quantity_grams'] ?? 0),
      ('Milk entries', summary['milk_entries'] ?? 0),
      ('No-milk days', summary['no_milk_days'] ?? 0),
    ];
    for (final metric in metrics) {
      final isQuantity = metric.$1 == 'Milk quantity (kg)';
      final value = isQuantity
          ? DoubleCellValue(metric.$2 / 1000)
          : metric.$1.endsWith('(Rs.)')
              ? DoubleCellValue(metric.$2 / 100)
              : IntCellValue(metric.$2);
      summarySheet.appendRow([TextCellValue(metric.$1), value]);
    }

    final customerSheet = workbook['Customer Totals'];
    customerSheet.appendRow([
      TextCellValue('Account #'), TextCellValue('Customer'),
      TextCellValue('Milk amount (Rs.)'), TextCellValue('Quantity (kg)'),
      TextCellValue('Entries'),
    ]);
    for (final row in customers) {
      customerSheet.appendRow([
        IntCellValue((row['account_number'] as int?) ?? 0),
        TextCellValue((row['customer_name'] ?? '').toString()),
        DoubleCellValue(((row['amount_paisa'] as int?) ?? 0) / 100),
        DoubleCellValue(((row['quantity_grams'] as int?) ?? 0) / 1000),
        IntCellValue((row['entries'] as int?) ?? 0),
      ]);
    }

    final dailySheet = workbook['Daily Totals'];
    dailySheet.appendRow([
      TextCellValue('Date'), TextCellValue('Milk amount (Rs.)'),
      TextCellValue('Quantity (kg)'), TextCellValue('Entries'),
    ]);
    for (final row in daily) {
      dailySheet.appendRow([
        TextCellValue((row['day'] ?? '').toString()),
        DoubleCellValue(((row['amount_paisa'] as int?) ?? 0) / 100),
        DoubleCellValue(((row['quantity_grams'] as int?) ?? 0) / 1000),
        IntCellValue((row['entries'] as int?) ?? 0),
      ]);
    }
    final bytes = workbook.save();
    if (bytes == null) throw StateError('Could not create Excel workbook');
    return Uint8List.fromList(bytes);
  }

  Future<void> shareExcel(Uint8List bytes, String filename) async {
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: filename, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: filename,
    );
  }

  Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<bool> sendSms(String message) async {
    final uri = Uri(scheme: 'sms', queryParameters: {'body': message});
    return launchUrl(uri);
  }

  Future<bool> shareWhatsApp(String message) async {
    final uri = Uri.https('wa.me', '/', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
