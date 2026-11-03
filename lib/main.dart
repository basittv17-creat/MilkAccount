import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(MilkAccountApp(preferences: preferences));
}

class MilkAccountApp extends StatefulWidget {
  const MilkAccountApp({super.key, required this.preferences});
  final SharedPreferences preferences;

  @override
  State<MilkAccountApp> createState() => _MilkAccountAppState();
}

class _MilkAccountAppState extends State<MilkAccountApp> {
  late Locale _locale;
  late bool _languageChosen;

  @override
  void initState() {
    super.initState();
    final saved = widget.preferences.getString('app_language');
    _languageChosen = saved != null;
    _locale = Locale(saved ?? 'ur');
  }

  Future<void> _selectLanguage(String language) async {
    await widget.preferences.setString('app_language', language);
    if (!mounted) return;
    setState(() {
      _locale = Locale(language);
      _languageChosen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milk Account',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ur'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0756C9),
          primary: const Color(0xFF0756C9),
          secondary: const Color(0xFF08A832),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F7FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0756C9),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: _languageChosen
          ? DashboardScreen(locale: _locale, onLanguageChanged: _selectLanguage)
          : LanguageSelectionScreen(onSelected: _selectLanguage),
    );
  }
}

class Copy {
  static const Map<String, Map<String, String>> values = {
    'ur': {
      'choose': 'زبان منتخب کریں',
      'next': 'آگے بڑھیں',
      'brand': 'دودھ کا کھاتہ',
      'milk': 'دودھ کا اندراج',
      'milkSub': 'روزانہ کا دودھ درج کریں',
      'advance': 'ایڈوانس',
      'advanceSub': 'پیسے کی وصولی کی تفصیل',
      'accounts': 'کھاتے',
      'accountsSub': 'مکمل تفصیل والے کھاتے',
      'home': 'ہوم',
      'reports': 'رپورٹس',
      'settings': 'سیٹنگز',
      'welcome': 'آسان، تیز اور محفوظ حساب',
      'coming': 'یہ حصہ اگلے مرحلے میں تیار ہوگا',
      'urdu': 'اردو (پاکستان)',
      'english': 'English',
    },
    'en': {
      'choose': 'Select Language',
      'next': 'Continue',
      'brand': 'Milk Account',
      'milk': 'Milk Entry',
      'milkSub': 'Record daily milk',
      'advance': 'Advance',
      'advanceSub': 'Advance payment details',
      'accounts': 'Accounts',
      'accountsSub': 'Complete customer ledgers',
      'home': 'Home',
      'reports': 'Reports',
      'settings': 'Settings',
      'welcome': 'Simple, fast and secure accounting',
      'coming': 'This section will be built in a later phase',
      'urdu': 'Urdu (Pakistan)',
      'english': 'English',
    },
  };

  static String get(String language, String key) =>
      values[language]?[key] ?? values['en']![key]!;
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String selected = 'ur';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF003C9C), Color(0xFF16A9EF), Colors.white],
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Icon(Icons.local_drink, size: 76, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text('Milk Account',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Text('دودھ کا کھاتہ',
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 38),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF9EDCFF), width: 3),
                      ),
                      child: Column(
                        children: [
                          Text(Copy.get(selected, 'choose'),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF062D70))),
                          const SizedBox(height: 16),
                          _languageTile('ur', '🇵🇰', Copy.get(selected, 'urdu')),
                          _languageTile('en', '🇺🇸', Copy.get(selected, 'english')),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => widget.onSelected(selected),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(Copy.get(selected, 'next')),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF08A832),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageTile(String code, String flag, String title) {
    final active = selected == code;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => setState(() => selected = code),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? const Color(0xFF08A832) : const Color(0xFF9AB8D5), width: active ? 2 : 1),
            color: active ? const Color(0xFFE8F8EC) : Colors.white,
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: active ? const Color(0xFF08A832) : Colors.blueGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.locale, required this.onLanguageChanged});
  final Locale locale;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final language = widget.locale.languageCode;
    final rtl = language == 'ur';
    final titles = [Copy.get(language, 'home'), Copy.get(language, 'accounts'), Copy.get(language, 'reports'), Copy.get(language, 'settings')];
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _openMenu(context, language)),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_drink, size: 27),
              const SizedBox(width: 7),
              Flexible(child: Text(Copy.get(language, 'brand'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))],
        ),
        body: _tab == 0
            ? _home(language)
            : _tab == 1
                ? _placeholder(language, Copy.get(language, 'accounts'))
                : _tab == 2
                    ? _placeholder(language, Copy.get(language, 'reports'))
                    : _placeholder(language, Copy.get(language, 'settings')),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: titles[0]),
            NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: titles[1]),
            NavigationDestination(icon: const Icon(Icons.bar_chart), label: titles[2]),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: titles[3]),
          ],
        ),
      ),
    );
  }

  Widget _home(String language) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE2F8FF), Colors.white]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9EDCFF)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign, color: Color(0xFF0756C9)),
              SizedBox(width: 8),
              Text('Ad space', style: TextStyle(color: Color(0xFF0756C9), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(Copy.get(language, 'welcome'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF082F72))),
        ),
        const SizedBox(height: 18),
        _actionCard(language, 'milk', 'milkSub', Icons.local_drink, const Color(0xFF0875E1), const Color(0xFFDFF1FF)),
        _actionCard(language, 'advance', 'advanceSub', Icons.monetization_on, const Color(0xFFE9A400), const Color(0xFFFFF4C9)),
        _actionCard(language, 'accounts', 'accountsSub', Icons.receipt_long, const Color(0xFF079B37), const Color(0xFFE3F9E8)),
      ],
    );
  }

  Widget _actionCard(String language, String title, String subtitle, IconData icon, Color color, Color tint) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showMessage(language, Copy.get(language, title)),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18), border: Border.all(color: color)),
          child: Row(
            children: [
              CircleAvatar(radius: 29, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Copy.get(language, title), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF101820))),
                    const SizedBox(height: 3),
                    Text(Copy.get(language, subtitle), style: const TextStyle(fontSize: 14, color: Color(0xFF24364B))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(String language, String title) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction, size: 52, color: Color(0xFF0756C9)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(Copy.get(language, 'coming'), textAlign: TextAlign.center),
          ]),
        ),
      );

  void _showMessage(String language, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — ${Copy.get(language, 'coming')}')),
    );
  }

  void _openMenu(BuildContext context, String language) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.language), title: Text(language == 'ur' ? 'زبان تبدیل کریں' : 'Change language'), onTap: () {
            Navigator.pop(sheetContext);
            widget.onLanguageChanged(language == 'ur' ? 'en' : 'ur');
          }),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('Milk Account • Phase 1'), onTap: () => Navigator.pop(sheetContext)),
        ]),
      ),
    );
  }
}
