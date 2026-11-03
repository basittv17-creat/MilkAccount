import 'package:flutter/material.dart';
import '../data/no_milk_repository.dart';

class NoMilkScreen extends StatefulWidget {
  const NoMilkScreen({super.key, required this.language});
  final String language;
  @override
  State<NoMilkScreen> createState() => _NoMilkScreenState();
}

class _NoMilkScreenState extends State<NoMilkScreen> {
  final _repo = NoMilkRepository();
  final _note = TextEditingController();
  late Future<List<Map<String, Object?>>> _accounts;
  List<Map<String, Object?>> _rows = [];
  String? _accountId;
  DateTime _day = DateTime.now();
  bool _saving = false;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) =>
      _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() {
    super.initState();
    _accounts = _repo.activeAccounts();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save() async {
    if (_accountId == null) return;
    setState(() => _saving = true);
    try {
      await _repo.markNoMilk(
          accountId: _accountId!, day: _day, note: _note.text);
      if (!mounted) return;
      _note.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('ناگا کا دن محفوظ ہو گیا', 'No-milk day saved',
              'दूध न आने का दिन सेव हो गया'))));
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : t('ریکارڈ محفوظ نہیں ہو سکا', 'Could not save record',
              'रिकॉर्ड सेव नहीं हो सका');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F9FF),
          appBar: AppBar(
            title: Text(t('دودھ نہ آنے کا دن (ناگا)', 'No-Milk Day (Naga)',
                'दूध न आने का दिन (नागा)')),
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
              _rows = snapshot.data ?? [];
              if (_rows.isEmpty) {
                return Center(child: Text(t('پہلے نیا کھاتہ بنائیں',
                    'Create an account first', 'पहले खाता बनाएँ')));
              }
              _accountId ??= _rows.first['id'] as String;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _accountId,
                    decoration: _dec(t('گاہک کا کھاتہ', 'Customer account',
                        'ग्राहक खाता')),
                    items: _rows.map((row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('#${row['account_number']} — ${row['customer_name']}'),
                    )).toList(),
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('${_day.day}/${_day.month}/${_day.year}'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2C6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2A000)),
                    ),
                    child: Text(t(
                      'اس تاریخ پر اس گاہک کا دودھ نہیں آیا۔ یہ اندراج دودھ کی رقم صفر رکھے گا اور ماہانہ کھاتے میں ناگا کے طور پر نظر آئے گا۔',
                      'No milk was received from this customer on this date. This records a zero-milk day and displays it in the monthly ledger.',
                      'इस तारीख को इस ग्राहक का दूध नहीं आया। यह शून्य-दूध दिन दर्ज करेगा और मासिक खाते में दिखेगा।',
                    )),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: _dec(t('نوٹس (اختیاری)', 'Notes (optional)',
                        'नोट्स (वैकल्पिक)')),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.event_busy),
                      label: Text(_saving
                          ? t('محفوظ ہو رہا ہے', 'Saving...', 'सेव हो रहा है')
                          : t('ناگا محفوظ کریں', 'Save No-Milk Day',
                              'नागा सेव करें')),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE2A000),
                          foregroundColor: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
