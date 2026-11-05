import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final String language;
  final ValueChanged<String> onLanguageChanged;

  Map<String, String> get _labels {
    const values = {
      'ur': {
        'title': 'سیٹنگز',
        'preferences': 'ایپ کی ترجیحات',
        'language': 'ایپ کی زبان',
        'languageSub': 'اردو، English یا हिन्दी منتخب کریں',
        'data': 'ڈیٹا اور بیک اپ',
        'backup': 'بیک اپ اور ڈیٹا بحال کریں',
        'backupSub': 'اپنے کھاتوں اور اندراجات کی کاپی محفوظ کریں',
        'about': 'ایپ کے بارے میں',
        'aboutSub': 'Milk Account کی معلومات',
        'version': 'ورژن',
        'appName': 'دودھ کا کھاتہ',
        'aboutBody': 'Milk Account دودھ کے روزانہ اندراج، گاہکوں کے کھاتوں، ایڈوانس اور ماہانہ رپورٹس کے لیے آف لائن فرسٹ ایپ ہے۔',
        'selectLanguage': 'زبان منتخب کریں',
        'urdu': 'اردو (پاکستان)',
        'english': 'English',
        'hindi': 'हिन्दी (Hindi)',
        'current': 'موجودہ زبان',
        'privacy': 'رازداری کی پالیسی',
        'privacySub': 'ایپ آپ کے ڈیٹا کو کیسے سنبھالتی ہے',
        'privacyError': 'رازداری کی پالیسی نہیں کھل سکی',
      },
      'en': {
        'title': 'Settings',
        'preferences': 'App Preferences',
        'language': 'App Language',
        'languageSub': 'Choose Urdu, English or Hindi',
        'data': 'Data & Backup',
        'backup': 'Backup & Restore',
        'backupSub': 'Save a copy of your accounts and records',
        'about': 'About the App',
        'aboutSub': 'Information about Milk Account',
        'version': 'Version',
        'appName': 'Milk Account',
        'aboutBody': 'Milk Account is an offline-first app for daily milk entries, customer accounts, advances and monthly reports.',
        'selectLanguage': 'Select Language',
        'urdu': 'Urdu (Pakistan)',
        'english': 'English',
        'hindi': 'Hindi',
        'current': 'Current language',
        'privacy': 'Privacy Policy',
        'privacySub': 'How the app handles your data',
        'privacyError': 'Could not open the Privacy Policy',
      },
      'hi': {
        'title': 'सेटिंग्स',
        'preferences': 'ऐप की प्राथमिकताएँ',
        'language': 'ऐप की भाषा',
        'languageSub': 'उर्दू, English या हिन्दी चुनें',
        'data': 'डेटा और बैकअप',
        'backup': 'बैकअप और डेटा वापस लाएँ',
        'backupSub': 'अपने खातों और रिकॉर्ड की कॉपी सुरक्षित करें',
        'about': 'ऐप के बारे में',
        'aboutSub': 'Milk Account की जानकारी',
        'version': 'वर्ज़न',
        'appName': 'दूध का खाता',
        'aboutBody': 'Milk Account दूध की रोज़ाना एंट्री, ग्राहक खातों, एडवांस और मासिक रिपोर्ट के लिए ऑफलाइन-फर्स्ट ऐप है।',
        'selectLanguage': 'भाषा चुनें',
        'urdu': 'उर्दू (पाकिस्तान)',
        'english': 'English',
        'hindi': 'हिन्दी',
        'current': 'मौजूदा भाषा',
        'privacy': 'गोपनीयता नीति',
        'privacySub': 'ऐप आपके डेटा को कैसे संभालता है',
        'privacyError': 'गोपनीयता नीति नहीं खुल सकी',
      },
    };
    return values[language] ?? values['en']!;
  }

  String _text(String key) => _labels[key] ?? key;

  String _languageName(String code) {
    switch (code) {
      case 'ur':
        return _text('urdu');
      case 'hi':
        return _text('hindi');
      default:
        return _text('english');
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse('https://basittv17-creat.github.io/MilkAccount/');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text('privacyError'))),
      );
    }
  }

  void _chooseLanguage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _text('selectLanguage'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _languageTile(sheetContext, 'ur', '🇵🇰', _text('urdu')),
            _languageTile(sheetContext, 'en', '🇺🇸', _text('english')),
            _languageTile(sheetContext, 'hi', '🇮🇳', _text('hindi')),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(BuildContext context, String code, String flag, String name) =>
      ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 26)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: language == code
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF079B37))
            : const Icon(Icons.radio_button_unchecked_rounded, color: Colors.blueGrey),
        onTap: () {
          Navigator.pop(context);
          if (language != code) onLanguageChanged(code);
        },
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0649AE),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _settingsCard({required List<Widget> children}) => Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xFFD8E8F7)),
        ),
        child: Column(children: children),
      );

  @override
  Widget build(BuildContext context) {
    final rtl = language == 'ur';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(top: false, child: Scaffold(
        backgroundColor: const Color(0xFFF3F9FF),
        appBar: AppBar(
          title: Text(_text('title')),
          backgroundColor: const Color(0xFF0649AE),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF003B91), Color(0xFF0879D5)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Milk Account',
                          style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _text('appName'),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_text('version')}: 0.3.0',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _sectionTitle(_text('preferences')),
            _settingsCard(children: [
              ListTile(
                leading: const Icon(Icons.language_rounded, color: Color(0xFF0756C9)),
                title: Text(_text('language'), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_text('current')}: ${_languageName(language)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseLanguage(context),
              ),
            ]),
            _sectionTitle(_text('data')),
            _settingsCard(children: [
              ListTile(
                leading: const Icon(Icons.backup_rounded, color: Color(0xFF079B37)),
                title: Text(_text('backup'), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_text('backupSub')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => BackupScreen(language: language)),
                ),
              ),
            ]),
            _sectionTitle(_text('about')),
            _settingsCard(children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF0756C9)),
                title: Text(_text('appName'), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_text('aboutSub')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Milk Account',
                  applicationVersion: '0.3.0',
                  applicationIcon: const Icon(Icons.local_drink_rounded, size: 42, color: Color(0xFF0756C9)),
                  applicationLegalese: '${_text('aboutBody')}\nPackage ID: com.awasigogera.milkaccount',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF0756C9)),
                title: Text(_text('privacy'), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_text('privacySub')),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _openPrivacyPolicy(context),
              ),
            ]),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'Milk Account • 0.3.0',
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
