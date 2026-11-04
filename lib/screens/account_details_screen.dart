import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/account_repository.dart';
import '../data/account_activity_repository.dart';
import 'new_account_screen.dart';
import '../services/report_export_service.dart';

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
  final _export = ReportExportService();
  bool _exporting = false;
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
  DateTime get _end {
    switch (_range) {
      case _ActivityRange.month:
        return DateTime(_month.year, _month.month + 1, 0);
      case _ActivityRange.last15Days:
      case _ActivityRange.custom:
        return DateTime(_to.year, _to.month, _to.day);
      case _ActivityRange.all:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
    }
  }
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

  void _refresh() => _records = _load();

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

  String _reportText(Map<String, Object?> account,
      List<Map<String, Object?>> records) {
    var milk = 0;
    var grams = 0;
    var advances = 0;
    var noMilkDays = 0;

    for (final row in records) {
      switch (row['activity_type']) {
        case 'milk':
          milk += (row['total_paisa'] as int?) ?? 0;
          grams += (row['quantity_grams'] as int?) ?? 0;
        case 'advance':
          advances += (row['amount_paisa'] as int?) ?? 0;
        case 'naga':
          noMilkDays++;
      }
    }

    final lines = <String>[
      'Milk Account — ${account['customer_name'] ?? ''}',
      '${t('کھاتہ نمبر', 'Account number', 'खाता नंबर')}: ${account['account_number'] ?? ''}',
      '${t('والد کا نام', 'Father name', 'पिता का नाम')}: ${account['father_name'] ?? ''}',
      '${t('فون نمبر', 'Phone', 'फ़ोन')}: ${account['country_code'] ?? ''} ${account['phone_number'] ?? ''}',
      '${t('مدت', 'Period', 'अवधि')}: ${_date(_start)} — ${_date(_end)}',
      '',
      '${t('کل دودھ', 'Total milk', 'कुल दूध')}: ${(grams / 1000).toStringAsFixed(3)} kg',
      '${t('دودھ کی کل رقم', 'Milk amount', 'दूध की रकम')}: ${_money(milk)}',
      if (advances > 0)
        '${t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया')}: ${_money(advances)}',
      if (advances > 0)
        '${t('باقی ایڈوانس', 'Remaining advance', 'बाकी एडوانس')}: ${_money((advances - milk).clamp(0, advances))}',
      '${t('ناگا کے دن', 'No-milk days', 'नागा दिन')}: $noMilkDays',
      '',
      t('مکمل روزانہ تفصیل', 'Complete daily details', 'पूरी दैनिक जानकारी'),
    ];

    for (final row in records) {
      final type = row['activity_type'];
      final isMilk = type == 'milk';
      final isNaga = type == 'naga';
      final isAdvance = type == 'advance';
      final dt = isNaga ? null : _local(row['recorded_at']);
      final day = isNaga ? DateTime.tryParse(row['day'].toString()) : dt;
      final date = day == null ? '—' : _date(day);
      final time = isNaga
          ? (row['recorded_time'] ?? '00:00').toString()
          : dt == null
              ? ''
              : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      String detail;
      String amount;
      if (isMilk) {
        detail = '${(row['quantity_grams'] as int) / 1000} kg • FAT: ${row['fat_value'] ?? '—'} • ${t('ریٹ', 'Rate', 'रेट')}: ${_money(row['rate_paisa_per_kg'])}/kg';
        amount = _money(row['total_paisa']);
      } else if (isNaga) {
        detail = row['note']?.toString() ?? '';
        amount = '—';
      } else {
        detail = row['note']?.toString() ?? '';
        amount = _money(row['amount_paisa']);
      }

      final title = isMilk
          ? t('دودھ', 'Milk', 'दूध')
          : isNaga
              ? t('ناگا', 'No milk', 'नागा')
              : isAdvance
                  ? t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया')
                  : t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया');
      lines.add('$date $time | $title | $detail | $amount');
    }

    return lines.join('\n');
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _exportReport(
    String action,
    Map<String, Object?> account,
    List<Map<String, Object?>> records,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final message = _reportText(account, records);
      final number = account['account_number'] ?? 'account';
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: message));
        _message(t('مکمل رپورٹ کاپی ہو گئی', 'Complete report copied', 'पूरी रिपोर्ट कॉपी हो गई'));
      } else if (action == 'sms') {
        final opened = await _export.sendSms(message);
        _message(opened
            ? t('SMS کے لیے رپورٹ تیار ہے', 'Report is ready in SMS', 'SMS के लिए रिपोर्ट तैयार है')
            : t('SMS ایپ نہیں کھل سکی', 'Could not open SMS app', 'SMS ऐप नहीं खुल सकी'));
      } else if (action == 'whatsapp') {
        final opened = await _export.shareWhatsApp(message);
        _message(opened
            ? t('WhatsApp کے لیے رپورٹ تیار ہے', 'Report is ready in WhatsApp', 'WhatsApp के लिए रिपोर्ट तैयार है')
            : t('WhatsApp نہیں کھل سکا', 'WhatsApp could not be opened', 'WhatsApp नहीं खुला'));
      } else {
        final pdf = await _export.createPdf(
          title: 'Milk Account — $number — ${account['customer_name'] ?? ''}',
          lines: message.split('\n'),
        );
        if (action == 'print') {
          await _export.printPdf(pdf);
        } else {
          await _export.sharePdf(pdf, 'milk-account-account-$number.pdf');
        }
      }
    } catch (error) {
      _message('${t('رپورٹ تیار نہیں ہو سکی', 'Could not prepare report', 'रिपोर्ट तैयार नहीं हुई')}: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _reportButton(
    String action,
    String label,
    IconData icon,
    Color color,
    Map<String, Object?> account,
    List<Map<String, Object?>> records,
  ) => OutlinedButton.icon(
        onPressed: _exporting ? null : () => _exportReport(action, account, records),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        ),
      );

  Widget _reportActions(
    Map<String, Object?> account,
    List<Map<String, Object?>> records,
  ) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Text(
            t('رپورٹ شیئر کریں یا کاپی کریں', 'Share or copy report', 'रिपोर्ट साझा या कॉपी करें'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _reportButton('print', t('پرنٹ', 'Print', 'प्रिंट'), Icons.print, const Color(0xFF0756C9), account, records),
              _reportButton('sms', 'SMS', Icons.sms, const Color(0xFF079B37), account, records),
              _reportButton('whatsapp', 'WhatsApp', Icons.chat, const Color(0xFF168B45), account, records),
              _reportButton('pdf', t('رپورٹ شیئر کریں', 'Share report', 'रिपोर्ट साझा करें'), Icons.share, const Color(0xFF7B1FA2), account, records),
              _reportButton('copy', t('مکمل رپورٹ کاپی کریں', 'Copy complete report', 'पूरी रिपोर्ट कॉपी करें'), Icons.copy, const Color(0xFFB07A00), account, records),
            ],
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
        ],
      );


  Widget _ledgerTable(List<Map<String, Object?>> records) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          t('اس دورانیے میں کوئی ریکارڈ نہیں', 'No records in this period',
              'इस अवधि में कोई रिकॉर्ड नहीं'),
          textAlign: TextAlign.center,
        ),
      );
    }

    String sortKey(Map<String, Object?> row) {
      if (row['activity_type'] == 'naga') {
        return '${row['day'].toString().substring(0, 10)}T${row['recorded_time'] ?? '00:00'}';
      }
      return _local(row['recorded_at'])?.toIso8601String() ?? '';
    }

    final ordered = [...records]
      ..sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    var balancePaisa = 0;
    final rows = <DataRow>[];

    for (final row in ordered) {
      final type = row['activity_type'];
      final isMilk = type == 'milk';
      final isNaga = type == 'naga';
      final isAdvance = type == 'advance';
      final dt = isNaga ? null : _local(row['recorded_at']);
      final day = isNaga ? DateTime.tryParse(row['day'].toString()) : dt;
      final date = day == null ? '—' : _date(day);
      final time = isNaga
          ? (row['recorded_time'] ?? '00:00').toString()
          : dt == null
              ? '—'
              : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      final amount = (row['total_paisa'] as int?) ?? 0;
      final advanceAmount = (row['amount_paisa'] as int?) ?? 0;
      if (isAdvance) balancePaisa += advanceAmount;
      if (isMilk) balancePaisa -= amount;

      final milkLabel = isMilk
          ? ((row['quantity_grams'] as int) / 1000).toStringAsFixed(1)
          : isNaga
              ? t('ناگا', 'No milk', 'नागा')
              : '—';
      final rate = isMilk
          ? (((row['rate_paisa_per_kg'] as int?) ?? 0) / 100)
              .toStringAsFixed(2)
          : '—';
      final fat = isMilk ? (row['fat_value'] ?? '—').toString() : '—';
      final milkAmount = isMilk ? _money(amount) : isNaga ? '0' : '—';
      final advance = isAdvance ? _money(advanceAmount) : '—';

      rows.add(DataRow(
        color: isNaga
            ? MaterialStateProperty.all(const Color(0xFFFFE3E3))
            : null,
        cells: [
          DataCell(Text(date)),
          DataCell(Text(time)),
          DataCell(Text(milkLabel,
              style: TextStyle(
                color: isNaga ? Colors.red.shade700 : Colors.black87,
                fontWeight: FontWeight.w800,
              ))),
          DataCell(Text(rate)),
          DataCell(Text(fat)),
          DataCell(Text(milkAmount)),
          DataCell(Text(advance)),
          DataCell(Text(_money(balancePaisa),
              style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFF0649AE)),
        headingTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
        columnSpacing: 14,
        horizontalMargin: 10,
        columns: [
          DataColumn(label: Text(t('تاریخ', 'Date', 'तारीख'))),
          DataColumn(label: Text(t('وقت', 'Time', 'समय'))),
          DataColumn(label: Text(t('دودھ کلو', 'Milk kg', 'दूध kg'))),
          DataColumn(label: Text(t('ریٹ / کلو', 'Rate/kg', 'रेट/kg'))),
          DataColumn(label: Text('FAT %')),
          DataColumn(label: Text(t('دودھ قیمت', 'Milk amount', 'दूध रकम'))),
          DataColumn(label: Text(t('ایڈوانس', 'Advance', 'एडवांस'))),
          DataColumn(label: Text(t('بقایا', 'Balance', 'बाकी'))),
        ],
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: SafeArea(top: false, child: Scaffold(
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
                var milk = 0, grams = 0, advances = 0;
                for (final row in list) {
                  switch (row['activity_type']) {
                    case 'milk': milk += row['total_paisa'] as int; grams += row['quantity_grams'] as int;
                    case 'advance': advances += row['amount_paisa'] as int;
                  }
                }
                final hasAdvance = advances > 0;
                final remainingAdvance = (advances - milk).clamp(0, advances);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Card(color: const Color(0xFFDFF1FF), child: Padding(padding: const EdgeInsets.all(12), child: Wrap(
                    alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 10, children: [
                      _total(t('دودھ کی رقم','Milk total','दूध रकम'), _money(milk)),
                      _total(t('دودھ کی مقدار','Milk quantity','दूध मात्रा'), '${(grams / 1000).toStringAsFixed(3)} kg'),
                      if (hasAdvance)
                        _total(t('ایڈوانس دیا','Advance given','एडवांस दिया'), _money(advances)),
                      if (hasAdvance)
                        _total(t('باقی ایڈوانس','Remaining advance','बाकी एडوانس'), _money(remainingAdvance)),
                    ]))),
                  Text(t('ماہانہ دودھ اور ایڈوانس کا مکمل حساب','Complete monthly milk and advance ledger','मासिक दूध और एडवांस का पूरा हिसाब'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _ledgerTable(list),
                  _reportActions(a, list),
                ]);
              },
            ),
          ]);
        },
      ),
    )),
  );

  Widget _choice(_ActivityRange value, String label) => ChoiceChip(
    label: Text(label), selected: _range == value,
    onSelected: (_) => setState(() { _range = value; _refresh(); }));

  Widget _info(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF52677D)))), Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)))]));
  Widget _total(String label, String value) => SizedBox(width: 145, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));

}
