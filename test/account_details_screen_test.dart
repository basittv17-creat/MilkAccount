import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/advance_repository.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/screens/account_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<String> createAccountWithMilk({int? advancePaisa}) async {
    final now = DateTime.now();
    await AccountRepository().createAccount(
      customerName: 'Advance Summary Regression',
      startAt: now,
      milkRatePaisa: 100000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Advance Summary Regression'],
    )).single;
    final accountId = account['id'] as String;

    await MilkEntryRepository().createEntry(
      accountId: accountId,
      recordedAt: now,
      quantityGrams: 1000,
      ratePaisaPerKg: 100000,
    );
    if (advancePaisa != null) {
      await AdvanceRepository().addAdvance(
        accountId: accountId,
        recordedAt: now,
        amountPaisa: advancePaisa,
      );
    }
    return accountId;
  }

  Future<void> pumpAccountDetails(WidgetTester tester, String accountId) async {
    await tester.pumpWidget(MaterialApp(
      home: AccountDetailsScreen(accountId: accountId, language: 'ur'),
    ));

    // sqflite_common_ffi performs real asynchronous work. Let its isolate
    // complete outside the widget test's fake-async clock before pumping.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  testWidgets('does not show advance summary when customer received no advance',
      (tester) async {
    final accountId = await tester.runAsync(createAccountWithMilk) ??
        (throw StateError('Account setup did not complete.'));
    await pumpAccountDetails(tester, accountId);

    expect(find.text('دودھ کی رقم'), findsOneWidget);
    expect(find.text('Rs. 1000.00'), findsWidgets);
    expect(find.text('ایڈوانس دیا'), findsNothing);
    expect(find.text('باقی ایڈوانس'), findsNothing);

    await tester.runAsync(AppDatabase.instance.close);
  });

  testWidgets('shows advance and positive remaining amount when advance exists',
      (tester) async {
    final accountId = await tester.runAsync(
          () => createAccountWithMilk(advancePaisa: 200000),
        ) ??
        (throw StateError('Account setup did not complete.'));
    await pumpAccountDetails(tester, accountId);

    expect(find.text('ایڈوانس دیا'), findsOneWidget);
    expect(find.text('باقی ایڈوانس'), findsOneWidget);
    expect(find.text('Rs. 1000.00'), findsWidgets);

    await tester.runAsync(AppDatabase.instance.close);
  });

  testWidgets('remaining advance never displays a negative value',
      (tester) async {
    final accountId = await tester.runAsync(
          () => createAccountWithMilk(advancePaisa: 50000),
        ) ??
        (throw StateError('Account setup did not complete.'));
    await pumpAccountDetails(tester, accountId);

    expect(find.text('باقی ایڈوانس'), findsOneWidget);
    expect(find.text('Rs. 0.00'), findsOneWidget);
    expect(find.text('Rs. -500.00'), findsNothing);

    await tester.runAsync(AppDatabase.instance.close);
  });
}
