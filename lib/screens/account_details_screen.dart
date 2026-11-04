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
    child: SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3E7F0),
        appBar: AppBar(
          title: Text(t('اکاؤنٹ کی مکمل تفصیل', 'Complete Account Ledger', 'खाते का पूरा विवरण')),
          backgroundColor: const Color(0xFF0649AE),
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F3FA), Color(0xFFD1D5E2)],
            ),
          ),
          child: FutureBuilder<Map<String, Object?>?>(
            future: _account,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final a = snapshot.data;
              if (snapshot.hasError || a == null) return Center(child: Text(t('اکاؤنٹ نہیں ملا', 'Account not found', 'खाता नहीं मिला')));
              _accountValue = a;
              final rate = ((a['milk_rate_paisa'] as int? ?? 0) / 100).toStringAsFixed(2);
              final phone = '${a['country_code'] ?? ''} ${a['phone_number'] ?? ''}'.trim();
              final flag = (a['country_code']?.toString() ?? '+92') == '+92' ? '🇵🇰' : '🌐';
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 22),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(17, 20, 17, 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFFF8FAFF), Color(0xFFDDE1EC)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 13, offset: Offset(-5, -5)),
                        BoxShadow(color: Color(0x55818A9F), blurRadius: 15, offset: Offset(6, 8)),
                      ],
                    ),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 44, backgroundColor: const Color(0xFFDDF6E8),
                        child: Text(a['account_number'].toString(),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF087B32))),
                      ),
                      const SizedBox(height: 13),
                      Text(a['customer_name']?.toString() ?? '', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: Color(0xFF111318))),
                      const SizedBox(height: 2),
                      Text('${t('والد:', 'Father:', 'पिता:')} ${a['father_name']?.toString() ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF20232B))),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Color(0xFFBFC4D0), height: 1)),
                      _detailRow(t('فون نمبر', 'Phone number', 'फ़ोन नंबर'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.white, Color(0xFFE2E6F0)]),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFB9BFCE), width: 1.4),
                            boxShadow: const [
                              BoxShadow(color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
                              BoxShadow(color: Color(0x33818A9F), blurRadius: 5, offset: Offset(2, 3)),
                            ],
                          ),
                          child: Directionality(textDirection: TextDirection.ltr,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(flag, style: const TextStyle(fontSize: 25)),
                              const SizedBox(width: 6),
                              Flexible(child: FittedBox(fit: BoxFit.scaleDown,
                                child: Text(phone, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))),
                              const SizedBox(width: 5),
                              const Icon(Icons.call, color: Color(0xFF66759A), size: 22),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      _detailRow(t('شروع ہونے کی تاریخ', 'Account start date', 'खाता शुरू होने की तारीख'),
                        Directionality(textDirection: TextDirection.ltr,
                          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                            Text(_date(_local(a['start_at']) ?? DateTime.now()),
                              style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 9),
                            const Icon(Icons.calendar_month, color: Color(0xFF8A755B), size: 27),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 13),
                      _detailRow(t('موجودہ دودھ ریٹ فی کلو', 'Current milk rate/kg', 'दूध का मौजूदा रेट/kg'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(color: const Color(0xFFE8EBF3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFAEB5C5), width: 1.3)),
                          child: Directionality(textDirection: TextDirection.ltr,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('🥛', style: TextStyle(fontSize: 26)),
                              const SizedBox(width: 8),
                              Text('Rs. ${rate}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      _softButton(onPressed: () => _edit(a),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(t('اکاؤنٹ میں ترمیم', 'Edit account', 'खाता संपादित करें'),
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 9),
                          const Icon(Icons.edit, color: Color(0xFF45577E), size: 23),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  Text(t('حساب دیکھنے کا دورانیہ', 'Choose ledger period', 'खाते की अवधि चुनें'),
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF111318))),
                  const SizedBox(height: 13),
                  Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                    _choice(_ActivityRange.month, t('یہ مہینہ', 'This month', 'यह महीना')),
                    _choice(_ActivityRange.last15Days, t('پچھلے 15 دن', 'Last 15 days', 'पिछले 15 दिन')),
                    _choice(_ActivityRange.all, t('شروع سے آخر تک', 'From start to end', 'शुरू से अब तक')),
                    _choice(_ActivityRange.custom, t('اپنی تاریخیں', 'Custom dates', 'अपनी तारीखें')),
                  ]),
                  if (_range == _ActivityRange.month)
                    Padding(padding: const EdgeInsets.only(top: 13),
                      child: _softButton(onPressed: _pickMonth, radius: 40,
                        child: Directionality(textDirection: TextDirection.ltr,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${_month.year}/${_month.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF435A83))),
                            const SizedBox(width: 12),
                            const Icon(Icons.calendar_month, color: Color(0xFF435A83), size: 25),
                          ]),
                        ),
                      ),
                    ),
                  if (_range == _ActivityRange.custom)
                    Padding(padding: const EdgeInsets.only(top: 13),
                      child: Row(children: [
                        Expanded(child: _softButton(onPressed: () => _pickCustom(true),
                          child: Text('${t('شروع', 'From', 'से')}: ${_date(_from)}'))),
                        const SizedBox(width: 9),
                        Expanded(child: _softButton(onPressed: () => _pickCustom(false),
                          child: Text('${t('آخر', 'To', 'तक')}: ${_date(_to)}'))),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, Object?>>>(future: _records, builder: (context, records) {
                    if (records.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                    if (records.hasError) return Text(records.error.toString());
                    final list = records.data ?? [];
                    var milk = 0, grams = 0, advances = 0;
                    for (final row in list) {
                      switch (row['activity_type']) {
                        case 'milk':
                          milk += row['total_paisa'] as int;
                          grams += row['quantity_grams'] as int;
                        case 'advance':
                          advances += row['amount_paisa'] as int;
                      }
                    }
                    final hasAdvance = advances > 0;
                    final remainingAdvance = (advances - milk).clamp(0, advances);
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF6F8FD), Color(0xFFE1E5EF)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: const [BoxShadow(color: Color(0x33818A9F), blurRadius: 9, offset: Offset(3, 4))],
                        ),
                        child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12, children: [
                          _total(t('دودھ کی رقم', 'Milk total', 'दूध रकम'), _money(milk)),
                          _total(t('دودھ کی مقدار', 'Milk quantity', 'दूध मात्रा'), '${(grams / 1000).toStringAsFixed(3)} kg'),
                          if (hasAdvance) _total(t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया'), _money(advances)),
                          if (hasAdvance) _total(t('باقی ایڈوانس', 'Remaining advance', 'बाकी एडवांस'), _money(remainingAdvance)),
                        ]),
                      ),
                      const SizedBox(height: 13),
                      Text(t('ماہانہ دودھ اور ایڈوانس کا مکمل حساب', 'Complete monthly milk and advance ledger', 'मासिक दूध और एडवांस का पूरा हिसाब'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      _ledgerTable(list),
                      _reportActions(a, list),
                    ]);
                  }),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _detailRow(String label, Widget value) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(flex: 5, child: Text(label, style: const TextStyle(fontSize: 18, color: Color(0xFF333B4C), height: 1.5))),
      const SizedBox(width: 8),
      Expanded(flex: 6, child: Align(alignment: Alignment.centerLeft, child: value)),
    ],
  );

  Widget _softButton({required VoidCallback onPressed, required Widget child, double radius = 18}) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF9FAFF), Color(0xFFDDE1EC)]),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.white, blurRadius: 7, offset: Offset(-3, -3)),
            BoxShadow(color: Color(0x55818A9F), blurRadius: 8, offset: Offset(4, 5)),
          ],
        ),
        child: Center(child: child),
      ),
    ),
  );

  Widget _choice(_ActivityRange value, String label) {
    final selected = _range == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() { _range = value; _refresh(); }),
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            gradient: selected
              ? const LinearGradient(colors: [Color(0xFFFFFDF5), Color(0xFFE8E2D3)])
              : const LinearGradient(colors: [Color(0xFFF9FAFF), Color(0xFFDDE1EC)]),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? const Color(0xFFC7AC63) : Colors.white, width: selected ? 2 : 1.4),
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(.9), blurRadius: 6, offset: const Offset(-3, -3)),
              const BoxShadow(color: Color(0x55818A9F), blurRadius: 7, offset: Offset(3, 4)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, color: Color(0xFF62563A), size: 21),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _total(String label, String value) => SizedBox(width: 145, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));

}
