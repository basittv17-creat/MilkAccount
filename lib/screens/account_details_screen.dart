import 'package:flutter/material.dart';
import '../data/account_repository.dart';
import '../data/account_activity_repository.dart';
import 'new_account_screen.dart';

enum _ActivityRange { month, last15Days, all, custom }

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key, required this.accountId, required this.language});
  final String accountId;
  final String language;
  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _accounts = AccountRepository();
  final _activity = AccountActivityRepository();
  late Future<Map<String, Object?>?> _account;
  late Future<List<Map<String, Object?>>> _records;
  _ActivityRange _range = _ActivityRange.month;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _from = DateTime.now().subtract(const Duration(days: 14));
  DateTime _to = DateTime.now();
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) => _ur ? u : widget.language == 'hi' ? h : e;

  DateTime get _start {
    switch (_range) {
      case _ActivityRange.month: return DateTime(_month.year, _month.month);
      case _ActivityRange.last15Days: return DateTime(_to.year, _to.month, _to.day - 14);
      case _ActivityRange.all:
        final value = DateTime.tryParse(_accountValue?['start_at']?.toString() ?? '')?.toLocal() ?? DateTime(2000);
        return DateTime(value.year, value.month, value.day);
      case _ActivityRange.custom: return DateTime(_from.year, _from.month, _from.day);
    }
  }
  DateTime get _end => _range == _ActivityRange.all ? DateTime.now() : DateTime(_to.year, _to.month, _to.day);
  Map<String, Object?>? _accountValue;

  @override
  void initState() {
    super.initState();
    _account = _accounts.getAccount(widget.accountId);
    _records = _load();
    _account.then((value) {
      if (mounted) setState(() { _accountValue = value; _records = _load(); });
    });
  }

  Future<List<Map<String, Object?>>> _load() async {
    final start = _range == _ActivityRange.all
      ? (DateTime.tryParse(_accountValue?['start_at']?.toString() ?? '')?.toLocal() ?? DateTime(2000))
      : _start;
    return _activity.load(accountId: widget.accountId, startDay: start, endDay: _end);
  }

  void _refresh() => setState(() => _records = _load());

  Future<void> _edit(Map<String, Object?> account) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => NewAccountScreen(language: widget.language, account: account)));
    if (saved == true && mounted) {
      setState(() { _account = _accounts.getAccount(widget.accountId); });
      _account.then((value) { if (mounted) setState(() { _accountValue = value; _records = _load(); }); });
    }
  }

  Future<void> _pickMonth() async {
    final value = await showDatePicker(context: context, initialDate: _month,
      firstDate: DateTime(2000), lastDate: DateTime(2100), initialDatePickerMode: DatePickerMode.year);
    if (value != null && mounted) setState(() { _month = DateTime(value.year, value.month); _refresh(); });
  }

  Future<void> _pickCustom(bool start) async {
    final initial = start ? _from : _to;
    final value = await showDatePicker(context: context, initialDate: initial,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (value != null && mounted) setState(() {
      if (start) { _from = value; if (_from.isAfter(_to)) _to = value; }
      else { _to = value; if (_to.isBefore(_from)) _from = value; }
      _refresh();
    });
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _money(Object? value) => 'Rs. ${(((value as int?) ?? 0) / 100).toStringAsFixed(2)}';
  DateTime? _local(Object? value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(title: Text(t('اکاؤنٹ کی مکمل تفصیل','Complete Account Ledger','खाते का पूरा विवरण')),
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white),
      body: FutureBuilder<Map<String, Object?>?>(
        future: _account,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final a = snapshot.data;
          if (snapshot.hasError || a == null) return Center(child: Text(t('اکاؤنٹ نہیں ملا','Account not found','खाता नहीं मिला')));
          _accountValue = a;
          final rate = ((a['milk_rate_paisa'] as int? ?? 0) / 100).toStringAsFixed(2);
          return ListView(padding: const EdgeInsets.all(14), children: [
            Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [
              CircleAvatar(radius: 30, backgroundColor: const Color(0xFFE0F8E8),
                child: Text(a['account_number'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF087B32)))),
              const SizedBox(height: 8),
              Text(a['customer_name']?.toString() ?? '', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const Divider(),
              _info(t('والد کا نام','Father name','पिता का नाम'), a['father_name']?.toString() ?? ''),
              _info(t('فون نمبر','Phone','फ़ोन'), '${a['country_code'] ?? ''} ${a['phone_number'] ?? ''}'),
              _info(t('شروع ہونے کی تاریخ','Account started','खाता शुरू'), _date(_local(a['start_at']) ?? DateTime.now())),
              _info(t('موجودہ دودھ ریٹ فی کلو','Current milk rate/kg','दूध का रेट/kg'), 'Rs. $rate'),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _edit(a), icon: const Icon(Icons.edit), label: Text(t('اکاؤنٹ میں ترمیم','Edit account','खाता संपादित करें')))),
            ]))),
            const SizedBox(height: 10),
            Text(t('حساب دیکھنے کا دورانیہ','Choose ledger period','खाते की अवधि चुनें'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _choice(_ActivityRange.month, t('یہ مہینہ','This month','यह महीना')),
              _choice(_ActivityRange.last15Days, t('پچھلے 15 دن','Last 15 days','पिछले 15 दिन')),
              _choice(_ActivityRange.all, t('شروع سے آخر تک','From start to end','शुरू से अब तक')),
              _choice(_ActivityRange.custom, t('اپنی تاریخیں','Custom dates','अपनी तारीखें')),
            ]),
            if (_range == _ActivityRange.month)
              OutlinedButton.icon(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month), label: Text('${_month.year}/${_month.month.toString().padLeft(2, '0')}')),
            if (_range == _ActivityRange.custom)
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _pickCustom(true), child: Text('${t('شروع','From','से')}: ${_date(_from)}'))),
                const SizedBox(width: 7),
                Expanded(child: OutlinedButton(onPressed: () => _pickCustom(false), child: Text('${t('آخر','To','तक')}: ${_date(_to)}'))),
              ]),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, Object?>>>(
              future: _records,
              builder: (context, records) {
                if (records.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (records.hasError) return Text(records.error.toString());
                final list = records.data ?? [];
                var milk = 0, grams = 0, advances = 0, received = 0;
                for (final row in list) {
                  switch (row['activity_type']) {
                    case 'milk': milk += row['total_paisa'] as int; grams += row['quantity_grams'] as int;
                    case 'advance': advances += row['amount_paisa'] as int;
                    case 'payment': received += row['amount_paisa'] as int;
                  }
                }
                final balance = milk + advances - received;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Card(color: const Color(0xFFDFF1FF), child: Padding(padding: const EdgeInsets.all(12), child: Wrap(
                    alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 10, children: [
                      _total(t('دودھ کی رقم','Milk total','दूध रकम'), _money(milk)),
                      _total(t('دودھ کی مقدار','Milk quantity','दूध मात्रा'), '${(grams / 1000).toStringAsFixed(3)} kg'),
                      _total(t('ایڈوانس دیا','Advance given','एडवांस दिया'), _money(advances)),
                      _total(t('رقم وصول','Payments received','रकम मिली'), _money(received)),
                      _total(t('باقی بیلنس','Balance','बाकी बैलेंस'), _money(balance)),
                    ]))),
                  Text(t('روزانہ کی مکمل تفصیل','Daily activity details','दैनिक पूरा विवरण'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t('اس دورانیے میں کوئی ریکارڈ نہیں','No records in this period','इस अवधि में कोई रिकॉर्ड नहीं'), textAlign: TextAlign.center)),
                  ...list.map(_activityCard),
                ]);
              },
            ),
          ]);
        },
      ),
    ),
  );

  Widget _choice(_ActivityRange value, String label) => ChoiceChip(
    label: Text(label), selected: _range == value,
    onSelected: (_) => setState(() { _range = value; _refresh(); }));

  Widget _info(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF52677D)))), Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)))]));
  Widget _total(String label, String value) => SizedBox(width: 145, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
  Widget _activityCard(Map<String, Object?> row) {
    final type = row['activity_type'];
    final isMilk = type == 'milk', isNaga = type == 'naga', isAdvance = type == 'advance';
    final dt = isNaga ? null : _local(row['recorded_at']);
    final day = isNaga ? DateTime.tryParse(row['day'].toString()) : dt;
    final date = day == null ? '—' : _date(day);
    final time = isNaga ? (row['recorded_time'] ?? '00:00').toString()
      : dt == null ? '' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final title = isMilk ? t('دودھ','Milk','दूध') : isNaga ? t('ناگا / دودھ نہیں آیا','No milk / Naga','नागा') : isAdvance ? t('ایڈوانس دیا','Advance given','एडवांस दिया') : t('رقم وصول کی','Payment received','रकम प्राप्त');
    String detail;
    String amount;
    if (isMilk) {
      detail = '${(row['quantity_grams'] as int) / 1000} kg • FAT: ${row['fat_value'] ?? '—'} • Rate: ${_money(row['rate_paisa_per_kg'])}/kg';
      amount = _money(row['total_paisa']);
    } else if (isNaga) {
      detail = (row['note']?.toString().isNotEmpty ?? false) ? row['note'].toString() : t('اس دن دودھ درج نہیں ہوا','No milk recorded that day','उस दिन दूध दर्ज नहीं हुआ');
      amount = '—';
    } else {
      detail = row['note']?.toString() ?? '';
      amount = _money(row['amount_paisa']);
    }
    return Card(color: Colors.white, child: ListTile(
      leading: CircleAvatar(backgroundColor: isMilk ? const Color(0xFFDFF1FF) : isNaga ? const Color(0xFFFFE3E3) : const Color(0xFFFFF2C6),
        child: Icon(isMilk ? Icons.water_drop : isNaga ? Icons.event_busy : isAdvance ? Icons.call_made : Icons.call_received)),
      title: Text('$title • $date  $time', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(detail), trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold))));
  }
}
