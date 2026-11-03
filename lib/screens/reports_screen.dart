import 'package:flutter/material.dart';
import '../data/reports_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.language});
  final String language;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ReportsRepository();
  DateTime _month = DateTime.now();
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

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
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
                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString());
                  }
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
                        Expanded(child: _metric(t('باقی بیلنس', 'Balance', 'बाकी बैलेंस'), data['balance_paisa'], const Color(0xFFE8E5FF))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _metric(t('ایڈوانس دیا', 'Advance Given', 'एडवांस दिया'), data['advance_given_paisa'], const Color(0xFFFFF2C6))),
                        const SizedBox(width: 8),
                        Expanded(child: _metric(t('وصول شدہ رقم', 'Payments Received', 'प्राप्त भुगतान'), data['payment_received_paisa'], const Color(0xFFE0F8E8))),
                      ]),
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
        ),
      );
}
