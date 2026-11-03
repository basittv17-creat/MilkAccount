import 'package:flutter/material.dart';
import '../data/account_repository.dart';
import 'new_account_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key, required this.accountId, required this.language});
  final String accountId;
  final String language;
  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _repo = AccountRepository();
  late Future<Map<String, Object?>?> _account;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) => _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() {
    super.initState();
    _account = _repo.getAccount(widget.accountId);
  }

  Future<void> _edit(Map<String, Object?> account) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => NewAccountScreen(language: widget.language, account: account)));
    if (saved == true && mounted) setState(() => _account = _repo.getAccount(widget.accountId));
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    return d.day.toString().padLeft(2, '0') + '/' +
      d.month.toString().padLeft(2, '0') + '/' + d.year.toString() + '  ' +
      d.hour.toString().padLeft(2, '0') + ':' + d.minute.toString().padLeft(2, '0');
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      Expanded(flex: 4, child: Text(label, style: const TextStyle(
        color: Color(0xFF52677D), fontWeight: FontWeight.w600))),
      const SizedBox(width: 10),
      Expanded(flex: 6, child: Text(value, textAlign: TextAlign.end,
        style: const TextStyle(color: Color(0xFF173D67), fontWeight: FontWeight.w700))),
    ]));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(title: Text(t('اکاؤنٹ کی تفصیلات','Account Details','खाते की जानकारी')),
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white),
      body: FutureBuilder<Map<String, Object?>?>(
        future: _account,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final a = snapshot.data;
          if (snapshot.hasError || a == null) return Center(child: Text(t('اکاؤنٹ نہیں ملا','Account not found','खाता नहीं मिला')));
          final rate = ((a['milk_rate_paisa'] as int? ?? 0) / 100).toStringAsFixed(2);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(color: Colors.white, shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFD6E8F8))),
              child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
                CircleAvatar(radius: 34, backgroundColor: const Color(0xFFE0F8E8),
                  child: Text(a['account_number'].toString(), style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF087B32)))),
                const SizedBox(height: 10),
                Text(a['customer_name']?.toString() ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 26),
                _row(t('کھاتہ نمبر','Account number','खाता नंबर'), a['account_number'].toString()),
                _row(t('والد کا نام','Father name','पिता का नाम'), a['father_name']?.toString() ?? ''),
                _row(t('فون نمبر','Phone number','फ़ोन नंबर'), (a['country_code'] ?? '').toString() + ' ' + (a['phone_number'] ?? '').toString()),
                _row(t('شروع ہونے کی تاریخ و وقت','Start date & time','शुरू होने की तारीख और समय'), _date(a['start_at'])),
                _row(t('دودھ کا ریٹ فی کلو','Milk rate per kg','दूध का रेट प्रति किलो'), 'Rs. ' + rate),
                _row('FAT', (a['fat_enabled'] as int? ?? 0) == 1 ? t('فعال','Enabled','चालू') : t('بند','Disabled','बंद')),
                _row(t('نوٹس','Notes','नोट्स'), (a['notes']?.toString().isNotEmpty ?? false) ? a['notes'].toString() : '—'),
              ]))),
            const SizedBox(height: 12),
            SizedBox(height: 52, child: FilledButton.icon(
              onPressed: () => _edit(a), icon: const Icon(Icons.edit),
              label: Text(t('اکاؤنٹ میں ترمیم کریں','Edit Account','खाता संपादित करें')),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF079B37), foregroundColor: Colors.white))),
          ]);
        }),
    ));
}
