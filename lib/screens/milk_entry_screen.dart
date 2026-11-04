import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/milk_entry_repository.dart';
import '../utils/phone_number.dart';

class MilkEntryScreen extends StatefulWidget {
  const MilkEntryScreen({super.key, required this.language, this.initialAccountId, this.initialDate});
  final String language;
  final String? initialAccountId;
  final DateTime? initialDate;
  @override
  State<MilkEntryScreen> createState() => _MilkEntryScreenState();
}

class _MilkEntryScreenState extends State<MilkEntryScreen> {
  final _repo = MilkEntryRepository();
  final _search = TextEditingController();
  final _quantity = TextEditingController();
  final _fat = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime _recordedAt = DateTime.now();
  List<Map<String, Object?>> _accounts = [];
  Map<String, Object?>? _selected;
  bool _loading = true;
  bool _saving = false;
  bool _sendSms = true;
  bool _sendWhatsApp = true;
  String? _successMessage;

  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) => _ur ? u : widget.language == 'hi' ? h : e;
  List<Map<String, Object?>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) =>
      (a['customer_name'] as String).toLowerCase().contains(q) ||
      '${a['account_number']}'.contains(q)).toList();
  }
  List<Map<String, Object?>> get _pending => _filtered.where((a) => a['has_entry'] != 1).toList();
  List<Map<String, Object?>> get _received => _filtered.where((a) => a['has_entry'] == 1).toList();

  bool _initialAccountApplied = false;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _date = DateTime(initialDate.year, initialDate.month, initialDate.day);
      _recordedAt = _date;
    }
    _loadAccounts();
    _search.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _search.dispose();
    _quantity.dispose();
    _fat.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.accountsForDate(_date);
      if (mounted) {
        setState(() { _accounts = rows; _loading = false; });
        if (!_initialAccountApplied && widget.initialAccountId != null) {
          _initialAccountApplied = true;
          Map<String, Object?>? initialAccount;
          for (final account in rows) {
            if (account['id'] == widget.initialAccountId) {
              initialAccount = account;
              break;
            }
          }
          if (initialAccount != null &&
              initialAccount['has_entry'] != 1) {
            _openAccount(initialAccount);
          } else if (initialAccount != null) {
            _message(t(
              'اس تاریخ کا دودھ پہلے درج ہے، دوسری تاریخ منتخب کریں',
              'Milk is already recorded for this date. Choose another date.',
              'इस तारीख का दूध पहले दर्ज है। दूसरी तारीख चुनें।',
            ));
          } else {
            _message(t(
              'منتخب کھاتہ اس تاریخ پر دستیاب نہیں',
              'The selected account is not available on this date',
              'चुना खाता इस तारीख पर उपलब्ध नहीं है',
            ));
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      rethrow;
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (value != null && mounted) {
      setState(() { _date = value; _recordedAt = DateTime(value.year, value.month, value.day, _recordedAt.hour, _recordedAt.minute); _selected = null; _successMessage = null; if (widget.initialAccountId != null) _initialAccountApplied = false; });
      await _loadAccounts();
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_recordedAt));
    if (value != null && mounted) {
      setState(() => _recordedAt = DateTime(_date.year, _date.month, _date.day, value.hour, value.minute));
    }
  }

  void _openAccount(Map<String, Object?> account) {
    final now = DateTime.now();
    setState(() {
      _selected = account;
      _successMessage = null;
      _quantity.clear();
      _fat.text = (account['fat_enabled'] as int? ?? 0) == 1 ? '4.5' : '';
      _note.clear();
      _recordedAt = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    });
  }

  Future<void> _save() async {
    final account = _selected;
    final kg = double.tryParse(_quantity.text.trim());
    if (account == null || kg == null || !kg.isFinite || kg <= 0 || kg > 1000) {
      _message(t('دودھ کی درست مقدار درج کریں', 'Enter a valid milk quantity', 'दूध की सही मात्रा दर्ज करें'));
      return;
    }
    final fatEnabled = (account['fat_enabled'] as int? ?? 0) == 1;
    final fat = fatEnabled && _fat.text.trim().isNotEmpty ? double.tryParse(_fat.text.trim()) : null;
    if (fatEnabled && _fat.text.trim().isNotEmpty && (fat == null || !fat.isFinite || fat < 0 || fat > 15)) {
      _message(t('FAT کی مقدار 0 سے 15 کے درمیان درج کریں', 'FAT must be between 0 and 15', 'FAT 0 से 15 के बीच दर्ज करें'));
      return;
    }
    setState(() => _saving = true);
    try {
      final quantityGrams = (kg * 1000).round();
      final ratePaisa = account['milk_rate_paisa'] as int? ?? 0;
      final totalPaisa = (quantityGrams * ratePaisa / 1000).round();
      final note = _note.text.trim();
      await _repo.createEntry(
        accountId: account['id'] as String,
        recordedAt: _recordedAt,
        quantityGrams: quantityGrams,
        fatValue: fat,
        ratePaisaPerKg: ratePaisa,
        note: note,
      );
      final message = _milkMessage(account: account, quantityGrams: quantityGrams,
        ratePaisa: ratePaisa, totalPaisa: totalPaisa, fat: fat, note: note);
      await _loadAccounts();
      if (mounted) {
        setState(() {
          _selected = null;
          _successMessage = t(
            'آج کا دودھ کامیابی سے درج ہو گیا ہے',
            'Today’s milk entry was saved successfully',
            'आज का दूध सफलतापूर्वक दर्ज हो गया है',
          );
        });
        if (_sendSms || _sendWhatsApp) await _showShareOptions(account, message);
      }
    } catch (error) {
      _message('${t('اندراج محفوظ نہیں ہو سکا', 'Could not save entry', 'एंट्री सेव नहीं हुई')}: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _milkMessage({
    required Map<String, Object?> account,
    required int quantityGrams,
    required int ratePaisa,
    required int totalPaisa,
    required double? fat,
    required String note,
  }) {
    final date = _dateLabel(_recordedAt);
    final time = TimeOfDay.fromDateTime(_recordedAt).format(context);
    final quantity = (quantityGrams / 1000).toStringAsFixed(3);
    final customerName = account['customer_name'] ?? '';
    final accountNumber = account['account_number'] ?? '';
    final lines = <String>[
      'Milk Account / ' + t('دودھ کا کھاتہ', 'Milk Account', 'दूध का खाता'),
      t('گاہک', 'Customer', 'ग्राहक') + ': $customerName',
      t('کھاتہ نمبر', 'Account No.', 'खाता नंबर') + ': $accountNumber',
      t('تاریخ', 'Date', 'तारीख') + ': $date',
      t('وقت', 'Time', 'समय') + ': $time',
      t('دودھ', 'Milk', 'दूध') + ': $quantity kg',
      if (fat != null) 'FAT: ' + fat.toStringAsFixed(1) + '%',
      t('ریٹ فی کلو', 'Rate per kg', 'प्रति किलो रेट') + ': Rs. ' + (ratePaisa / 100).toStringAsFixed(2),
      t('کل رقم', 'Total amount', 'कुल राशि') + ': Rs. ' + (totalPaisa / 100).toStringAsFixed(2),
      if (note.isNotEmpty) t('نوٹ', 'Note', 'नोट') + ': $note',
    ];
    return lines.join('\n');
  }

  String? _customerPhone(Map<String, Object?> account) {
    final phone = (account['phone_number'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    final country = (account['country_code'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return null;
    return phone.startsWith(country) ? phone : '$country$phone';
  }

  Future<void> _showShareOptions(Map<String, Object?> account, String message) async {
    final phone = _customerPhone(account);
    if (phone == null || phone.isEmpty) {
      _message(t('گاہک کا فون نمبر درج نہیں ہے', 'Customer phone number is missing', 'ग्राहक का फोन नंबर दर्ज नहीं है'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t('دودھ کی تفصیل بھیجیں', 'Send milk details', 'दूध की जानकारी भेजें'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (_sendWhatsApp)
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF159447)),
                title: const Text('WhatsApp'),
                subtitle: Text('+$phone'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final uri = Uri.parse('https://wa.me/$phone?text=' + Uri.encodeComponent(message));
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && mounted) _message(t('WhatsApp نہیں کھل سکا', 'Could not open WhatsApp', 'WhatsApp नहीं खुल सका'));
                },
              ),
            if (_sendSms)
              ListTile(
                leading: const Icon(Icons.sms, color: Color(0xFF0756C9)),
                title: const Text('SMS'),
                subtitle: Text('+$phone'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final uri = Uri(scheme: 'sms', path: '+$phone', queryParameters: {'body': message});
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && mounted) _message(t('SMS ایپ نہیں کھل سکی', 'Could not open SMS app', 'SMS ऐप नहीं खुल सकी'));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  String _dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
  String _money(Object? paisa) => ((paisa as int? ?? 0) / 100).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
          if (_selected != null) { setState(() => _selected = null); } else { Navigator.maybePop(context); }
        }),
        title: Text(_selected == null
          ? t('دودھ کا اندراج', 'Milk Entry', 'दूध की एंट्री')
          : t('آج کا دودھ درج کریں', 'Enter Today’s Milk', 'आज का दूध दर्ज करें')),
      ),
      body: SafeArea(
        top: false,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
            ? Center(child: Text(t('پہلے نیا کھاتہ بنائیں', 'Create an account first', 'पहले खाता बनाएँ')))
            : _selected == null ? _listView() : _entryView(_selected!),
      ),
    ),
  );

  Widget _listView() => ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 22), children: [
    if (_successMessage != null)
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F8E9),
          border: Border.all(color: const Color(0xFF64BC78), width: 1.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF079B37), size: 28),
          const SizedBox(width: 9),
          Expanded(child: Text(
            _successMessage!,
            style: const TextStyle(
              color: Color(0xFF075A24),
              fontWeight: FontWeight.w900,
            ),
          )),
        ]),
      ),
    _datePicker(),
    const SizedBox(height: 10),
    TextField(controller: _search, decoration: InputDecoration(
      hintText: t('نام یا کھاتہ نمبر تلاش کریں...', 'Search name or account number...', 'नाम या खाता नंबर खोजें...'),
      prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _countCard(t('دودھ وصول (اندراج)', 'Milk received', 'दूध प्राप्त'), _received.length, const Color(0xFF159447))),
      const SizedBox(width: 8),
      Expanded(child: _countCard(t('باقی کھاتے (دودھ نہیں آیا)', 'Pending (not entered)', 'बाकी खाते'), _pending.length, const Color(0xFF1453A5))),
    ]),
    const SizedBox(height: 12),
    if (_pending.isNotEmpty) ...[
      _sectionTitle(t('آج کا دودھ درج کریں', 'Enter today’s milk', 'आज का दूध दर्ज करें'), _pending.length, const Color(0xFFBFE0FF)),
      for (final account in _pending) _accountTile(account, received: false),
    ],
    if (_received.isNotEmpty) ...[
      const SizedBox(height: 8),
      _sectionTitle(t('آج کا دودھ وصول (اندراج ہو چکا)', 'Milk received (already entered)', 'दूध दर्ज हो चुका'), _received.length, const Color(0xFFCFF2D8)),
      for (final account in _received) _accountTile(account, received: true),
    ],
    if (_filtered.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(
      t('کوئی کھاتہ نہیں ملا', 'No matching account found', 'कोई खाता नहीं मिला'), textAlign: TextAlign.center)),
  ]);

  Widget _datePicker() => InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(14), child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF9BCDF3))),
    child: Row(children: [
      const Icon(Icons.calendar_month, color: Color(0xFF0649AE), size: 28),
      const SizedBox(width: 12),
      Expanded(child: Text('${t('آج کی تاریخ', 'Date', 'तारीख')}: ${_dateLabel(_date)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      const Icon(Icons.edit_calendar, color: Color(0xFF0649AE)),
    ]),
  ));

  Widget _countCard(String title, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w900))),
    ]),
  );

  Widget _sectionTitle(String title, int count, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF9DBFE0))),
    child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))), Text('$count', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
  );

  Widget _accountTile(Map<String, Object?> a, {required bool received}) {
    final color = received ? const Color(0xFFE0F7E7) : const Color(0xFFFFE6E8);
    return Card(
      elevation: 0, color: color, margin: const EdgeInsets.only(bottom: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: received ? const Color(0xFF9AD7AA) : const Color(0xFFE8B5BC))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12), onTap: received ? null : () => _openAccount(a),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11), child: Row(children: [
          const Icon(Icons.local_drink, color: Color(0xFF47616F), size: 30),
          const SizedBox(width: 10),
          SizedBox(width: 34, child: Text('${a['account_number']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['customer_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if ((a['father_name'] as String? ?? '').isNotEmpty)
              Text('${t('ولد:', 'S/O:', 'पुत्र:')} ${a['father_name']}', style: const TextStyle(fontSize: 11)),
          ])),
          Icon(received ? Icons.check_circle : Icons.check_box_outline_blank, color: received ? const Color(0xFF079B37) : const Color(0xFF54616B), size: 28),
        ])),
      ),
    );
  }

  Widget _entryView(Map<String, Object?> a) {
    final fatEnabled = (a['fat_enabled'] as int? ?? 0) == 1;
    final rate = _money(a['milk_rate_paisa']);
    return ListView(padding: const EdgeInsets.all(13), children: [
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFDDF5E5), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF80C995))),
        child: Row(children: [
          const Icon(Icons.local_drink, size: 48, color: Color(0xFF527181)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['customer_name']}  •  ${t('کھاتہ نمبر:', 'Account:', 'खाता नंबर:')} ${a['account_number']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if ((a['father_name'] as String? ?? '').isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  Text(t('ولد:', 'S/O:', 'पुत्र:')),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(a['father_name'] as String),
                    ),
                  ),
                ],
              ),
            if ((a['phone_number'] as String? ?? '').isNotEmpty)
              Builder(builder: (context) {
                final phone = normalizeInternationalPhone(
                  countryCode: a['country_code'] as String?,
                  phoneNumber: a['phone_number'] as String?,
                );
                final country = (a['country_code'] as String? ?? '+92')
                    .replaceAll(RegExp(r'\D'), '');
                final displayPhone = phone == null
                    ? (a['phone_number'] as String)
                    : phone.startsWith(country) && country.isNotEmpty
                        ? '+$country ${phone.substring(country.length)}'
                        : '+$phone';
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(displayPhone),
                );
              }),
          ])),
        ])),
      const SizedBox(height: 12),
      _input(_quantity, t('آج کا دودھ (کلو)', 'Today’s milk (kg)', 'आज का दूध (kg)'), Icons.local_drink, decimal: true),
      if (fatEnabled) ...[const SizedBox(height: 10), _input(_fat, 'FAT (%)', Icons.water_drop, decimal: true)],
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB7D5EF))),
        child: Row(children: [const Icon(Icons.price_change, color: Color(0xFF0649AE)), const SizedBox(width: 8), Expanded(child: Text(t('دودھ کا ریٹ فی کلو', 'Milk rate per kg', 'दूध का रेट प्रति किलो'))), Text('Rs. $rate', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))])),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_dateLabel(_date), maxLines: 1, softWrap: false),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.access_time), label: Text(TimeOfDay.fromDateTime(_recordedAt).format(context)))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: t('نوٹ / وجہ (اختیاری)', 'Note (optional)', 'नोट (वैकल्पिक)'), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 10),
      _toggleRow(t('SMS بھیجیں', 'Send SMS', 'SMS भेजें'), Icons.sms, _sendSms, (v) => setState(() => _sendSms = v)),
      _toggleRow(t('WhatsApp پر بھیجیں', 'Send on WhatsApp', 'WhatsApp पर भेजें'), Icons.chat, _sendWhatsApp, (v) => setState(() => _sendWhatsApp = v)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : () {
                setState(() {
                  _selected = null;
                  _quantity.clear();
                  _fat.clear();
                  _note.clear();
                });
              },
              icon: const Icon(Icons.close),
              label: Text(t('منسوخ', 'Cancel', 'रद्द करें')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_circle),
              label: Text(_saving
                  ? t('محفوظ ہو رہا ہے...', 'Saving...', 'सेव हो रहा है...')
                  : t('محفوظ کریں', 'Save Milk Entry', 'दूध सेव करें')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF079B37),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ]),

    ]);
  }

  Widget _input(TextEditingController controller, String label, IconData icon, {bool decimal = false}) => TextField(
    controller: controller, keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));

  Widget _toggleRow(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => Container(
    margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB7D5EF))),
    child: Row(children: [Icon(icon, color: const Color(0xFF0875B9)), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))), Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF079B37))]),
  );
}
