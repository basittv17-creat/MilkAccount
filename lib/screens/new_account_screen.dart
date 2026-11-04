import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../data/account_repository.dart';

class NewAccountScreen extends StatefulWidget {
  const NewAccountScreen({super.key, required this.language, this.account});
  final String language;
  final Map<String, Object?>? account;
  @override
  State<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends State<NewAccountScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _father = TextEditingController();
  final _code = TextEditingController(text: '+92');
  final _phone = TextEditingController();
  final _rate = TextEditingController();
  final _notes = TextEditingController();
  final _repo = AccountRepository();
  late Future<int> _nextAccountNumber;
  DateTime _start = DateTime.now();
  bool _fat = false, _saving = false;
  String _selectedFlag = '🇵🇰';
  bool get _ur => widget.language == 'ur';
  bool get _editing => widget.account != null;
  String t(String u, String e, String h) => _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() {
    super.initState();
    _nextAccountNumber = _repo.nextAccountNumber();
    final a = widget.account;
    if (a != null) {
      _name.text = a['customer_name']?.toString() ?? '';
      _father.text = a['father_name']?.toString() ?? '';
      _code.text = a['country_code']?.toString() ?? '+92';
      _phone.text = a['phone_number']?.toString() ?? '';
      _rate.text = ((a['milk_rate_paisa'] as int? ?? 0) / 100).toStringAsFixed(2);
      _notes.text = a['notes']?.toString() ?? '';
      _fat = (a['fat_enabled'] as int? ?? 0) == 1;
      _start = DateTime.tryParse(a['start_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    }
    final initialCountry = CountryService().findByPhoneCode(_code.text.replaceAll('+', ''));
    _selectedFlag = initialCountry?.flagEmoji ?? '🇵🇰';
  }

  @override
  void dispose() {
    _name.dispose(); _father.dispose(); _code.dispose(); _phone.dispose();
    _rate.dispose(); _notes.dispose(); super.dispose();
  }

  InputDecoration dec(String label) => InputDecoration(labelText: label, filled: true,
    fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  Widget _accountNumberCard() {
    final number = _editing
        ? Text(
            widget.account!['account_number'].toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          )
        : FutureBuilder<int>(
            future: _nextAccountNumber,
            builder: (context, snapshot) => Text(
              snapshot.hasData ? snapshot.data!.toString().padLeft(2, '0') : '—',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2C6),
        border: Border.all(color: const Color(0xFFE2B52D), width: 1.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t('کھاتہ نمبر', 'Account number', 'खाता नंबर'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 62),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2B52D)),
            ),
            child: Center(child: number),
          ),
        ],
      ),
    );
  }

  Widget field(TextEditingController c, String label, {bool required = false, bool numeric = false, int lines = 1}) =>
    TextFormField(controller: c, maxLines: lines,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: dec(label),
      validator: required ? (v) => v == null || v.trim().isEmpty ? t('یہ خانہ ضروری ہے','Required field','यह ज़रूरी है') : null : null);

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _start,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null && mounted) setState(() => _start = DateTime(d.year,d.month,d.day,_start.hour,_start.minute));
  }

  Future<void> pickTime() async {
    final v = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (v != null && mounted) setState(() => _start = DateTime(_start.year,_start.month,_start.day,v.hour,v.minute));
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['PK', 'SA', 'AE', 'GB', 'US', 'IN'],
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        flagSize: 26,
        textStyle: const TextStyle(fontSize: 16, color: Color(0xFF173D67)),
        bottomSheetHeight: 560,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        inputDecoration: InputDecoration(
          hintText: t('ملک یا کوڈ تلاش کریں', 'Search country or code', 'देश या कोड खोजें'),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF3F9FF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      onSelect: (country) {
        setState(() {
          _code.text = '+${country.phoneCode}';
          _selectedFlag = country.flagEmoji;
        });
      },
    );
  }

  Widget _countryCodeField() => InkWell(
    onTap: _pickCountry,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: dec(t('ملک کا کوڈ', 'Country code', 'देश कोड')),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(children: [
                Text(_selectedFlag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 5),
                Text(_code.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );

  Future<void> save() async {
    if (!_key.currentState!.validate()) return;
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || !rate.isFinite || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('ریٹ درست درج کریں','Enter a valid rate','सही रेट दर्ज करें'))));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await _repo.updateAccount(
          id: widget.account!['id'].toString(), customerName: _name.text,
          fatherName: _father.text, countryCode: _code.text, phoneNumber: _phone.text,
          startAt: _start, milkRatePaisa: (rate * 100).round(),
          fatEnabled: _fat, notes: _notes.text);
      } else {
        await _repo.createAccount(
          customerName: _name.text, fatherName: _father.text,
          countryCode: _code.text, phoneNumber: _phone.text, startAt: _start,
          milkRatePaisa: (rate * 100).round(), fatEnabled: _fat, notes: _notes.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
    SafeArea(top: false, child: child: Scaffold(
      backgroundColor: const Color(0xFFF3F9FF),
      appBar: AppBar(title: Text(_editing ? t('اکاؤنٹ میں ترمیم','Edit Account','खाता संपादित करें') : t('نیا کھاتہ','New Account','नया खाता')),
        backgroundColor: const Color(0xFF0649AE), foregroundColor: Colors.white),
      body: Form(key: _key, child: ListView(padding: const EdgeInsets.all(16), children: [
        _accountNumberCard(),
        field(_name,t('گاہک کا نام','Customer name','ग्राहक का नाम'),required:true), const SizedBox(height:12),
        field(_father,t('والد کا نام','Father name','पिता का नाम')), const SizedBox(height:12),
        Text(t('فون نمبر','Phone number','फ़ोन नंबर')),
        Row(children:[
          SizedBox(width:124,child:_countryCodeField()),
          const SizedBox(width:8),
          Expanded(child:TextFormField(controller:_phone,keyboardType:TextInputType.phone,decoration:dec(t('موبائل نمبر','Mobile number','मोबाइल नंबर')))),
        ]),
        const SizedBox(height:12), Text(t('شروع ہونے کی تاریخ اور وقت','Start date and time','शुरू होने की तारीख और समय')),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:pickDate,icon:const Icon(Icons.calendar_month),
            label:Text(_start.day.toString()+'/'+_start.month.toString()+'/'+_start.year.toString()))),
          const SizedBox(width:8),
          Expanded(child:OutlinedButton.icon(onPressed:pickTime,icon:const Icon(Icons.access_time),
            label:Text(TimeOfDay.fromDateTime(_start).format(context)))),
        ]),
        const SizedBox(height:12), field(_rate,t('دودھ کا ریٹ فی کلو (روپے)','Milk rate per kg (Rs.)','दूध का रेट प्रति किलो'),required:true,numeric:true),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:_fat,onChanged:(v)=>setState(()=>_fat=v),
          title:Text(t('FAT کی سہولت فعال کریں','Enable FAT','FAT चालू करें'))),
        field(_notes,t('اضافی نوٹس (اختیاری)','Additional notes','अतिरिक्त नोट्स'),lines:3),
        const SizedBox(height:20),
        SizedBox(height:52,child:FilledButton.icon(onPressed:_saving?null:save,icon:const Icon(Icons.save),
          label:Text(_saving?t('محفوظ ہو رہا ہے','Saving...','सेव हो रहा है') :
            _editing?t('تبدیلیاں محفوظ کریں','Save Changes','बदलाव सेव करें'):t('کھاتہ محفوظ کریں','Save Account','खाता सेव करें')),
          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF079B37),foregroundColor:Colors.white))),
      ])),
    )));
}
