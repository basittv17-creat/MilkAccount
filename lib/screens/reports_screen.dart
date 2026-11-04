import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/reports_repository.dart';
import '../services/report_export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.language});
  final String language;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ReportsRepository();
  final _export = ReportExportService();
  DateTime _month = DateTime.now();
  bool _busy = false;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) =>
      _ur ? u : widget.language == 'hi' ? h : e;
  String money(Object? value) =>
      'Rs. ' + ((((value as int?) ?? 0) / 100).toStringAsFixed(2));

  Future<void> _pickMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (date != null && mounted) {
      setState(() => _month = DateTime(date.year, date.month, 1));
    }
  }

  Future<({Uint8List pdf, String message, Map<String, int> summary, List<Map<String, Object?>> customers, List<Map<String, Object?>> daily, String period})> _reportData() async {
    final summary = await _repo.summary(_month);
    final customers = await _repo.customerTotals(_month);
    final daily = await _repo.dailyTotals(_month);
    final period = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    final lines = <String>[
      'Period: $period',
      'Milk amount: ${money(summary['milk_amount_paisa'])}',
      'Balance: ${money(summary['balance_paisa'])}',
      'Advance given: ${money(summary['advance_given_paisa'])}',
      'Milk quantity: ${((summary['milk_quantity_grams'] ?? 0) / 1000).toStringAsFixed(3)} kg',
      'Milk entries: ${summary['milk_entries']}',
      'No-milk days: ${summary['no_milk_days']}',
      '',
      'CUSTOMER TOTALS',
      ...customers.map((row) =>
          '#${row['account_number']} ${row['customer_name']}: ${money(row['amount_paisa'])} (${((row['quantity_grams'] as int) / 1000).toStringAsFixed(3)} kg)'),
      '',
      'DAILY TOTALS',
      ...daily.map((row) =>
          '${row['day']}: ${money(row['amount_paisa'])}, ${((row['quantity_grams'] as int) / 1000).toStringAsFixed(3)} kg'),
    ];
    final message = lines.join('\n');
    final pdf = await _export.createPdf(
      title: 'Milk Account — Monthly Report',
      lines: lines,
    );
    return (pdf: pdf, message: message, summary: summary, customers: customers, daily: daily, period: period);
  }

  Future<void> _runExport(String action) async {
    setState(() => _busy = true);
    try {
      final data = await _reportData();
      if (action == 'print') {
        await _export.printPdf(data.pdf);
      } else if (action == 'pdf') {
        final period =
            '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
        await _export.sharePdf(data.pdf, 'milk-account-$period.pdf');
      } else if (action == 'excel') {
        final bytes = _export.createExcelReport(
          period: data.period,
          summary: data.summary,
          customers: data.customers,
          daily: data.daily,
        );
        await _export.shareExcel(bytes, 'milk-account-${data.period}.xlsx');
      } else if (action == 'sms') {
        final ok = await _export.sendSms(data.message);
        if (!ok && mounted) {
          _message(t('SMS ایپ نہیں کھل سکی', 'Could not open SMS app', 'SMS ऐप नहीं खुला'));
        }
      } else {
        final ok = await _export.shareWhatsApp(data.message);
        if (!ok && mounted) {
          _message(t('WhatsApp نہیں کھل سکا', 'Could not open WhatsApp', 'WhatsApp नहीं खुला'));
        }
      }
    } catch (error) {
      if (mounted) _message('${t('رپورٹ تیار نہیں ہو سکی', 'Could not prepare report', 'रिपोर्ट तैयार नहीं हुई')}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _metric(String title, Object? value, Color color) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(money(value),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _exportButton(
          String action, String label, IconData icon, Color color) =>
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _runExport(action),
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(top: false, child: Scaffold(
          backgroundColor: const Color(0xFFF3F9FF),
          appBar: AppBar(
            title: Text(t('رپورٹس', 'Reports', 'रिपोर्ट')),
            backgroundColor: const Color(0xFF0649AE),
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month),
                label: Text('${_month.year} / ${_month.month.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 8),
              if (_busy) const LinearProgressIndicator(),
              Row(children: [
                _exportButton('pdf', t('PDF شیئر', 'PDF / Share', 'PDF साझा'), Icons.picture_as_pdf, const Color(0xFFB3261E)),
                const SizedBox(width: 5),
                _exportButton('print', t('پرنٹ', 'Print', 'प्रिंट'), Icons.print, const Color(0xFF0756C9)),
              ]),
              Row(children: [
                _exportButton('excel', t('Excel ایکسپورٹ', 'Export Excel', 'Excel निर्यात'), Icons.table_chart, const Color(0xFF16834A)),
                const SizedBox(width: 5),
                _exportButton('sms', t('SMS', 'SMS', 'SMS'), Icons.sms, const Color(0xFF079B37)),
                const SizedBox(width: 5),
                _exportButton('whatsapp', t('واٹس ایپ', 'WhatsApp', 'WhatsApp'), Icons.chat, const Color(0xFF168B45)),
              ]),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: _repo.summary(_month),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) return Text(snapshot.error.toString());
                  final data = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t('ماہانہ خلاصہ', 'Monthly Summary', 'मासिक सारांश'),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _metric(t('دودھ کی کل رقم', 'Milk Amount', 'दूध की रकम'), data['milk_amount_paisa'], const Color(0xFFDFF1FF))),
                        const SizedBox(width: 8),
                        Expanded(child: _metric(t('باقی ایڈوانس', 'Remaining advance', 'बाकी एडवांस'), data['balance_paisa'], const Color(0xFFE8E5FF))),
                      ]),
                      const SizedBox(height: 8),
                      _metric(t('کل ایڈوانس دیا', 'Total advance given', 'कुल एडवांस दिया'), data['advance_given_paisa'], const Color(0xFFFFF2C6)),
                      const SizedBox(height: 10),
                      Text(
                        t('کل دودھ: ', 'Milk quantity: ', 'कुल दूध: ') +
                            ((data['milk_quantity_grams'] ?? 0) / 1000).toStringAsFixed(3) +
                            ' kg  •  ' +
                            t('اندراجات: ', 'Entries: ', 'एंट्री: ') +
                            (data['milk_entries'] ?? 0).toString() +
                            '  •  ' +
                            t('ناگا: ', 'No-milk days: ', 'नागा: ') +
                            (data['no_milk_days'] ?? 0).toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(t('گاہکوں کے حساب سے رپورٹ', 'Customer-wise Report', 'ग्राहक के अनुसार रिपोर्ट'),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _repo.customerTotals(_month),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return Text(snapshot.error.toString());
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t('کوئی فعال کھاتہ موجود نہیں', 'No active accounts', 'कोई सक्रिय खाता नहीं')),
                    );
                  }
                  return Column(
                    children: rows.map((row) => Card(
                      color: Colors.white,
                      child: ListTile(
                        title: Text('#${row['account_number']} — ${row['customer_name']}'),
                        subtitle: Text(
                          (((row['quantity_grams'] as int) / 1000).toStringAsFixed(3)) +
                              ' kg  •  ' +
                              t('اندراجات: ', 'Entries: ', 'एंट्री: ') +
                              row['entries'].toString(),
                        ),
                        trailing: Text(money(row['amount_paisa']),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(t('روزانہ دودھ کی رپورٹ', 'Daily Milk Report', 'दैनिक दूध रिपोर्ट'),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _repo.dailyTotals(_month),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return Text(snapshot.error.toString());
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t('اس مہینے دودھ درج نہیں ہوا', 'No milk entries this month', 'इस महीने दूध दर्ज नहीं है')),
                    );
                  }
                  return Column(
                    children: rows.map((row) => Card(
                      color: Colors.white,
                      child: ListTile(
                        title: Text(row['day'].toString()),
                        subtitle: Text(
                          ((row['quantity_grams'] as int) / 1000).toStringAsFixed(3) +
                              ' kg  •  ' +
                              t('اندراجات: ', 'Entries: ', 'एंट्री: ') +
                              row['entries'].toString(),
                        ),
                        trailing: Text(money(row['amount_paisa']),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        )),
      );
}
