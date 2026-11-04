import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/milk_rate_repository.dart';
import '../utils/phone_number.dart';

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
  int _mode = 0; // 0: selected month, 1: from month onward, 2: one account.
  bool _singleAccountFutureOnly = false;
  bool _sendSms = false;
  bool _sendWhatsApp = false;
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


  void _changeMode(int mode) {
    setState(() {
      _mode = mode;
      _selectedIds.clear();
      if (mode != 2) _singleAccountFutureOnly = false;
    });
  }

  void _selectAccount(String id, bool selected) {
    setState(() {
      if (_mode == 2) {
        _selectedIds..clear()..add(id);
      } else if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _adjustRate(double step) {
    final current = double.tryParse(_rate.text.trim()) ?? 0;
    final next = (current + step).clamp(0, 1000000).toDouble();
    _rate.text = next.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _save(List<Map<String, Object?>> accounts) async {
    final amount = double.tryParse(_rate.text.trim());
    final validSelection = _mode == 2
        ? _selectedIds.length == 1
        : _selectedIds.isNotEmpty;
    if (!validSelection || amount == null || !amount.isFinite ||
        amount < 0 || amount > 1000000) {
      _message(t('کھاتہ منتخب کریں اور درست ریٹ درج کریں',
          'Select the required account(s) and enter a valid rate',
          'खाते चुनें और सही रेट दर्ज करें'));
      return;
    }

    final selectedAccounts = accounts
        .where((account) => _selectedIds.contains(account['id']))
        .toList();
    if (selectedAccounts.length != _selectedIds.length) {
      _message(t('منتخب کھاتے نہیں ملے', 'Selected accounts could not be found',
          'चुने खाते नहीं मिले'));
      return;
    }

    final singleFuture = _mode == 2 && _singleAccountFutureOnly;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('ریٹ تبدیل کرنے کی تصدیق',
            'Confirm milk rate change', 'दूध रेट बदलने की पुष्टि')),
        content: Text(_mode == 1
            ? t(
                '${_monthLabel()} سے منتخب کھاتوں کی محفوظ اور آئندہ انٹریوں پر نیا ریٹ لگے گا۔',
                'The new rate will apply to saved entries from ${_monthLabel()} onward and to future entries for selected accounts.',
                '${_monthLabel()} से चुने खातों की सेव और आगे की एंट्री पर नया रेट लगेगा।')
            : singleFuture
                ? t(
                    'صرف منتخب کھاتے کی آئندہ انٹریوں کا ریٹ تبدیل ہوگا۔ محفوظ پرانی انٹریاں نہیں بدلیں گی۔',
                    'Only future entries for the selected account will use this rate. Saved entries will not change.',
                    'केवल चुने खाते की आगे की एंट्री का रेट बदलेगा। पुरानी सेव एंट्री नहीं बदलेगी।')
                : t(
                    'صرف ${_monthLabel()} کی منتخب کھاتوں والی محفوظ انٹریاں تبدیل ہوں گی۔',
                    'Only saved entries in ${_monthLabel()} for the selected account(s) will change.',
                    'केवल ${_monthLabel()} की चुने खातों वाली सेव एंट्री बदलेगी।')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('منسوخ', 'Cancel', 'रद्द करें'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('تبدیلی کریں', 'Apply change', 'बदलाव करें'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final paisa = (amount * 100).round();
      final int changed;
      if (_mode == 1) {
        changed = await _repo.updateFromMonth(
          accountIds: _selectedIds.toList(),
          month: _month,
          ratePaisaPerKg: paisa,
        );
      } else if (singleFuture) {
        changed = await _repo.updateFutureRate(
          accountIds: _selectedIds.toList(),
          ratePaisaPerKg: paisa,
        );
      } else {
        changed = await _repo.updateMonthEntries(
          accountIds: _selectedIds.toList(),
          month: _month,
          ratePaisaPerKg: paisa,
        );
      }

      if (!mounted) return;
      await _showSuccess(
        accounts: selectedAccounts,
        rate: _money(paisa),
        changedEntries: changed,
      );
      if (mounted && (_sendSms || _sendWhatsApp)) {
        await _sendNotifications(selectedAccounts, _money(paisa));
      }
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _rate.clear();
          _sendSms = false;
          _sendWhatsApp = false;
          _load();
        });
      }
    } catch (error) {
      if (mounted) {
        _message('${t('ریٹ محفوظ نہیں ہو سکا', 'Could not save rate',
            'रेट सेव नहीं हो सका')}: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSuccess({
    required List<Map<String, Object?>> accounts,
    required String rate,
    required int changedEntries,
  }) async {
    final period = _mode == 1
        ? t('منتخب مہینے سے آئندہ', 'From selected month onward',
            'चुने महीने से आगे')
        : _mode == 2 && _singleAccountFutureOnly
            ? t('آئندہ انٹریاں', 'Future entries', 'आगे की एंट्री')
            : _monthLabel();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF08A832), size: 76),
            const SizedBox(height: 12),
            Text(
              t('دودھ کی قیمت کامیابی سے تبدیل کر دی گئی!',
                  'Milk rate changed successfully!',
                  'दूध का रेट सफलतापूर्वक बदल गया!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _successLine(t('مہینہ / مدت', 'Month / period', 'महीना / अवधि'), period),
            _successLine(t('تبدیل شدہ کھاتے', 'Accounts changed', 'बदले खाते'),
                '${accounts.length}'),
            _successLine(t('نیا ریٹ فی کلو', 'New rate per kg', 'नया रेट प्रति किलो'),
                rate),
            if (_mode != 2 || !_singleAccountFutureOnly)
              _successLine(t('تبدیل شدہ انٹریاں', 'Entries updated', 'बदली एंट्री'),
                  '$changedEntries'),
            if (accounts.length == 1)
              _successLine(t('کھاتہ', 'Account', 'खाता'),
                  '#${accounts.first['account_number']} — ${accounts.first['customer_name']}'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.check),
            label: Text(t('ٹھیک ہے', 'OK', 'ठीक है')),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF08A832),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _successLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(color: Colors.blueGrey))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );

  Future<void> _sendNotifications(
    List<Map<String, Object?>> accounts,
    String rate,
  ) async {
    final errors = <String>[];
    for (final account in accounts) {
      final phone = normalizeInternationalPhone(
        countryCode: account['country_code']?.toString(),
        phoneNumber: account['phone_number']?.toString(),
      );
      final name = account['customer_name']?.toString() ?? '';
      if (phone == null) {
        errors.add('$name: ${t('درست فون نمبر موجود نہیں',
            'No valid phone number', 'सही फोन नंबर नहीं है')}');
        continue;
      }
      final period = _mode == 2 && _singleAccountFutureOnly
          ? t('آئندہ انٹریاں', 'future entries', 'आगे की एंट्री')
          : _monthLabel();
      final message = t(
        'محترم $name، دودھ کا نیا ریٹ $rate فی کلو ہے۔ مؤثر مدت: $period۔',
        'Dear $name, the new milk rate is $rate per kg. Effective period: $period.',
        'प्रिय $name, दूध का नया रेट $rate प्रति किलो है। प्रभावी अवधि: $period।',
      );
      if (_sendSms) {
        try {
          final uri = Uri(
            scheme: 'sms',
            path: '+$phone',
            queryParameters: {'body': message},
          );
          if (!await launchUrl(uri)) {
            errors.add('$name: SMS ${t('نہیں کھل سکا', 'could not open', 'नहीं खुला')}');
          }
        } catch (error) {
          errors.add('$name: SMS $error');
        }
      }
      if (_sendWhatsApp) {
        try {
          final uri = Uri.https('wa.me', '/$phone', {'text': message});
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            errors.add('$name: WhatsApp ${t('نہیں کھل سکا', 'could not open', 'नहीं खुला')}');
          }
        } catch (error) {
          errors.add('$name: WhatsApp $error');
        }
        if (accounts.length > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
      }
    }
    if (errors.isNotEmpty && mounted) {
      _message(errors.take(3).join('\n'));
    }
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

              _sectionTitle(t('ریٹ تبدیل کرنے کا طریقہ منتخب کریں',
                  'Choose rate change method', 'रेट बदलने का तरीका चुनें')),
              RadioListTile<int>(
                value: 0, groupValue: _mode,
                onChanged: _saving ? null : (value) => _changeMode(value!),
                title: Text(t('منتخب مہینے کا ریٹ تبدیل کریں',
                    'Change rate for a selected month', 'चुने महीने का रेट बदलें')),
                subtitle: Text(t('صرف منتخب مہینے کی محفوظ انٹریاں',
                    'Only saved entries in that month', 'केवल उस महीने की सेव एंट्री')),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<int>(
                value: 1, groupValue: _mode,
                onChanged: _saving ? null : (value) => _changeMode(value!),
                title: Text(t('منتخب مہینے سے آئندہ ریٹ تبدیل کریں',
                    'Change rate from a selected month onward',
                    'चुने महीने से आगे का रेट बदलें')),
                subtitle: Text(t('منتخب مہینے سے تمام اگلے مہینوں اور نئی انٹریوں تک',
                    'Saved entries from that month onward and future entries',
                    'उस महीने से आगे की सेव और नई एंट्री')),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<int>(
                value: 2, groupValue: _mode,
                onChanged: _saving ? null : (value) => _changeMode(value!),
                title: Text(t('کسی خاص کھاتے کا ریٹ تبدیل کریں',
                    'Change one specific account rate', 'किसी खास खाते का रेट बदलें')),
                subtitle: Text(t('صرف ایک کھاتہ منتخب کریں',
                    'Select one account only', 'केवल एक खाता चुनें')),
                contentPadding: EdgeInsets.zero,
              ),
              if (_mode == 2) ...[
                const Divider(height: 18),
                _sectionTitle(t('اس کھاتے کے ریٹ کا اطلاق',
                    'Apply this account rate to', 'इस खाते का रेट लागू करें')),
                RadioListTile<bool>(
                  value: false, groupValue: _singleAccountFutureOnly,
                  onChanged: _saving ? null : (value) =>
                      setState(() => _singleAccountFutureOnly = value!),
                  title: Text(t('منتخب مہینے کی انٹریاں',
                      'Selected month entries', 'चुने महीने की एंट्री')),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  value: true, groupValue: _singleAccountFutureOnly,
                  onChanged: _saving ? null : (value) =>
                      setState(() => _singleAccountFutureOnly = value!),
                  title: Text(t('آئندہ انٹریاں',
                      'Future entries', 'आगे की एंट्री')),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (_mode != 2 || !_singleAccountFutureOnly) ...[
                const SizedBox(height: 8),
                _sectionTitle(t('مہینہ منتخب کریں', 'Select month', 'महीना चुनें')),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickMonth,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_monthLabel(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
              Row(children: [
                Expanded(child: _sectionTitle(t('کھاتے منتخب کریں', 'Select accounts', 'खाते चुनें'))),
                if (_mode != 2)
                  TextButton(
                    onPressed: _saving ? null : () => _toggleAll(accounts, !allSelected),
                    child: Text(allSelected ? t('سب ختم کریں', 'Clear all', 'सब हटाएँ') : t('تمام کھاتے منتخب کریں', 'Select all', 'सभी खाते चुनें')),
                  ),
              ]),

              for (final account in accounts)
                Card(
                  color: _selectedIds.contains(account['id'])
                      ? const Color(0xFFE3F8E9)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(
                      color: _selectedIds.contains(account['id'])
                          ? const Color(0xFF079B37)
                          : const Color(0xFFD5E8F8),
                    ),
                  ),
                  child: _mode == 2
                      ? RadioListTile<String>(
                          value: account['id'] as String,
                          groupValue: _selectedIds.isEmpty
                              ? null
                              : _selectedIds.first,
                          onChanged: _saving
                              ? null
                              : (value) => _selectAccount(value!, true),
                          activeColor: const Color(0xFF079B37),
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xFFDFF1FF),
                            child: Text(account['account_number'].toString(),
                                style: const TextStyle(
                                    color: Color(0xFF0649AE),
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(account['customer_name'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(t('موجودہ ریٹ: ', 'Current rate: ',
                                  'मौजूदा रेट: ') +
                              _money(account['milk_rate_paisa'])),
                        )
                      : CheckboxListTile(
                          value: _selectedIds.contains(account['id']),
                          onChanged: _saving
                              ? null
                              : (value) => _selectAccount(
                                  account['id'] as String, value == true),
                          activeColor: const Color(0xFF079B37),
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xFFDFF1FF),
                            child: Text(account['account_number'].toString(),
                                style: const TextStyle(
                                    color: Color(0xFF0649AE),
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(account['customer_name'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(t('موجودہ ریٹ: ', 'Current rate: ',
                                  'मौजूदा रेट: ') +
                              _money(account['milk_rate_paisa'])),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                ),
              const SizedBox(height: 12),
              _sectionTitle(t('نیا دودھ کا ریٹ فی کلو', 'New milk rate per kg', 'दूध का नया रेट प्रति किलो')),
              Row(children: [
                IconButton.filledTonal(
                  onPressed: _saving ? null : () => _adjustRate(-1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: TextField(
                    controller: _rate, enabled: !_saving,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixText: 'Rs. ', hintText: '270.00',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : () => _adjustRate(1),
                  icon: const Icon(Icons.add),
                ),
              ]),

              CheckboxListTile(
                value: _sendSms,
                onChanged: _saving ? null : (value) =>
                    setState(() => _sendSms = value ?? false),
                activeColor: const Color(0xFF079B37),
                secondary: const Icon(Icons.sms, color: Color(0xFF0756C9)),
                title: Text(t('SMS بھیجیں', 'Send SMS', 'SMS भेजें')),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _sendWhatsApp,
                onChanged: _saving ? null : (value) =>
                    setState(() => _sendWhatsApp = value ?? false),
                activeColor: const Color(0xFF079B37),
                secondary: const Icon(Icons.chat, color: Color(0xFF168B45)),
                title: const Text('WhatsApp'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(accounts),
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
