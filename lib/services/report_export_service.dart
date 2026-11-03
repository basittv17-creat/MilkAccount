import 'dart:typed_data';

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
