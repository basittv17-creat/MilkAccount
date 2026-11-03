import 'package:flutter/material.dart';
import '../data/milk_entry_repository.dart';

class MilkEntryScreen extends StatefulWidget {
  const MilkEntryScreen({super.key, required this.language});
  final String language;
  @override
  State<MilkEntryScreen> createState() => _MilkEntryScreenState();
}

class _MilkEntryScreenState extends State<MilkEntryScreen> {
  final _repo = MilkEntryRepository();
  final _quantity = TextEditingController();
  final _fat = TextEditingController();
  final _note = TextEditingController();
  late Future<List<Map<String, Object?>>> _accounts;
  String? _accountId;
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) => _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() {
    super.initState();
    _accounts = _repo.activeAccounts();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _fat.dispose();
    _note.dispose();
    super.dispose();
  }

  Map<String, Object?>? get _selected {
    final rows = _accountsValue;
    for (final row in rows) {
      if (row['id'] == _accountId) return row;
    }
    return null;
  }

  List<Map<String, Object?>> _accountsValue = [];

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context, initialDate: _recordedAt,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date != null && mounted) {
      setState(() => _recordedAt = DateTime(
        date.year, date.month, date.day, _recordedAt.hour, _recordedAt.minute));
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(_recordedAt));
    if (time != null && mounted) {
      setState(() => _recordedAt = DateTime(
        _recordedAt.year, _recordedAt.month, _recordedAt.day,
        time.hour, time.minute));
    }
  }

  Future<void> _save() async {
    final account = _selected;
    final kg = double.tryParse(_quantity.text.trim());
    if (account == null || kg == null || !kg.isFinite || kg <= 0) {
      _message(t('کھاتہ منتخب کریں اور دودھ کی مقدار درست درج کریں',
        'Select an account and enter a valid milk quantity',
        'खाता चुनें और दूध की सही मात्रा दर्ज करें'));
      return;
    }
    final fatEnabled = (account['fat_enabled'] as int? ?? 0) == 1;
    final fat = fatEnabled && _fat.text.trim().isNotEmpty
        ? double.tryParse(_fat.text.trim()) : null;
    if (fatEnabled && _fat.text.trim().isNotEmpty &&
        (fat == null || !fat.isFinite || fat < 0 || fat > 15)) {
      _message(t('FAT کی مقدار 0 سے 15 کے درمیان درج کریں',
        'FAT must be between 0 and 15', 'FAT 0 से 15 के बीच दर्ज करें'));
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.createEntry(
        accountId: _accountId!,
        recordedAt: _recordedAt,
        quantityGrams: (kg * 1000).round(),
        fatValue: fat,
        ratePaisaPerKg: account['milk_rate_paisa'] as int? ?? 0,
        note: _note.text,
      );
      if (mounted) {
        _quantity.clear();
        _fat.clear();
        _note.clear();
        _message(t('دودھ کا اندراج محفوظ ہو گیا',
          'Milk entry saved successfully', 'दूध की एंट्री सेव हो गई'));
      }
    } catch (error) {
      _message('Could not save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(
        title: Text(t('روزانہ دودھ کا اندراج', 'Daily Milk Entry', 'रोज़ाना दूध की एंट्री')),
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(t('کھاتے لوڈ نہیں ہو سکے',
              'Could not load accounts', 'खाते लोड नहीं हो सके')));
          }
          _accountsValue = snapshot.data ?? [];
          if (_accountsValue.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('پہلے ایک نیا کھاتہ بنائیں',
                'Create an account before entering milk',
                'दूध दर्ज करने से पहले खाता बनाएँ'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
          }
          if (_accountId == null ||
              !_accountsValue.any((a) => a['id'] == _accountId)) {
            _accountId = _accountsValue.first['id'] as String;
          }
          final account = _selected!;
          final ratePaisa = account['milk_rate_paisa'] as int? ?? 0;
          final rate = (ratePaisa / 100).toStringAsFixed(2);
          final fatEnabled = (account['fat_enabled'] as int? ?? 0) == 1;
          return ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<String>(
              value: _accountId,
              decoration: _dec(t('گاہک کا کھاتہ', 'Customer account', 'ग्राहक खाता')),
              items: _accountsValue.map((a) => DropdownMenuItem(
                value: a['id'] as String,
                child: Text('#${a['account_number']} — ${a['customer_name']}'))).toList(),
              onChanged: (value) => setState(() => _accountId = value)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD6E8F8))),
              child: Row(children: [
                Expanded(child: Text(t('دودھ کا ریٹ فی کلو', 'Milk rate per kg', 'दूध का रेट प्रति किलो'))),
                Text('Rs. $rate', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF087B32))),
              ])),
            const SizedBox(height: 14),
            TextFormField(controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(t('دودھ کی مقدار (کلو)', 'Milk quantity (kg)', 'दूध की मात्रा (kg)'))),
            if (fatEnabled) ...[
              const SizedBox(height: 14),
              TextFormField(controller: _fat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec('FAT (%)')),
            ],
            const SizedBox(height: 14),
            Text(t('تاریخ اور وقت', 'Date and time', 'तारीख और समय'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickDate, icon: const Icon(Icons.calendar_month),
                label: Text('${_recordedAt.day}/${_recordedAt.month}/${_recordedAt.year}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickTime, icon: const Icon(Icons.access_time),
                label: Text(TimeOfDay.fromDateTime(_recordedAt).format(context)))),
            ]),
            const SizedBox(height: 14),
            TextFormField(controller: _note, maxLines: 2,
              decoration: _dec(t('نوٹس (اختیاری)', 'Notes (optional)', 'नोट्स (वैकल्पिक)'))),
            const SizedBox(height: 20),
            SizedBox(height: 52, child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? t('محفوظ ہو رہا ہے', 'Saving...', 'सेव हो रहा है')
                : t('دودھ محفوظ کریں', 'Save Milk Entry', 'दूध सेव करें')),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF079B37),
                foregroundColor: Colors.white))),
          ]);
        }),
    ));
}
