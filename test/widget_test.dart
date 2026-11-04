import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milk_account/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows animated splash before language selection',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MilkAccountApp(preferences: preferences));

    expect(find.text('ایپ لوڈ ہو رہی ہے، براہِ کرم انتظار کریں...'),
        findsOneWidget);
    expect(find.text('جاری رکھیں'), findsNothing);
    await tester.pump(const Duration(milliseconds: 4400));
    await tester.pump();

    expect(find.text('جاری رکھیں'), findsOneWidget);
    expect(find.text('हिन्दी (Hindi)'), findsOneWidget);
  });

  testWidgets('saved Urdu language opens dashboard after splash',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'ur'});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MilkAccountApp(preferences: preferences));

    expect(find.text('ایپ لوڈ ہو رہی ہے، براہِ کرم انتظار کریں...'),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4400));
    await tester.pump();

    expect(find.text('دودھ کا اندراج'), findsOneWidget);
    expect(find.text('ایڈوانس'), findsOneWidget);
    expect(find.text('کھاتے'), findsNWidgets(2));
  });

  testWidgets('saved Hindi language opens Hindi dashboard after splash',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'hi'});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MilkAccountApp(preferences: preferences));

    expect(find.text('ایپ لوڈ ہو رہی ہے، براہِ کرم انتظار کریں...'),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4400));
    await tester.pump();

    expect(find.text('दूध की एंट्री'), findsOneWidget);
    expect(find.text('एडوان्स'), findsOneWidget);
    expect(find.text('खाते'), findsNWidgets(2));
  });
}
