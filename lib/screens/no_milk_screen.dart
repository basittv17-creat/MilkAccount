import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony_sms/telephony_sms.dart';
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
  final Set<String> _selectedIds = {};
  DateTime _day = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _sendSms = false;
  bool _sendWhatsApp = false;
  final TelephonySMS _telephonySms = TelephonySMS();
  bool _saving = false;
  bool _showDetails = false;

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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  String _phone(Map<String, Object?> row) {
    final code = (row['country_code'] as String? ?? '+92').replaceAll(RegExp(r'[^0-9+]'), '');
    final number = (row['phone_number'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (number.isEmpty) return '';
    if (number.startsWith('0')) return '$code${number.substring(1)}';
    if (number.startsWith('92')) return '+$number';
    return '$code$number';
  }

  String get _recordedTime =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  String _nagaMessage(Map<String, Object?> row) => t(
    'محترم ${row['customer_name']}، ${_day.day}/${_day.month}/${_day.year} کو دودھ نہیں آیا، اس لیے آج ناگا درج کیا گیا۔',
    'Dear ${row['customer_name']}, no milk was received on ${_day.day}/${_day.month}/${_day.year}. A no-milk day has been recorded.',
    'प्रिय ${row['customer_name']}, ${_day.day}/${_day.month}/${_day.year} को दूध नहीं आया, इसलिए नागा दर्ज किया गया।',
  );

  Future<void> _sendNotifications(List<Map<String, Object?>> savedRows) async {
    if (!_sendSms && !_sendWhatsApp) return;
    final errors = <String>[];
    if (_sendSms && Platform.isAndroid) {
      try {
        final granted = await _telephonySms.requestPermission();
        if (!granted) {
          errors.add(t('SMS کی اجازت نہیں ملی', 'SMS permission was not granted', 'SMS अनुमति नहीं मिली'));
        } else {
          for (final row in savedRows) {
            final phone = _phone(row);
            if (phone.isEmpty) { errors.add('${row['customer_name']}: ${t('فون نمبر موجود نہیں', 'No phone number', 'फोन नंबर नहीं है')}'); continue; }
            try { await _telephonySms.sendSMS(phone: phone, message: _nagaMessage(row)); }
            catch (error) { errors.add('${row['customer_name']}: SMS $error'); }
          }
        }
      } catch (error) { errors.add('SMS: $error'); }
    } else if (_sendSms && !Platform.isAndroid) {
      errors.add(t('براہ راست SMS صرف Android پر دستیاب ہے', 'Direct SMS is available on Android only', 'सीधा SMS केवल Android पर उपलब्ध है'));
    }
    if (_sendWhatsApp) {
      for (final row in savedRows) {
        final phone = _phone(row).replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isEmpty) { errors.add('${row['customer_name']}: ${t('فون نمبر موجود نہیں', 'No phone number', 'फोन नंबर नहीं है')}'); continue; }
        final uri = Uri.https('wa.me', '/$phone', {'text': _nagaMessage(row)});
        try {
          final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!opened) errors.add('${row['customer_name']}: WhatsApp could not be opened');
          if (savedRows.length > 1) await Future<void>.delayed(const Duration(seconds: 2));
        } catch (error) { errors.add('${row['customer_name']}: WhatsApp $error'); }
      }
    }
    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors.take(3).join('\n')), duration: const Duration(seconds: 6)));
    }
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

  void _toggleAll(bool selected) {
    setState(() {
      if (selected) {
        _selectedIds
          ..clear()
          ..addAll(_rows.map((row) => row['id'] as String));
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    var saved = 0;
    final savedRows = <Map<String, Object?>>[];
    final failures = <String>[];
    for (final row in _rows) {
      final id = row['id'] as String;
      if (!_selectedIds.contains(id)) continue;
      final name = row['customer_name'] as String;
      try {
        await _repo.markNoMilk(
          accountId: id,
          day: _day,
          note: _note.text,
          recordedTime: _recordedTime,
        );
        saved++;
        savedRows.add(row);
      } catch (error) {
        failures.add('$name: ${error is StateError ? error.message : error}');
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved > 0) await _sendNotifications(savedRows);
    if (saved > 0 && failures.isEmpty) {
      _note.clear();
      setState(() {
        _showDetails = false;
        _selectedIds.clear();
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF08A832),
                size: 76,
              ),
              const SizedBox(height: 14),
              Text(
                t(
                  'ناگا کامیابی سے درج کر دیا گیا',
                  'No-milk day saved successfully',
                  'दूध न आने का दिन सफलतापूर्वक सेव हो गया',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.check),
              label: Text(t('ٹھیک ہے', 'OK', 'ठीक है')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF08A832),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final message = [
        if (saved > 0)
          t('$saved کھاتوں میں ناگا محفوظ ہوا',
              'Saved for $saved account(s)', '$saved खातों में सेव हुआ'),
        ...failures.take(2),
        if (failures.length > 2) '+ ${failures.length - 2} more',
      ].join('\n');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message.isEmpty
            ? t('ریکارڈ محفوظ نہیں ہو سکا', 'Could not save record',
                'रिकॉर्ड सेव नहीं हो सका')
            : message),
        duration: const Duration(seconds: 5),
      ));
      if (saved > 0) {
        setState(() {
          _selectedIds.removeWhere((id) =>
              !_rows.any((row) => row['id'] == id));
        });
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _header(String title, {VoidCallback? onBack}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0649AE), Color(0xFF0879D5)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            if (onBack != null) ...[
              InkWell(
                onTap: onBack,
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _accountRow(Map<String, Object?> row) {
    final id = row['id'] as String;
    final selected = _selectedIds.contains(id);
    final phone = _phone(row);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF8D9) : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFFE2B52D) : const Color(0xFFB8D8F2),
          width: 1.3,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: CheckboxListTile(
        value: selected,
        activeColor: const Color(0xFF08A832),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        onChanged: (value) => setState(() {
          if (value == true) {
            _selectedIds.add(id);
          } else {
            _selectedIds.remove(id);
          }
        }),
        secondary: const Icon(
          Icons.local_drink_rounded,
          color: Color(0xFF0756C9),
          size: 31,
        ),
        title: Text(
          '#${row['account_number']}  ${row['customer_name']}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          phone.isEmpty
              ? t('فون نمبر موجود نہیں', 'No phone number saved', 'फ़ोन नंबर सेव नहीं है')
              : phone,
          style: TextStyle(
            color: phone.isEmpty ? Colors.red.shade700 : Colors.blueGrey.shade700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _selectionView() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _header(t('ناگا درج کریں', 'Record No-Milk Day', 'नागा दर्ज करें')),
          const SizedBox(height: 14),
          TextField(
            decoration: _dec(t('نام یا کھاتہ نمبر تلاش کریں',
                'Search name or account number', 'नाम या खाता नंबर खोजें'))
                .copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (value) => setState(() {
              // Filtering is applied below without changing the stored selection.
              _search = value.trim().toLowerCase();
            }),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3FF),
              border: Border.all(color: const Color(0xFF8FC5F2)),
              borderRadius: BorderRadius.circular(13),
            ),
            child: CheckboxListTile(
              value: _rows.isNotEmpty && _selectedIds.length == _rows.length,
              activeColor: const Color(0xFF08A832),
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(
                t('تمام کھاتے منتخب کریں', 'Select all accounts',
                    'सभी खाते चुनें'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onChanged: (value) => _toggleAll(value == true),
            ),
          ),
          const SizedBox(height: 10),
          ..._rows.where((row) {
            final query = _search;
            final name = (row['customer_name'] as String).toLowerCase();
            final number = (row['account_number']?.toString() ?? '');
            return query.isEmpty || name.contains(query) || number.contains(query);
          }).map(_accountRow),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAE5FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB6A5E8)),
            ),
            child: Text(
              t('منتخب کھاتے: ${_selectedIds.length}',
                  'Selected accounts: ${_selectedIds.length}',
                  'चुने गए खाते: ${_selectedIds.length}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => setState(() => _showDetails = true),
              icon: const Icon(Icons.arrow_forward),
              label: Text(t('اگلا', 'Next', 'आगे')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF08A832),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      );

  String _search = '';

  Widget _detailsView() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _header(
            t('ناگا کی تفصیل', 'No-Milk Details', 'नागा का विवरण'),
            onBack: () => setState(() => _showDetails = false),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2C6),
              border: Border.all(color: const Color(0xFFE2A000)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              t('منتخب کھاتے: ${_selectedIds.length}',
                  'Selected accounts: ${_selectedIds.length}',
                  'चुने गए खाते: ${_selectedIds.length}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
          const SizedBox(height: 12),
          Text(t('تاریخ', 'Date', 'तारीख'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month, color: Color(0xFF0756C9)),
            label: Text('${_day.day} ${_day.month} ${_day.year}'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              foregroundColor: Colors.black87,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF9CC9ED)),
            ),
          ),
          const SizedBox(height: 14),
          Text(t('وقت', 'Time', 'समय'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time, color: Color(0xFF0756C9)),
            label: Text(_time.format(context)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), foregroundColor: Colors.black87, backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFF9CC9ED))),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: _dec(t('نوٹ / وجہ (اختیاری)', 'Note / reason (optional)',
                'नोट / कारण (वैकल्पिक)'))
                .copyWith(
              suffixIcon: const Icon(Icons.edit, color: Color(0xFF0756C9)),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _sendSms,
            onChanged: (value) => setState(() => _sendSms = value ?? false),
            activeColor: const Color(0xFF08A832),
            secondary: const Icon(Icons.sms, color: Color(0xFF0756C9)),
            title: Text(t('SMS بھیجیں', 'Send SMS', 'SMS भेजें')),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _sendWhatsApp,
            onChanged: (value) => setState(() => _sendWhatsApp = value ?? false),
            activeColor: const Color(0xFF08A832),
            secondary: const Icon(Icons.chat, color: Color(0xFF168B45)),
            title: Text(t('WhatsApp پر بھیجیں', 'Send on WhatsApp', 'WhatsApp पर भेजें')),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showDetails = false),
                  icon: const Icon(Icons.close),
                  label: Text(t('منسوخ', 'Cancel', 'रद्द करें')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_circle),
                  label: Text(_saving
                      ? t('محفوظ ہو رہا ہے', 'Saving...', 'सेव हो रहा है')
                      : t('محفوظ کریں', 'Save', 'सेव करें')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF08A832),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

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
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              _rows = snapshot.data ?? [];
              if (_rows.isEmpty) {
                return Center(
                  child: Text(t('پہلے نیا کھاتہ بنائیں', 'Create an account first',
                      'पहले खाता बनाएँ')),
                );
              }
              return _showDetails ? _detailsView() : _selectionView();
            },
          ),
        ),
      );
}
