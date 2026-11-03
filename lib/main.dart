import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/accounts_screen.dart';
import 'screens/milk_entry_screen.dart';
import 'screens/advance_screen.dart';
import 'screens/monthly_ledger_screen.dart';
import 'screens/milk_rate_screen.dart';
import 'screens/no_milk_screen.dart';
import 'screens/reports_screen.dart';
import 'l10n/language_support.dart';
import 'screens/backup_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MilkAccountApp(preferences: await SharedPreferences.getInstance()));
}

class MilkAccountApp extends StatefulWidget {
  const MilkAccountApp({super.key, required this.preferences});
  final SharedPreferences preferences;
  @override
  State<MilkAccountApp> createState() => _MilkAccountAppState();
}

class _MilkAccountAppState extends State<MilkAccountApp> {
  late String language;
  @override
  void initState() {
    super.initState();
    language = widget.preferences.getString('app_language') ?? '';
  }
  Future<void> selectLanguage(String value) async {
    await widget.preferences.setString('app_language', value);
    if (mounted) setState(() => language = value);
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Milk Account', debugShowCheckedModeBanner: false,
    locale: Locale(language.isEmpty ? 'ur' : language),
    supportedLocales: LanguageSupport.activeLocales,
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0756C9)), scaffoldBackgroundColor: const Color(0xFFF3F9FF)),
    home: language.isEmpty ? LanguageScreen(onSelect: selectLanguage) : Dashboard(language: language, onLanguage: selectLanguage),
  );
}

const copy = <String, Map<String, String>>{
  'ur': {'choose':'زبان منتخب کریں','continue':'جاری رکھیں','brand':'دودھ کا کھاتہ','milk':'دودھ کا اندراج','milkSub':'روزانہ کا دودھ درج کریں','advance':'ایڈوانس','advanceSub':'پہلے سے وصول کی گئی رقم','ledger':'ماہانہ کھاتہ','ledgerSub':'ماہانہ دودھ اور بیلنس','rates':'دودھ کے ریٹ','ratesSub':'ہر گاہک کا دودھ ریٹ تبدیل کریں','naga':'ناگا (دودھ نہیں آیا)','nagaSub':'جس دن دودھ نہ آئے اس کا اندراج کریں','accounts':'کھاتے','accountsSub':'مکمل تفصیل والے کھاتے','home':'ہوم','reports':'رپورٹس','settings':'سیٹنگز','backup':'بیک اپ اور ڈیٹا منتقلی','ad':'دودھ کی کوالٹی بہتر بنائیں!','adSub':'بہترین فیڈ، خوراک اور ڈیری پروڈکٹس','learn':'مزید جانیں','language':'زبان تبدیل کریں','menu':'دیگر سہولیات','later':'یہ سہولت اگلے مرحلے میں شامل ہوگی','saved':'دودھ کا اندراج محفوظ ہو گیا','milkEntry':'روزانہ دودھ درج کریں','todaySummary':'آج کا خلاصہ','todayMilk':'آج کا دودھ','todayAmount':'آج کی دودھ کی رقم','totalAdvance':'کل ایڈوانس دیا','remainingAdvance':'باقی ایڈوانس','monthlySummary':'ماہانہ خلاصہ','milkAmount':'دودھ کی رقم','monthBalance':'ماہانہ بیلنس','milkQuantity':'دودھ کی مقدار','milkEntries':'اندراجات','dailyMilkList':'روزانہ دودھ کی فہرست','noDailyMilk':'اس مہینے ابھی دودھ درج نہیں ہوا','entries':'اندراجات','quickActions':'فوری سہولیات','dashboardError':'ڈیش بورڈ ڈیٹا لوڈ نہیں ہو سکا'},
  'en': {'choose':'Select Language','continue':'Continue','brand':'Milk Account','milk':'Milk Entry','milkSub':'Add daily milk record','advance':'Advance','advanceSub':'Receive advance payment','ledger':'Monthly Ledger','ledgerSub':'Monthly milk and balance','rates':'Milk Rates','ratesSub':'Manage each customer milk rate','naga':'No-Milk Day (Naga)','nagaSub':'Record a day when no milk arrives','accounts':'Accounts','accountsSub':'Complete account details','home':'Home','reports':'Reports','settings':'Settings','backup':'Backup & Data Transfer','ad':'Improve Milk Quality!','adSub':'Best feed, nutrition and dairy products','learn':'Learn More','language':'Change language','menu':'More services','later':'This feature will be added in a later phase','saved':'Milk entry saved successfully','milkEntry':'Daily milk entry','todaySummary':'Today’s Summary','todayMilk':'Today’s Milk','todayAmount':'Today’s Milk Amount','totalAdvance':'Total Advance Given','remainingAdvance':'Remaining Advance','monthlySummary':'Monthly Summary','milkAmount':'Milk Amount','monthBalance':'Monthly Balance','milkQuantity':'Milk Quantity','milkEntries':'Milk Entries','dailyMilkList':'Daily Milk List','noDailyMilk':'No milk entries recorded this month yet','entries':'entries','quickActions':'Quick Actions','dashboardError':'Could not load dashboard data'},
  'hi': {'choose':'भाषा चुनें','continue':'जारी रखें','brand':'दूध का खाता','milk':'दूध की एंट्री','milkSub':'रोज़ाना का दूध दर्ज करें','advance':'एडवांस','advanceSub':'पहले से प्राप्त की गई राशि','ledger':'मासिक खाता','ledgerSub':'मासिक दूध और बैलेंस','rates':'दूध के रेट','ratesSub':'हर ग्राहक का दूध रेट बदलें','naga':'नागा (दूध नहीं आया)','nagaSub':'जिस दिन दूध न आए उसका रिकॉर्ड करें','accounts':'खाते','accountsSub':'पूरी जानकारी वाले खाते','home':'होम','reports':'रिपोर्ट','settings':'सेटिंग्स','backup':'बैकअप और डेटा ट्रांसफर','ad':'दूध की गुणवत्ता बढ़ाएँ!','adSub':'बेहतर चारा, पोषण और डेयरी उत्पाद','learn':'और जानें','language':'भाषा बदलें','menu':'अन्य सुविधाएँ','later':'यह सुविधा अगले चरण में जोड़ी जाएगी','saved':'दूध की एंट्री सेव हो गई','milkEntry':'रोज़ाना दूध दर्ज करें','todaySummary':'आज का सारांश','todayMilk':'आज का दूध','todayAmount':'आज के दूध की रकम','totalAdvance':'कुल दिया एडवांस','remainingAdvance':'बाकी एडवांस','monthlySummary':'मासिक सारांश','milkAmount':'दूध की रकम','monthBalance':'मासिक बैलेंस','milkQuantity':'दूध की मात्रा','milkEntries':'दूध एंट्री','dailyMilkList':'रोज़ाना दूध सूची','noDailyMilk':'इस महीने अभी दूध दर्ज नहीं हुआ','entries':'एंट्री','quickActions':'त्वरित सुविधाएँ','dashboardError':'डैशबोर्ड डेटा लोड नहीं हुआ'},
};
String tr(String lang, String key) => copy[lang]?[key] ?? copy['en']![key]!;

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, required this.onSelect});
  final ValueChanged<String> onSelect;
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}
class _LanguageScreenState extends State<LanguageScreen> {
  String selected = 'ur';
  @override
  Widget build(BuildContext context) => Scaffold(body: Container(
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[Color(0xFF003B91),Color(0xFF159FE4),Colors.white],stops:[0,.55,1])),
    child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22),child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:440),child: Column(children:[
      const Icon(Icons.local_drink_rounded,size:82,color:Colors.white),const Text('Milk Account',style:TextStyle(fontSize:34,fontWeight:FontWeight.w900,color:Colors.white)),const Text('دودھ کا کھاتہ',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.white)),const SizedBox(height:28),
      Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:const BorderRadius.all(Radius.circular(26)),border:Border.all(color:const Color(0xFF9EDCFF),width:3)),child:Column(children:[
        Text(tr(selected,'choose'),style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold,color:Color(0xFF062D70))),const SizedBox(height:14),
        for(final option in const [('ur','🇵🇰','اردو (پاکستان)'),('en','🇺🇸','English'),('hi','🇮🇳','हिन्दी (Hindi)')])
          Material(
            color:selected==option.$1?const Color(0xFFE8F8EC):Colors.white,
            borderRadius:const BorderRadius.all(Radius.circular(14)),
            clipBehavior:Clip.antiAlias,
            child:ListTile(
              dense:true,
              shape:RoundedRectangleBorder(borderRadius:const BorderRadius.all(Radius.circular(14))),
              leading:Text(option.$2,style:const TextStyle(fontSize:25)),
              title:Text(option.$3,style:const TextStyle(fontWeight:FontWeight.w700)),
              trailing:Icon(selected==option.$1?Icons.check_circle:Icons.radio_button_unchecked,color:selected==option.$1?Colors.green:Colors.blueGrey),
              onTap:()=>setState(()=>selected=option.$1),
            ),
          ),
        const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>widget.onSelect(selected),icon:const Icon(Icons.arrow_forward),label:Text(tr(selected,'continue')),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF08A832),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:16))))
      ]))
    ]))))),
  ));
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key,required this.language,required this.onLanguage});
  final String language; final ValueChanged<String> onLanguage;
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
  int tab=0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool get rtl=>LanguageSupport.isRtl(widget.language);
  Future<void> _open(Widget page) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection:rtl?TextDirection.rtl:TextDirection.ltr,child:Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar:PreferredSize(preferredSize:const Size.fromHeight(76),child:AppBar(
        backgroundColor:const Color(0xFF0649AE),foregroundColor:Colors.white,
        leading:IconButton(icon:const Icon(Icons.menu_rounded,size:30),onPressed:()=>_scaffoldKey.currentState?.openDrawer()),titleSpacing:0,
        title:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:49,height:49,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFB9E6FF),width:2),borderRadius:const BorderRadius.all(Radius.circular(15)),boxShadow:const[BoxShadow(color:Color(0x44001D55),blurRadius:7,offset:Offset(0,2))]),child:Stack(alignment:Alignment.center,children:[const Icon(Icons.agriculture_rounded,size:30,color:Color(0xFF0649AE)),Positioned(right:2,bottom:1,child:Container(width:17,height:17,decoration:const BoxDecoration(color:Color(0xFF079B48),shape:BoxShape.circle),child:const Icon(Icons.water_drop_rounded,size:11,color:Colors.white))) ])),const SizedBox(width:9),Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Milk Account',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,fontStyle:FontStyle.italic,color:Colors.white)),Text(tr(widget.language,'brand'),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Colors.white))]))]),
        actions:[IconButton(onPressed:(){},icon:const Icon(Icons.notifications_none_rounded,size:28))],
        flexibleSpace:Stack(fit:StackFit.expand,children:[const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF003B91),Color(0xFF0879D5)]))),const Align(alignment:Alignment.centerLeft,child:Opacity(opacity:.18,child:Text('🐄',style:TextStyle(fontSize:40)))),const Align(alignment:Alignment.centerRight,child:Opacity(opacity:.18,child:Text('🥛',style:TextStyle(fontSize:36))))]),
      )),
      body:tab==0?home():tab==1?AccountsScreen(language:widget.language):tab==2?ReportsScreen(language:widget.language):SettingsScreen(language:widget.language,onLanguageChanged:widget.onLanguage),
      bottomNavigationBar:NavigationBar(height:76,backgroundColor:Colors.white,indicatorColor:const Color(0xFFDCEBFF),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,destinations:[
        NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:tr(widget.language,'home')),
        NavigationDestination(icon:const Icon(Icons.people_outline),selectedIcon:const Icon(Icons.people),label:tr(widget.language,'accounts')),
        NavigationDestination(icon:const Icon(Icons.bar_chart_rounded),label:tr(widget.language,'reports')),
        NavigationDestination(icon:const Icon(Icons.settings_outlined),selectedIcon:const Icon(Icons.settings),label:tr(widget.language,'settings')),
      ]),
    ));
  }
  Widget home() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 22),
    children: [
      Container(
        height: 94,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE7F8FF), Colors.white, Color(0xFFD9F0FF)],
          ),
          border: Border.all(color: const Color(0xFF91CFFF), width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(17)),
          boxShadow: const [BoxShadow(color: Color(0x14004A91), blurRadius: 7, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 67,
            height: 67,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0879D5), Color(0xFF003B91)]),
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
            child: const Stack(alignment: Alignment.center, children: [
              Icon(Icons.local_drink_rounded, color: Colors.white, size: 43),
              Positioned(right: 3, top: 3, child: Icon(Icons.auto_awesome, color: Color(0xFFFFD83D), size: 15)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(color: Color(0xFFFFD83D), borderRadius: BorderRadius.all(Radius.circular(5))),
                  child: const Text('Ad', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(tr(widget.language, 'ad'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF073B70)))),
              ]),
              const SizedBox(height: 5),
              Text(tr(widget.language, 'adSub'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF38566F))),
            ],
          )),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_forward_ios_rounded, size: 17, color: Color(0xFF0756C9)),
        ]),
      ),
      const SizedBox(height: 19),
      action('milk','milkSub',Icons.local_drink_rounded,const Color(0xFF0875E1),const Color(0xFFE8F4FF)),
      action('advance','advanceSub',Icons.monetization_on_rounded,const Color(0xFFE2A000),const Color(0xFFFFF6D9)),
      action('accounts','accountsSub',Icons.receipt_long_rounded,const Color(0xFF079B37),const Color(0xFFE8F8EC)),
    ],
  );

  Widget action(String title,String sub,IconData icon,Color color,Color tint) => Container(
    margin: const EdgeInsets.only(bottom: 13),
    decoration: BoxDecoration(
      color: tint,
      border: Border.all(color: color.withOpacity(.8), width: 1.7),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      boxShadow: const [BoxShadow(color: Color(0x18002D64), blurRadius: 7, offset: Offset(0, 3))],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        onTap: () => title=='accounts'
          ? setState(()=>tab=1)
          : title=='milk'
            ? Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>MilkEntryScreen(language:widget.language)))
            : title=='advance'
              ? Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>AdvanceScreen(language:widget.language)))
              : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(17))),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(widget.language,title), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF101820))),
                const SizedBox(height: 3),
                Text(tr(widget.language,sub), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF24364B))),
              ],
            )),
            Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 34, color: color),
          ]),
        ),
      ),
    ),
  );

  Widget _buildDrawer() => Drawer(
    width: 310,
    child: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF003B91), Color(0xFF0879D5)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white70, width: 1.5),
                  ),
                  child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Milk Account',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(
                  tr(widget.language, 'brand'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(widget.language, 'menu'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerTile(Icons.home_rounded, tr(widget.language, 'home'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  setState(() => tab = 0);
                }),
                _drawerTile(Icons.people_alt_rounded, tr(widget.language, 'accounts'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  setState(() => tab = 1);
                }),
                _drawerTile(Icons.bar_chart_rounded, tr(widget.language, 'reports'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  setState(() => tab = 2);
                }),
                const Divider(indent: 16, endIndent: 16, height: 18),
                _drawerTile(Icons.local_drink_rounded, tr(widget.language, 'milk'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(MilkEntryScreen(language: widget.language));
                }),
                _drawerTile(Icons.payments_rounded, tr(widget.language, 'advance'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(AdvanceScreen(language: widget.language));
                }),
                _drawerTile(Icons.calendar_month_rounded, tr(widget.language, 'ledger'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(MonthlyLedgerScreen(language: widget.language));
                }),
                _drawerTile(Icons.price_change_rounded, tr(widget.language, 'rates'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(MilkRateScreen(language: widget.language));
                }),
                _drawerTile(Icons.event_busy_rounded, tr(widget.language, 'naga'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(NoMilkScreen(language: widget.language));
                }),
                const Divider(indent: 16, endIndent: 16, height: 18),
                _drawerTile(Icons.backup_rounded, tr(widget.language, 'backup'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  _open(BackupScreen(language: widget.language));
                }),
                _drawerTile(Icons.settings_rounded, tr(widget.language, 'settings'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  setState(() => tab = 3);
                }),
                _drawerTile(Icons.language_rounded, tr(widget.language, 'language'), () {
                  _scaffoldKey.currentState?.closeDrawer();
                  languagePicker();
                }),
                _drawerTile(Icons.info_outline_rounded, 'About Milk Account', () {
                  _scaffoldKey.currentState?.closeDrawer();
                  showAboutDialog(
                    context: context,
                    applicationName: 'Milk Account',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Milk Collection & Account Management App',
                  );
                }),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Milk Account • 1.0.0', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
          ),
        ],
      ),
    ),
  );

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: const Color(0xFF0756C9)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.blueGrey),
    dense: true,
    onTap: onTap,
  );

  void languagePicker()=>showModalBottomSheet<void>(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[for(final option in const [('ur','🇵🇰','اردو (پاکستان)'),('en','🇺🇸','English'),('hi','🇮🇳','हिन्दी (Hindi)')])ListTile(leading:Text(option.$2,style:const TextStyle(fontSize:24)),title:Text(option.$3),onTap:(){Navigator.pop(ctx);widget.onLanguage(option.$1);})])));
}
