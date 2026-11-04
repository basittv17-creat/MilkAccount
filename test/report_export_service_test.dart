import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:milk_account/services/report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF report embeds Urdu-capable font for customer names', () async {
    final bytes = await ReportExportService().createPdf(
      title: 'Milk Account - Monthly Report',
      lines: ['#2 محمد علی: Rs. 2880.00 (96.000 kg)'],
    );

    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    expect(latin1.decode(bytes, allowInvalid: true), contains('NotoNaskhArabic'));
  });
}
