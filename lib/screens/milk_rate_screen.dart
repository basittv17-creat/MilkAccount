import 'package:flutter/material.dart';
import '../data/milk_rate_repository.dart';

class MilkRateScreen extends StatefulWidget {
  const MilkRateScreen({super.key, required this.language});
  final String language;
  @override
  State<MilkRateScreen> createState() => _MilkRateScreenState();
}

class _MilkRateScreenState extends State<MilkRateScreen> {
  final _repo = MilkRateRepository();
  final _rate = TextEditingController();
  late Future<List<Map<String, Object?>>> _accounts;
  final Set<String> _selectedIds = {};
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _futureOnly = false;
  bool _saving = false;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) =>
      _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _rate.dispose(); super.dispose(); }
  void _load() => _accounts = _repo.activeAccounts();
  String _money(Object? paisa) => 'Rs. ${((((paisa as int?) ?? 0) / 100).toStringAsFixed(2))}';

  String _monthLabel() {
    const urMonths = ['جنوری','فروری','مارچ','اپریل','مئی','جون','جولائی','اگست','ستمبر','اکتوبر','نومبر','دسمبر'];
    const enMonths = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    const hiMonths = ['जनवरी','फ़रवरी','मार्च','अप्रैल','मई','जून','जुलाई','अगस्त','सितंबर','अक्टूबर','नवंबर','दिसंबर'];
    final names = _ur ? urMonths : widget.language == 'hi' ? hiMonths : enMonths;
    return '${names[_month.month - 1]} ${_month.year}';
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context, initialDate: _month,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      helpText: t('مہینہ منتخب کریں', 'Select month', 'महीना चुनें'),
    );
    if (picked != null && mounted) setState(() => _month = DateTime(picked.year, picked.month));
  }

  void _toggleAll(List<Map<String, Object?>> accounts, bool selected) {
    setState(() {
      if (selected) { _selectedIds.addAll(accounts.map((a) => a['id'] as String)); }
      else { _selectedIds.clear(); }
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_rate.text.trim());
    if (_selectedIds.isEmpty || amount == null || !amount.isFinite || amount < 0 || amount > 1000000) {
      _message(t('کھاتے منتخب کریں اور درست ریٹ درج کریں', 'Select accounts and enter a valid rate', 'खाते चुनें और सही रेट दर्ज करें'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ریٹ تبدیل کرنے کی تصدیق', 'Confirm milk rate change', 'दूध रेट बदलने की पुष्टि')),
        content: Text(_futureOnly
          ? t('نیا ریٹ منتخب کھاتوں کی آئندہ نئی انٹریوں پر لاگو ہوگا۔ پرانی انٹریاں تبدیل نہیں ہوں گی۔',
              'The new rate will apply to future entries for selected accounts. Existing entries will not change.',
              'नया रेट चुने गए खातों की आगे की एंट्री पर लागू होगा। पुरानी एंट्री नहीं बदलेगी।')
          : t('صرف ${_monthLabel()} کی منتخب کھاتوں والی موجودہ دودھ انٹریاں تبدیل ہوں گی۔ دوسرے مہینوں اور آئندہ ریٹ پر کوئی اثر نہیں ہوگا۔',
              'Only existing milk entries for selected accounts in ${_monthLabel()} will change. Other months and future account rates will remain untouched.',
              'केवल ${_monthLabel()} की चुने गए खातों वाली मौजूदा दूध एंट्री बदलेगी। दूसरे महीने और आगे का रेट नहीं बदलेगा।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('منسوخ', 'Cancel', 'रद्द करें'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('تبدیلی کریں', 'Apply change', 'बदलाव करें'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final paisa = (amount * 100).round();
      final changed = _futureOnly
        ? await _repo.updateFutureRate(accountIds: _selectedIds.toList(), ratePaisaPerKg: paisa)
        : await _repo.updateMonthEntries(accountIds: _selectedIds.toList(), month: _month, ratePaisaPerKg: paisa);
      if (!mounted) return;
      setState(() { _selectedIds.clear(); _rate.clear(); _load(); });
      _message(_futureOnly
        ? t('آئندہ انٹریوں کا ریٹ محفوظ ہوگیا۔', 'Future rate saved.', 'आगे की एंट्री का रेट सेव हो गया।')
        : t('منتخب مہینے کی $changed انٹریاں تبدیل ہوگئیں۔', '$changed entries in the selected month were updated.', 'चुने गए महीने की $changed एंट्री बदल गईं।'));
    } catch (error) {
      if (mounted) _message('${t('ریٹ محفوظ نہیں ہو سکا', 'Could not save rate', 'रेट सेव नहीं हो सका')}: $error');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(
        title: Text(t('دودھ کے ریٹ تبدیل کریں', 'Change milk rates', 'दूध के रेट बदलें')),
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) return Center(child: Text(t('پہلے نیا کھاتہ بنائیں', 'Create an account first', 'पहले खाता बनाएँ')));
          _selectedIds.removeWhere((id) => !accounts.any((a) => a['id'] == id));
          final allSelected = _selectedIds.length == accounts.length;
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE7F4FF), Colors.white]),
                  border: Border.all(color: const Color(0xFF91CFFF), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  t('اہم: مہینے کی تبدیلی صرف اسی مہینے کی محفوظ انٹریوں پر اثر کرے گی۔ دوسرے مہینوں کا حساب محفوظ رہے گا۔ آئندہ ریٹ الگ سے تبدیل کیا جا سکتا ہے۔',
                    'Important: A monthly change affects only saved entries in that month. Other months stay unchanged. Future rates can be changed separately.',
                    'ज़रूरी: महीने का बदलाव केवल उसी महीने की सेव एंट्री पर लागू होगा। दूसरे महीने सुरक्षित रहेंगे। आगे का रेट अलग बदला जा सकता है।'),
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              _sectionTitle(t('ریٹ تبدیل کرنے کا طریقہ', 'Choose what to change', 'क्या बदलना है चुनें')),
              RadioListTile<bool>(
                value: false, groupValue: _futureOnly,
                onChanged: _saving ? null : (v) => setState(() => _futureOnly = v!),
                title: Text(t('منتخب مہینے کا حساب تبدیل کریں', 'Change selected month entries', 'चुने महीने की एंट्री बदलें')),
                subtitle: Text(t('صرف اسی مہینے کی پرانی انٹریاں تبدیل ہوں گی', 'Only existing entries in that month are recalculated', 'केवल उसी महीने की पुरानी एंट्री बदलेगी')),
                activeColor: const Color(0xFF079B37), contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: true, groupValue: _futureOnly,
                onChanged: _saving ? null : (v) => setState(() => _futureOnly = v!),
                title: Text(t('آئندہ دودھ کا ریٹ تبدیل کریں', 'Change rate for future entries', 'आगे की एंट्री का रेट बदलें')),
                subtitle: Text(t('پہلے سے محفوظ انٹریاں تبدیل نہیں ہوں گی', 'Previously saved entries remain unchanged', 'पहले से सेव एंट्री नहीं बदलेगी')),
                activeColor: const Color(0xFF079B37), contentPadding: EdgeInsets.zero,
              ),
              if (!_futureOnly) ...[
                const SizedBox(height: 8),
                _sectionTitle(t('مہینہ منتخب کریں', 'Select month', 'महीना चुनें')),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickMonth,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_monthLabel(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.white),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _sectionTitle(t('کھاتے منتخب کریں', 'Select accounts', 'खाते चुनें'))),
                TextButton(
                  onPressed: _saving ? null : () => _toggleAll(accounts, !allSelected),
                  child: Text(allSelected ? t('سب ختم کریں', 'Clear all', 'सब हटाएँ') : t('سب منتخب کریں', 'Select all', 'सब चुनें')),
                ),
              ]),
              for (final account in accounts)
                Card(
                  color: _selectedIds.contains(account['id']) ? const Color(0xFFE3F8E9) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(color: _selectedIds.contains(account['id']) ? const Color(0xFF079B37) : const Color(0xFFD5E8F8)),
                  ),
                  child: CheckboxListTile(
                    value: _selectedIds.contains(account['id']),
                    onChanged: _saving ? null : (v) => setState(() {
                      final id = account['id'] as String;
                      if (v == true) { _selectedIds.add(id); } else { _selectedIds.remove(id); }
                    }),
                    activeColor: const Color(0xFF079B37),
                    secondary: CircleAvatar(
                      backgroundColor: const Color(0xFFDFF1FF),
                      child: Text(account['account_number'].toString(), style: const TextStyle(color: Color(0xFF0649AE), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(account['customer_name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(t('موجودہ آئندہ ریٹ: ', 'Current future rate: ', 'मौजूदा आगे का रेट: ') + _money(account['milk_rate_paisa'])),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ),
              const SizedBox(height: 12),
              _sectionTitle(t('نیا دودھ کا ریٹ فی کلو', 'New milk rate per kg', 'दूध का नया रेट प्रति किलो')),
              TextField(
                controller: _rate, enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: 'Rs. ', hintText: '250.00', filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle),
                  label: Text(_saving ? t('محفوظ ہو رہا ہے', 'Saving...', 'सेव हो रहा है') : t('منتخب ریٹ محفوظ کریں', 'Apply selected rate', 'चुना हुआ रेट लागू करें')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF079B37), foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0649AE))),
  );
}
