import 'package:flutter/material.dart';
import '../data/advance_repository.dart';

class AdvanceScreen extends StatefulWidget {
  const AdvanceScreen({super.key, required this.language});
  final String language;
  @override State<AdvanceScreen> createState() => _AdvanceScreenState();
}
class _AdvanceScreenState extends State<AdvanceScreen> {
  final _repo = AdvanceRepository(); final _amount = TextEditingController(); final _note = TextEditingController();
  late Future<List<Map<String,Object?>>> _accounts; List<Map<String,Object?>> _rows = []; String? _id; String _direction = 'given_to_customer'; DateTime _date = DateTime.now(); bool _saving = false;
  bool get _ur => widget.language == 'ur'; String t(String u,String e,String h) => _ur ? u : widget.language == 'hi' ? h : e;
  @override void initState() { super.initState(); _accounts = _repo.activeAccounts(); }
  @override void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }
  Map<String,Object?>? get _selected { for(final row in _rows) { if(row['id']==_id) return row; } return null; }
  String money(Object? v) => 'Rs. ' + (((v as int?) ?? 0) / 100).toStringAsFixed(2);
  InputDecoration dec(String label) => InputDecoration(labelText:label,filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)));
  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> save() async { final amount = double.tryParse(_amount.text.trim()); if(_selected==null || amount==null || !amount.isFinite || amount<=0) { message(t('کھاتہ منتخب کریں اور درست رقم درج کریں','Select an account and enter a valid amount','खाता चुनें और सही रकम दर्ज करें')); return; }
    setState(()=>_saving=true); try { await _repo.addAdvance(accountId:_id!,recordedAt:_date,amountPaisa:(amount*100).round(),direction:_direction,note:_note.text); _amount.clear(); _note.clear(); if(mounted) setState((){}); message(t('ادائیگی محفوظ ہو گئی','Payment saved','भुगतान सेव हो गया')); } catch(e) { message('Could not save: '+e.toString()); } finally { if(mounted) setState(()=>_saving=false); }
  }
  Future<void> pickDate() async { final d=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2000),lastDate:DateTime(2100)); if(d!=null && mounted) setState(()=>_date=DateTime(d.year,d.month,d.day,_date.hour,_date.minute)); }
  Future<void> pickTime() async { final v=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(_date)); if(v!=null && mounted) setState(()=>_date=DateTime(_date.year,_date.month,_date.day,v.hour,v.minute)); }
  @override Widget build(BuildContext context) => Directionality(textDirection:_ur?TextDirection.rtl:TextDirection.ltr,child:Scaffold(backgroundColor:const Color(0xFFF3F9FF),appBar:AppBar(title:Text(t('ایڈوانس اور ادائیگیاں','Advance & Payments','एडवांस और भुगतान')),backgroundColor:const Color(0xFF0649AE),foregroundColor:Colors.white),body:FutureBuilder<List<Map<String,Object?>>>(future:_accounts,builder:(context,s){
    if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator()); if(s.hasError) return Center(child:Text(t('کھاتے لوڈ نہیں ہو سکے','Could not load accounts','खाते लोड नहीं हो सके'))); _rows=s.data??[]; if(_rows.isEmpty) return Center(child:Text(t('پہلے نیا کھاتہ بنائیں','Create an account first','पहले नया खाता बनाएँ'))); if(_id==null || !_rows.any((a)=>a['id']==_id)) _id=_rows.first['id'] as String;
    return FutureBuilder<Map<String,int>>(future:_repo.totals(_id!),builder:(context,tot){ final sums=tot.data??{'given_to_customer':0,'received_from_customer':0}; return ListView(padding:const EdgeInsets.all(16),children:[
      DropdownButtonFormField<String>(value:_id,decoration:dec(t('گاہک کا کھاتہ','Customer account','ग्राहक खाता')),items:_rows.map((a)=>DropdownMenuItem(value:a['id'] as String,child:Text('#'+a['account_number'].toString()+' — '+a['customer_name'].toString()))).toList(),onChanged:(v)=>setState(()=>_id=v)),
      const SizedBox(height:12),Row(children:[Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF2C6),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t('گاہک کو دیے','Given to customer','ग्राहक को दिए')),Text(money(sums['given_to_customer']),style:const TextStyle(fontWeight:FontWeight.bold))]))),const SizedBox(width:8),Expanded(child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFE0F8E8),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t('گاہک سے وصول','Received from customer','ग्राहक से मिले')),Text(money(sums['received_from_customer']),style:const TextStyle(fontWeight:FontWeight.bold))]))) ]),
      const SizedBox(height:18),Text(t('نئی ادائیگی درج کریں','Add payment','नया भुगतान दर्ज करें'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:10),
      SegmentedButton<String>(segments:[ButtonSegment(value:'given_to_customer',label:Text(t('ایڈوانس دیا','Advance given','एडवांस दिया'))),ButtonSegment(value:'received_from_customer',label:Text(t('رقم وصول','Payment received','रकम मिली')))],selected:{_direction},onSelectionChanged:(v)=>setState(()=>_direction=v.first)),
      const SizedBox(height:12),TextField(controller:_amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:dec(t('رقم (روپے)','Amount (Rs.)','रकम (रुपये)'))),const SizedBox(height:10),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:pickDate,icon:const Icon(Icons.calendar_month),label:Text(_date.day.toString()+'/'+_date.month.toString()+'/'+_date.year.toString()))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:pickTime,icon:const Icon(Icons.access_time),label:Text(TimeOfDay.fromDateTime(_date).format(context))))]),
      const SizedBox(height:10),TextField(controller:_note,maxLines:2,decoration:dec(t('تفصیل / نوٹس (اختیاری)','Details / note (optional)','विवरण / नोट (वैकल्पिक)'))),const SizedBox(height:14),
      FilledButton.icon(onPressed:_saving?null:save,icon:const Icon(Icons.save),label:Text(_saving?t('محفوظ ہو رہا ہے','Saving...','सेव हो रहा है'):t('ادائیگی محفوظ کریں','Save payment','भुगतान सेव करें')),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF079B37),foregroundColor:Colors.white)),
      const SizedBox(height:20),Text(t('ادائیگیوں کی تفصیل','Payment history','भुगतान का रिकॉर्ड'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      FutureBuilder<List<Map<String,Object?>>>(future:_repo.history(_id!),builder:(context,h){if(h.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());final list=h.data??[];if(list.isEmpty)return Text(t('ابھی کوئی ادائیگی موجود نہیں','No payments recorded yet','अभी कोई भुगतान दर्ज नहीं है'));return Column(children:list.map((r){final given=r['direction']=='given_to_customer';final dt=DateTime.tryParse(r['recorded_at'].toString())?.toLocal();final date=dt==null?'':dt.day.toString()+'/'+dt.month.toString()+'/'+dt.year.toString();final note=(r['note'] as String?)??'';return Card(color:Colors.white,child:ListTile(leading:Icon(given?Icons.call_made:Icons.call_received),title:Text(given?t('گاہک کو ایڈوانس دیا','Advance given','एडवांस दिया'):t('گاہک سے رقم وصول','Payment received','रकम प्राप्त')),subtitle:Text(note.isEmpty?date:date+' • '+note),trailing:Text(money(r['amount_paisa']))));}).toList());})
    ]); }); }));
}
