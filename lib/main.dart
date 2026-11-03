import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    supportedLocales: const [Locale('ur'), Locale('en'), Locale('hi')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0756C9)), scaffoldBackgroundColor: const Color(0xFFF3F9FF)),
    home: language.isEmpty ? LanguageScreen(onSelect: selectLanguage) : Dashboard(language: language, onLanguage: selectLanguage),
  );
}

const copy = <String, Map<String, String>>{
  'ur': {'choose':'زبان منتخب کریں','continue':'جاری رکھیں','brand':'دودھ کا کھاتہ','milk':'دودھ کا اندراج','milkSub':'روزانہ کا دودھ درج کریں','advance':'ایڈوانس','advanceSub':'پہلے سے وصول کی گئی رقم','accounts':'کھاتے','accountsSub':'مکمل تفصیل والے کھاتے','home':'ہوم','reports':'رپورٹس','settings':'سیٹنگز','ad':'دودھ کی کوالٹی بہتر بنائیں!','adSub':'بہترین فیڈ، خوراک اور ڈیری پروڈکٹس','learn':'مزید جانیں','language':'زبان تبدیل کریں','later':'یہ سہولت اگلے مرحلے میں شامل ہوگی'},
  'en': {'choose':'Select Language','continue':'Continue','brand':'Milk Account','milk':'Milk Entry','milkSub':'Add daily milk record','advance':'Advance','advanceSub':'Receive advance payment','accounts':'Accounts','accountsSub':'Complete account details','home':'Home','reports':'Reports','settings':'Settings','ad':'Improve Milk Quality!','adSub':'Best feed, nutrition and dairy products','learn':'Learn More','language':'Change language','later':'This feature will be added in a later phase'},
  'hi': {'choose':'भाषा चुनें','continue':'जारी रखें','brand':'दूध का खाता','milk':'दूध की एंट्री','milkSub':'रोज़ाना का दूध दर्ज करें','advance':'एडवांस','advanceSub':'पहले से प्राप्त की गई राशि','accounts':'खाते','accountsSub':'पूरी जानकारी वाले खाते','home':'होम','reports':'रिपोर्ट','settings':'सेटिंग्स','ad':'दूध की गुणवत्ता बढ़ाएँ!','adSub':'बेहतर चारा, पोषण और डेयरी उत्पाद','learn':'और जानें','language':'भाषा बदलें','later':'यह सुविधा अगले चरण में जोड़ी जाएगी'},
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
  bool get rtl=>widget.language=='ur';
  @override
  Widget build(BuildContext context) {
    final labels=['home','accounts','reports','settings'];
    return Directionality(textDirection:rtl?TextDirection.rtl:TextDirection.ltr,child:Scaffold(
      appBar:PreferredSize(preferredSize:const Size.fromHeight(78),child:AppBar(
        backgroundColor:const Color(0xFF0649AE),foregroundColor:Colors.white,
        leading:IconButton(icon:const Icon(Icons.menu_rounded,size:30),onPressed:menu),titleSpacing:0,
        title:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.local_drink_rounded,size:42),const SizedBox(width:8),Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Milk Account',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Colors.white)),Text(tr(widget.language,'brand'),style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Colors.white))]))]),
        actions:[IconButton(onPressed:(){},icon:const Icon(Icons.notifications_none_rounded,size:28))],
        flexibleSpace:Stack(fit:StackFit.expand,children:[const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF003B91),Color(0xFF0879D5)]))),const Align(alignment:Alignment.centerLeft,child:Opacity(opacity:.18,child:Text('🐄',style:TextStyle(fontSize:40)))),const Align(alignment:Alignment.centerRight,child:Opacity(opacity:.18,child:Text('🥛',style:TextStyle(fontSize:36))))]),
      )),
      body:tab==0?home():Center(child:Text(tr(widget.language,labels[tab]),style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold))),
      bottomNavigationBar:NavigationBar(height:76,backgroundColor:Colors.white,indicatorColor:const Color(0xFFDCEBFF),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,destinations:[
        NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:tr(widget.language,'home')),
        NavigationDestination(icon:const Icon(Icons.people_outline),selectedIcon:const Icon(Icons.people),label:tr(widget.language,'accounts')),
        NavigationDestination(icon:const Icon(Icons.bar_chart_rounded),label:tr(widget.language,'reports')),
        NavigationDestination(icon:const Icon(Icons.settings_outlined),selectedIcon:const Icon(Icons.settings),label:tr(widget.language,'settings')),
      ]),
    ));
  }
  Widget home()=>ListView(padding:const EdgeInsets.fromLTRB(15,12,15,12),children:[
    Container(height:94,padding:const EdgeInsets.all(9),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFE7F8FF),Colors.white,Color(0xFFD9F0FF)]),border:Border.all(color:const Color(0xFF91CFFF),width:1.5),borderRadius:const BorderRadius.all(Radius.circular(17))),child:Row(children:[const Icon(Icons.water_drop_rounded,color:Color(0xFF0875E1),size:48),const SizedBox(width:8),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),decoration:BoxDecoration(color:const Color(0xFFFFD83D),borderRadius:const BorderRadius.all(Radius.circular(5))),child:const Text('Ad',style:TextStyle(fontWeight:FontWeight.w900))),const SizedBox(width:6),Expanded(child:Text(tr(widget.language,'ad'),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)))]),const SizedBox(height:5),Text(tr(widget.language,'adSub'),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))])),const SizedBox(width:6),Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.info_outline,size:17),const SizedBox(height:5),Text(tr(widget.language,'learn'),style:const TextStyle(color:Color(0xFF0756C9),fontSize:10,fontWeight:FontWeight.bold))])])),
    const SizedBox(height:18),
    action('milk','milkSub',Icons.local_drink_rounded,const Color(0xFF0875E1),const Color(0xFFDFF1FF)),
    action('advance','advanceSub',Icons.monetization_on_rounded,const Color(0xFFE2A000),const Color(0xFFFFF2C6)),
    action('accounts','accountsSub',Icons.receipt_long_rounded,const Color(0xFF079B37),const Color(0xFFE0F8E8)),
    Container(height:55,decoration:BoxDecoration(borderRadius:const BorderRadius.all(Radius.circular(14)),gradient:const LinearGradient(colors:[Color(0xFFBCEBFF),Color(0xFFE8FAFF),Color(0xFF9BDE9A)])),child:const Center(child:Icon(Icons.water_drop_rounded,color:Colors.white,size:38))),
  ]);
  Widget action(String title,String sub,IconData icon,Color color,Color tint)=>Container(margin:const EdgeInsets.only(bottom:14),decoration:BoxDecoration(color:tint,border:Border.all(color:color,width:1.6),borderRadius:const BorderRadius.all(Radius.circular(23)),boxShadow:const[BoxShadow(color:Color(0x16002D64),blurRadius:5,offset:Offset(0,3))]),child:InkWell(onTap:()=>title=='accounts'?setState(()=>tab=1):ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${tr(widget.language,title)} — ${tr(widget.language,'later')}'))),borderRadius:const BorderRadius.all(Radius.circular(23)),child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:17),child:Row(children:[CircleAvatar(radius:30,backgroundColor:color,child:Icon(icon,color:Colors.white,size:33)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr(widget.language,title),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Color(0xFF101820))),Text(tr(widget.language,sub),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,color:Color(0xFF24364B)))])),const Icon(Icons.chevron_right_rounded,size:34)]))));
  void menu()=>showModalBottomSheet<void>(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.language),title:Text(tr(widget.language,'language')),onTap:(){Navigator.pop(ctx);languagePicker();}),const ListTile(leading:Icon(Icons.info_outline),title:Text('Milk Account'),subtitle:Text('Milk Collection & Account Management App'))])));
  void languagePicker()=>showModalBottomSheet<void>(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[for(final option in const [('ur','🇵🇰','اردو (پاکستان)'),('en','🇺🇸','English'),('hi','🇮🇳','हिन्दी (Hindi)')])ListTile(leading:Text(option.$2,style:const TextStyle(fontSize:24)),title:Text(option.$3),onTap:(){Navigator.pop(ctx);widget.onLanguage(option.$1);})])));
}
