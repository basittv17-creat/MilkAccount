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
  late Future<List<Map<String, Object?>>> _accounts;
  bool get _ur => widget.language == 'ur';
  String t(String u, String e, String h) =>
      _ur ? u : widget.language == 'hi' ? h : e;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _accounts = _repo.activeAccounts();

  String _money(Object? paisa) =>
      'Rs. ' + ((((paisa as int?) ?? 0) / 100).toStringAsFixed(2));

  Future<void> _editRate(Map<String, Object?> account) async {
    final current = account['milk_rate_paisa'] as int? ?? 0;
    final controller =
        TextEditingController(text: (current / 100).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('دودھ کا نیا ریٹ', 'Update milk rate', 'दूध का नया रेट')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t('فی کلو ریٹ (روپے)', 'Rate per kg (rupees)',
                  'प्रति किलो रेट (रुपये)'),
              prefixText: 'Rs. ',
            ),
            validator: (text) {
              final rate = double.tryParse((text ?? '').trim());
              if (rate == null ||
                  !rate.isFinite ||
                  rate < 0 ||
                  rate > 1000000) {
                return t('درست ریٹ درج کریں', 'Enter a valid rate',
                    'सही रेट दर्ज करें');
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('منسوخ', 'Cancel', 'रद्द करें')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                    dialogContext, double.parse(controller.text.trim()));
              }
            },
            child: Text(t('محفوظ کریں', 'Save', 'सेव करें')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await _repo.updateRate(
        accountId: account['id'] as String,
        ratePaisaPerKg: (value * 100).round(),
      );
      if (!mounted) return;
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('دودھ کا ریٹ محفوظ ہو گیا', 'Milk rate saved',
            'दूध का रेट सेव हो गया')),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rate: ' + error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _ur ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F9FF),
          appBar: AppBar(
            title: Text(t('دودھ کے ریٹ', 'Milk Rate Management',
                'दूध रेट मैनेजमेंट')),
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
              final accounts = snapshot.data ?? [];
              if (accounts.isEmpty) {
                return Center(child: Text(t('پہلے نیا کھاتہ بنائیں',
                    'Create an account first', 'पहले खाता बनाएँ')));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4FF),
                      border: Border.all(color: const Color(0xFF91CFFF)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      t(
                        'ہر گاہک کا دودھ کا ریٹ یہاں الگ تبدیل کیا جا سکتا ہے۔ '
                        'نیا ریٹ صرف آئندہ دودھ کے اندراجات پر لاگو ہوگا؛ '
                        'پرانے اندراجات کا حساب محفوظ رہے گا۔',
                        'Set a separate milk rate for each customer. New rates '
                        'apply only to future entries; previous entries keep '
                        'their original calculated amounts.',
                        'हर ग्राहक का दूध रेट अलग बदला जा सकता है। नया रेट '
                        'आगे की एंट्री पर लागू होगा; पुरानी एंट्री का हिसाब '
                        'वैसा ही रहेगा।',
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final account in accounts)
                    Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(color: Color(0xFFD5E8F8)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFDFF1FF),
                          child: Text(account['account_number'].toString(),
                              style: const TextStyle(
                                  color: Color(0xFF0649AE),
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(account['customer_name'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          t('موجودہ ریٹ', 'Current rate', 'मौजूदा रेट') +
                              ': ' +
                              _money(account['milk_rate_paisa']) +
                              ' / kg',
                        ),
                        trailing: IconButton(
                          tooltip: t(
                              'ریٹ تبدیل کریں', 'Change rate', 'रेट बदलें'),
                          onPressed: () => _editRate(account),
                          icon: const Icon(Icons.edit,
                              color: Color(0xFF0756C9)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
}
