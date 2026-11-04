import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/monthly_ledger_repository.dart';
import '../services/report_export_service.dart';
import 'milk_entry_screen.dart';
import 'milk_rate_screen.dart';

class MonthlyLedgerScreen extends StatefulWidget {
  const MonthlyLedgerScreen({super.key, required this.language});
  final String language;

  @override
  State<MonthlyLedgerScreen> createState() => _MonthlyLedgerScreenState();
}

class _MonthlyLedgerScreenState extends State<MonthlyLedgerScreen> {
  final _repo = MonthlyLedgerRepository();
  final _export = ReportExportService();
  late Future<List<Map<String, Object?>>> _accounts;
  Future<Map<String, Object?>>? _summary;
  Future<List<Map<String, Object?>>>? _activities;
  String? _accountId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _busy = false;
  bool _fatUpdating = false;

  bool get _ur => widget.language == 'ur';
  String t(String ur, String en, String hi) =>
      _ur ? ur : widget.language == 'hi' ? hi : en;

  @override
  void initState() {
    super.initState();
    _accounts = _repo.activeAccounts();
  }

  void _loadMonth() {
    final id = _accountId;
    if (id == null) return;
    _summary = _repo.summary(accountId: id, month: _month);
    _activities = _repo.activities(accountId: id, month: _month);
  }

  String _monthName(int month) {
    const ur = ['جنوری','فروری','مارچ','اپریل','مئی','جون','جولائی','اگست','ستمبر','اکتوبر','نومبر','دسمبر'];
    const en = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    const hi = ['जनवरी','फ़रवरी','मार्च','अप्रैल','मई','जून','जुलाई','अगस्त','सितंबर','अक्टूबर','नवंबर','दिसंबर'];
    final labels = _ur ? ur : widget.language == 'hi' ? hi : en;
    return labels[month - 1];
  }

  String _monthLabel() => _monthName(_month.month) + ' ' + _month.year.toString();

  String _money(Object? value) {
    final paisa = (value as num?)?.toInt() ?? 0;
    final sign = paisa < 0 ? '-Rs. ' : 'Rs. ';
    return sign + (paisa.abs() / 100).toStringAsFixed(2);
  }

  String _date(DateTime date) =>
      date.day.toString().padLeft(2, '0') + ' ' +
      _monthName(date.month) + ' ' + date.year.toString();

  String _dateFor(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null ? '—' : _date(date);
  }

  String _timeFor(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return date.hour.toString().padLeft(2, '0') + ':' +
        date.minute.toString().padLeft(2, '0');
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _loadMonth();
    });
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _month = DateTime(month.year, month.month, 1);
      _loadMonth();
    });
  }

  Future<void> _pickMonth() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: t('مہینہ منتخب کریں', 'Select month', 'महीना चुनें'),
    );
    if (value != null && mounted) _selectMonth(value);
  }

  void _selectAccount(String? id) {
    if (id == null) return;
    setState(() {
      _accountId = id;
      _loadMonth();
    });
  }

  Future<void> _openMilkEntry(Map<String, Object?> account) async {
    final monthStart = DateTime(_month.year, _month.month, 1);
    final accountStart = DateTime.tryParse(account['start_at']?.toString() ?? '')?.toLocal();
    final entryDate = accountStart != null && accountStart.isAfter(monthStart)
        ? DateTime(accountStart.year, accountStart.month, accountStart.day)
        : monthStart;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MilkEntryScreen(
          language: widget.language,
          initialAccountId: account['id'] as String,
          initialDate: entryDate,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _accounts = _repo.activeAccounts();
      _loadMonth();
    });
  }

  Future<void> _openRateSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => MilkRateScreen(language: widget.language)),
    );
    if (!mounted) return;
    setState(() {
      _accounts = _repo.activeAccounts();
      _loadMonth();
    });
  }

  Future<void> _toggleFat(Map<String, Object?> account, bool enabled) async {
    if (_fatUpdating) return;
    setState(() => _fatUpdating = true);
    try {
      await _repo.updateFatEnabled(
        accountId: account['id'] as String,
        enabled: enabled,
      );
      if (mounted) {
        setState(() => _accounts = _repo.activeAccounts());
        _message(enabled
            ? t('FAT کی سہولت فعال ہو گئی', 'FAT has been enabled', 'FAT चालू हो गया')
            : t('FAT کی سہولت بند ہو گئی', 'FAT has been disabled', 'FAT बंद हो गया'));
      }
    } catch (error) {
      _message(t('FAT کی ترتیب تبدیل نہیں ہو سکی', 'Could not update FAT setting', 'FAT सेटिंग नहीं बदली') + ': ' + error.toString());
    } finally {
      if (mounted) setState(() => _fatUpdating = false);
    }
  }

  String _reportText(
    Map<String, Object?> account,
    Map<String, Object?> summary,
    List<Map<String, Object?>> activities,
  ) {
    final lines = <String>[
      'Milk Account — ' + (account['customer_name'] ?? '').toString(),
      t('کھاتہ نمبر', 'Account number', 'खाता नंबर') + ': ' + (account['account_number'] ?? '').toString(),
      t('مہینہ', 'Month', 'महीना') + ': ' + _monthLabel(),
      '',
      t('کل دودھ', 'Total milk', 'कुल दूध') + ': ' +
          ((summary['milk_quantity_grams'] as int? ?? 0) / 1000).toStringAsFixed(3) + ' kg',
      t('کل قیمت', 'Total amount', 'कुल रकम') + ': ' + _money(summary['milk_total_paisa']),
      t('شروعاتی ایڈوانس', 'Opening advance', 'शुरुआती एडवांस') + ': ' + _money(summary['opening_advance_paisa']),
      t('بقایا ایڈوانس', 'Remaining advance', 'बाकी एडवांस') + ': ' + _money(summary['remaining_advance_paisa']),
      t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया') + ': ' + _money(summary['advance_given_paisa']),
      t('ناگا کے دن', 'No-milk days', 'नागा दिन') + ': ' + (summary['no_milk_days'] ?? 0).toString(),
      '',
      t('روزانہ کی مکمل تفصیل', 'Complete daily details', 'पूरी दैनिक जानकारी'),
    ];

    for (final row in activities) {
      final type = row['activity_type'];
      final date = type == 'naga'
          ? row['day'].toString().substring(0, 10)
          : _dateFor(row['recorded_at']);
      final time = type == 'naga'
          ? (row['recorded_time'] ?? '00:00').toString()
          : _timeFor(row['recorded_at']);
      if (type == 'milk') {
        lines.add(
          date + ' ' + time + ' | ' +
          ((row['quantity_grams'] as int) / 1000).toStringAsFixed(3) +
          ' kg | FAT ' + (row['fat_value'] ?? '—').toString() +
          '% | ' + _money(row['total_paisa']),
        );
      } else if (type == 'naga') {
        lines.add(date + ' ' + time + ' | ' +
            t('ناگا', 'No milk', 'नागा') + ' | ' +
            (row['note'] ?? '').toString());
      } else {
        lines.add(date + ' ' + time + ' | ' +
            t('ایڈوانس دیا', 'Advance given', 'एडवांस दिया') + ' | ' +
            _money(row['amount_paisa']) + ' | ' + (row['note'] ?? '').toString());
      }
    }
    return lines.join('\n');
  }

  Future<void> _shareReport(
    String action,
    Map<String, Object?> account,
    Map<String, Object?> summary,
    List<Map<String, Object?>> activities,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = _reportText(account, summary, activities);
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
            ? t('رپورٹ WhatsApp کے لیے تیار ہے', 'Report is ready for WhatsApp', 'रिपोर्ट WhatsApp के लिए तैयार है')
            : t('WhatsApp نہیں کھل سکا', 'Could not open WhatsApp', 'WhatsApp नहीं खुला'));
      } else {
        final pdf = await _export.createPdf(
          title: 'Milk Account — ' + (account['customer_name'] ?? '').toString() + ' — ' + _monthLabel(),
          lines: message.split('\n'),
        );
        await _export.printPdf(pdf);
        _message(t('رپورٹ پرنٹ کے لیے تیار ہے', 'Report is ready to print', 'रिपोर्ट प्रिंट के लिए तैयार है'));
      }
    } catch (error) {
      _message(t('رپورٹ تیار نہیں ہو سکی', 'Could not prepare report', 'रिपोर्ट तैयार नहीं हुई') + ': ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(value, style: const TextStyle(
      color: Color(0xFF0649AE), fontSize: 17, fontWeight: FontWeight.w900,
    )),
  );

  Widget _monthChip(DateTime month) {
    final selected = month.year == _month.year && month.month == _month.month;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: SizedBox(
          width: 75,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _monthName(month.month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : const Color(0xFF173D67),
              ),
            ),
            Text(
              month.year.toString(),
              style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : Colors.blueGrey),
            ),
          ]),
        ),
        selectedColor: const Color(0xFF0756C9),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFF0756C9) : const Color(0xFFB7D5EF)),
        onSelected: (_) => _selectMonth(month),
      ),
    );
  }

  Widget _monthPicker() => Column(children: [
    Row(children: [
      IconButton.filledTonal(
        onPressed: () => _changeMonth(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month),
          label: Text(_monthLabel(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF102C4C),
          ),
        ),
      ),
      IconButton.filledTonal(
        onPressed: () => _changeMonth(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ]),
    const SizedBox(height: 8),
    SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(
          5,
          (index) => _monthChip(DateTime(_month.year, _month.month - 1 + index, 1)),
        ),
      ),
    ),
  ]);

  Widget _accountCard(Map<String, Object?> account) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFE7F8EC), Colors.white]),
      border: Border.all(color: const Color(0xFF8BCF9C), width: 1.4),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(children: [
      const Icon(Icons.local_drink, size: 43, color: Color(0xFF547486)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#' + (account['account_number'] ?? '').toString() + '  ' +
                  (account['customer_name'] ?? '').toString(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if ((account['father_name'] ?? '').toString().isNotEmpty)
              Text(t('ولد:', 'S/O:', 'पुत्र:') + ' ' + account['father_name'].toString()),
            if ((account['phone_number'] ?? '').toString().isNotEmpty)
              Text((account['country_code'] ?? '').toString() + ' ' + account['phone_number'].toString()),
          ],
        ),
      ),
    ]),
  );

  Widget _metric(String title, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF173D67)),
        const SizedBox(height: 5),
        Text(title, maxLines: 2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );

  Widget _summaryMetrics(Map<String, Object?> values) {
    final milkKg = ((values['milk_quantity_grams'] as int? ?? 0) / 1000).toStringAsFixed(1);
    return Column(children: [
      Row(children: [
        Expanded(child: _metric(t('کل دودھ', 'Total milk', 'कुल दूध'), milkKg + ' kg', const Color(0xFFDDF5E4), Icons.local_drink)),
        const SizedBox(width: 7),
        Expanded(child: _metric(t('کل قیمت', 'Total amount', 'कुल रकम'), _money(values['milk_total_paisa']), const Color(0xFFDDEEFF), Icons.payments)),
      ]),
      const SizedBox(height: 7),
      Row(children: [
        Expanded(child: _metric(t('شروعاتی ایڈوانس', 'Opening advance', 'शुरुआती एडवांस'), _money(values['opening_advance_paisa']), const Color(0xFFFFF0C9), Icons.savings)),
        const SizedBox(width: 7),
        Expanded(child: _metric(t('بقایا ایڈوانس', 'Remaining advance', 'बाकी एडवांस'), _money(values['remaining_advance_paisa']), const Color(0xFFF2E2FF), Icons.account_balance_wallet)),
      ]),
    ]);
  }

  Widget _fatPanel(Map<String, Object?> account, Map<String, Object?> summary) {
    final enabled = (account['fat_enabled'] as int? ?? 0) == 1;
    final average = (summary['average_fat'] as num? ?? 0).toDouble();
    final count = summary['fat_entries'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF9BCDF3), width: 1.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(
            t('FAT (اختیاری)', 'FAT (optional)', 'FAT (वैकल्पिक)'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          )),
          Switch(
            value: enabled,
            onChanged: _fatUpdating ? null : (value) => _toggleFat(account, value),
            activeColor: const Color(0xFF079B37),
          ),
        ]),
        Row(children: [
          Expanded(child: Text(
            t('اس مہینے کی اوسط FAT', 'Monthly average FAT', 'इस महीने का औसत FAT'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F9FF),
              border: Border.all(color: const Color(0xFFB7D5EF)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count == 0 ? '—' : average.toStringAsFixed(1) + '%',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ]),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                t('FAT کی پیمائش اس کھاتے کے لیے بند ہے۔', 'FAT recording is disabled for this account.', 'इस खाते के लिए FAT रिकॉर्डिंग बंद है।'),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _detailSummary(Map<String, Object?> values) {
    final rows = <(String, String)>[
      (t('کل دن', 'Total days', 'कुल दिन'), (values['month_days'] ?? 0).toString()),
      (
        t('کل دودھ', 'Total milk', 'कुल दूध'),
        ((values['milk_quantity_grams'] as int? ?? 0) / 1000).toStringAsFixed(1) + ' kg',
      ),
      (t('کل قیمت', 'Total amount', 'कुल रकम'), _money(values['milk_total_paisa'])),
      (t('شروعاتی ایڈوانس', 'Opening advance', 'शुरुआती एडवांस'), _money(values['opening_advance_paisa'])),
      (t('بقایا ایڈوانس', 'Remaining advance', 'बाकी एडवांस'), _money(values['remaining_advance_paisa'])),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF9BCDF3), width: 1.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0756C9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Text(
            t('ماہانہ تفصیل', 'Monthly details', 'मासिक विवरण'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: i.isEven ? const Color(0xFFF1F8FF) : Colors.white,
              border: const Border(bottom: BorderSide(color: Color(0xFFE0EAF3))),
            ),
            child: Row(children: [
              Expanded(child: Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }

  Widget _activityTable(List<Map<String, Object?>> activities, Map<String, Object?> summary) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          t('اس مہینے ابھی کوئی اندراج موجود نہیں', 'No entries recorded for this month yet', 'इस महीने अभी कोई एंट्री दर्ज नहीं है'),
          textAlign: TextAlign.center,
        ),
      );
    }

    var runningBalance = summary['opening_balance_paisa'] as int? ?? 0;
    final rows = <DataRow>[];
    for (final row in activities) {
      final type = row['activity_type'];
      final isMilk = type == 'milk';
      final isNaga = type == 'naga';
      final isAdvance = type == 'advance';
      final date = isNaga
          ? row['day'].toString().substring(0, 10)
          : _dateFor(row['recorded_at']);
      final time = isNaga
          ? (row['recorded_time'] ?? '00:00').toString()
          : _timeFor(row['recorded_at']);

      final milkTotal = (row['total_paisa'] as int?) ?? 0;
      final amount = (row['amount_paisa'] as int?) ?? 0;
      if (isAdvance) runningBalance += amount;
      if (isMilk) runningBalance -= milkTotal;

      final milkValue = isMilk
          ? ((row['quantity_grams'] as int) / 1000).toStringAsFixed(1)
          : isNaga
              ? t('ناگا', 'No milk', 'नागा')
              : '—';
      final rate = isMilk ? _money(row['rate_paisa_per_kg']) : '—';
      final fat = isMilk && row['fat_value'] != null
          ? row['fat_value'].toString() + '%'
          : '—';

      rows.add(DataRow(
        color: isNaga ? WidgetStateProperty.all(const Color(0xFFFFE3E3)) : null,
        cells: [
          DataCell(Text(date)),
          DataCell(Text(time)),
          DataCell(Text(
            milkValue,
            style: TextStyle(
              color: isNaga ? Colors.red.shade700 : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          )),
          DataCell(Text(rate)),
          DataCell(Text(fat)),
          DataCell(Text(isMilk ? _money(milkTotal) : '—')),
          DataCell(Text(isAdvance ? _money(amount) : '—')),
          DataCell(Text(_money(runningBalance), style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF0756C9)),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
        dataTextStyle: const TextStyle(color: Color(0xFF172D43), fontSize: 12),
        columnSpacing: 13,
        horizontalMargin: 10,
        columns: [
          DataColumn(label: Text(t('تاریخ', 'Date', 'तारीख'))),
          DataColumn(label: Text(t('وقت', 'Time', 'समय'))),
          DataColumn(label: Text(t('دودھ کلو', 'Milk kg', 'दूध kg'))),
          DataColumn(label: Text(t('ریٹ / کلو', 'Rate / kg', 'रेट / kg'))),
          const DataColumn(label: Text('FAT %')),
          DataColumn(label: Text(t('دودھ قیمت', 'Milk amount', 'दूध रकम'))),
          DataColumn(label: Text(t('ایڈوانس', 'Advance', 'एडवांस'))),
          DataColumn(label: Text(t('بقایا', 'Balance', 'बाकी'))),
        ],
        rows: rows,
      ),
    );
  }

  Widget _reportActions(
    Map<String, Object?> account,
    Map<String, Object?> summary,
    List<Map<String, Object?>> activities,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(t('رپورٹ شیئر کریں', 'Share monthly report', 'मासिक रिपोर्ट साझा करें')),
      Row(children: [
        _reportButton('whatsapp', 'WhatsApp', Icons.chat, const Color(0xFF079B37), account, summary, activities),
        const SizedBox(width: 5),
        _reportButton('sms', 'SMS', Icons.sms, const Color(0xFF0756C9), account, summary, activities),
        const SizedBox(width: 5),
        _reportButton('print', t('پرنٹ', 'Print', 'प्रिंट'), Icons.print, const Color(0xFF7B1FA2), account, summary, activities),
        const SizedBox(width: 5),
        _reportButton('copy', t('کاپی', 'Copy', 'कॉपी'), Icons.copy, const Color(0xFFE0A000), account, summary, activities),
      ]),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
      const SizedBox(height: 9),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF079B37), size: 17),
          const SizedBox(width: 5),
          Text(
            t('تمام ڈیٹا محفوظ ہے', 'All data is saved', 'सारा डेटा सुरक्षित है'),
            style: const TextStyle(color: Color(0xFF087B32), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    ],
  );

  Widget _reportButton(
    String action,
    String label,
    IconData icon,
    Color color,
    Map<String, Object?> account,
    Map<String, Object?> summary,
    List<Map<String, Object?>> activities,
  ) => Expanded(
    child: SizedBox(
      height: 66,
      child: ElevatedButton(
        onPressed: _busy ? null : () => _shareReport(action, account, summary, activities),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    ),
  );

  Widget _ledgerContent(
    Map<String, Object?> account,
    Map<String, Object?> summary,
    List<Map<String, Object?>> activities,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _summaryMetrics(summary),
      const SizedBox(height: 10),
      _fatPanel(account, summary),
      const SizedBox(height: 14),
      _detailSummary(summary),
      const SizedBox(height: 17),
      _sectionTitle(t('روزانہ دودھ اور ایڈوانس کی تفصیل', 'Daily milk and advance details', 'दैनिक दूध और एडवांस विवरण')),
      _activityTable(activities, summary),
      const SizedBox(height: 17),
      _reportActions(account, summary, activities),
    ],
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: SafeArea(top: false, child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(
        title: Text(t('ماہانہ حساب', 'Monthly Ledger', 'मासिक खाता')),
        backgroundColor: const Color(0xFF0649AE),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return Center(child: Text(t('پہلے نیا کھاتہ بنائیں', 'Create an account first', 'पहले खाता बनाएँ')));
          }

          if (_accountId == null || !accounts.any((row) => row['id'] == _accountId)) {
            _accountId = accounts.first['id'] as String;
            _loadMonth();
          }
          final account = accounts.firstWhere((row) => row['id'] == _accountId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 24),
            children: [
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0756C9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t('ماہانہ حساب', 'Monthly Ledger', 'मासिक खाता'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: FilledButton.icon(
                      onPressed: _openRateSettings,
                      icon: const Icon(Icons.settings, size: 19),
                      label: Text(
                        t('دودھ کا ریٹ تبدیل کریں', 'Change milk rate', 'दूध का रेट बदलें'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF079B37),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 11),
              _accountCard(account),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _accountId,
                decoration: InputDecoration(
                  labelText: t('گاہک کا کھاتہ', 'Customer account', 'ग्राहक खाता'),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: accounts.map((row) => DropdownMenuItem<String>(
                  value: row['id'] as String,
                  child: Text(
                    '#' + row['account_number'].toString() + ' — ' + row['customer_name'].toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: _selectAccount,
              ),
              const SizedBox(height: 11),
              _monthPicker(),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFE3F8E8),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => _openMilkEntry(account),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    height: 72,
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 9, 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF64BC78),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_drink,
                          size: 42,
                          color: Color(0xFF079B37),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t(
                              'اس مہینے میں شامل کریں (دودھ، تاریخ، وقت، قیمت وغیرہ)',
                              'Add milk for this month (date, time and details)',
                              'इस महीने दूध जोड़ें (तारीख, समय और विवरण)',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF075A24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF079B37),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_summary == null || _activities == null)
                const Center(child: CircularProgressIndicator())
              else
                FutureBuilder<Map<String, Object?>>(
                  future: _summary,
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (summarySnapshot.hasError) return Text(summarySnapshot.error.toString());
                    return FutureBuilder<List<Map<String, Object?>>>(
                      future: _activities,
                      builder: (context, activitySnapshot) {
                        if (activitySnapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (activitySnapshot.hasError) return Text(activitySnapshot.error.toString());
                        return _ledgerContent(
                          account,
                          summarySnapshot.data!,
                          activitySnapshot.data ?? [],
                        );
                      },
                    );
                  },
                ),
            ],
          );
        },
      ),
    )),
  );
}
