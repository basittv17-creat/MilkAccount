import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milk_account/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows language selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MilkAccountApp(preferences: preferences));
    expect(find.text('Milk Account'), findsOneWidget);
    expect(find.text('دودھ کا کھاتہ'), findsOneWidget);
    expect(find.text('آگے بڑھیں'), findsOneWidget);
  });

  testWidgets('saved language opens dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'ur'});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(MilkAccountApp(preferences: preferences));
    expect(find.text('دودھ کا اندراج'), findsOneWidget);
    expect(find.text('ایڈوانس'), findsOneWidget);
    // "کھاتے" is intentionally shown in both the dashboard card and bottom navigation.
    expect(find.text('کھاتے'), findsNWidgets(2));
  });
}
