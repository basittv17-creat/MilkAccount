import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/milk_entry_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('daily milk entry stores quantity, FAT and calculated amount', () async {
    final accounts = AccountRepository();
    await accounts.createAccount(
      customerName: 'Phase5 Test Customer',
      phoneNumber: '3001234567',
      startAt: DateTime(2026, 11, 3),
      milkRatePaisa: 15000,
      fatEnabled: true,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Phase5 Test Customer'])).single;
    await MilkEntryRepository().createEntry(
      accountId: account['id'] as String,
      recordedAt: DateTime(2026, 11, 3, 8),
      quantityGrams: 2500,
      fatValue: 4.5,
      ratePaisaPerKg: 15000,
    );
    final rows = await db.query('milk_entries',
      where: 'account_id = ?', whereArgs: [account['id']]);
    expect(rows, hasLength(1));
    expect(rows.single['quantity_grams'], 2500);
    expect(rows.single['fat_value'], 4.5);
    expect(rows.single['total_paisa'], 37500);
    await AppDatabase.instance.close();
  });

  test('daily milk entry rejects zero quantity', () async {
    await expectLater(MilkEntryRepository().createEntry(
      accountId: 'missing', recordedAt: DateTime.now(),
      quantityGrams: 0, ratePaisaPerKg: 10000), throwsArgumentError);
  });

  test('accountsForDate separates accounts with and without a daily entry', () async {
    final accounts = AccountRepository();
    await accounts.createAccount(
      customerName: 'Daily Status Test',
      phoneNumber: '3001234567',
      startAt: DateTime(2026, 11, 3),
      milkRatePaisa: 25000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Daily Status Test'],
    )).single;

    final repository = MilkEntryRepository();
    final before = await repository.accountsForDate(DateTime(2026, 11, 3));
    final beforeRow = before.singleWhere((row) => row['id'] == account['id']);
    expect(beforeRow['has_entry'], 0);

    await repository.createEntry(
      accountId: account['id'] as String,
      recordedAt: DateTime(2026, 11, 3, 7, 42),
      quantityGrams: 20000,
      ratePaisaPerKg: 25000,
    );
    final after = await repository.accountsForDate(DateTime(2026, 11, 3));
    final afterRow = after.singleWhere((row) => row['id'] == account['id']);
    expect(afterRow['has_entry'], 1);
    await AppDatabase.instance.close();
  });

}
