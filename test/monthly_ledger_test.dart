import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/data/advance_repository.dart';
import 'package:milk_account/data/monthly_ledger_repository.dart';
import 'package:milk_account/data/no_milk_repository.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  test('Rs. 10000 advance minus Rs. 500 milk leaves Rs. 9500 advance', () async {
    await AccountRepository().createAccount(customerName: 'Phase7 Ledger Customer', startAt: DateTime(2026,11,1), milkRatePaisa: 10000);
    final db = await AppDatabase.instance.database;
    final a = (await db.query('accounts', where: 'customer_name = ?', whereArgs: ['Phase7 Ledger Customer'])).single;
    final id = a['id'] as String;
    await MilkEntryRepository().createEntry(accountId: id, recordedAt: DateTime(2026,11,3), quantityGrams: 2000, ratePaisaPerKg: 25000);
    await AdvanceRepository().addAdvance(accountId: id, recordedAt: DateTime(2026,11,3), amountPaisa: 1000000);
    final result = await MonthlyLedgerRepository().summary(accountId: id, month: DateTime(2026,11));
    expect(result['milk_total_paisa'], 50000);
    expect(result['advance_given_paisa'], 1000000);
    expect(result['balance_paisa'], 950000);
    expect(result['remaining_advance_paisa'], 950000);
    expect(result['milk_quantity_grams'], 2000);
    await AppDatabase.instance.close();
  });
  test('monthly ledger includes records by device-local month boundaries', () async {
    await AccountRepository().createAccount(
      customerName: 'Local Time Ledger Boundary',
      startAt: DateTime(2097, 12, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Local Time Ledger Boundary'])).single;
    final id = account['id'] as String;
    final repository = MilkEntryRepository();
    await repository.createEntry(
      accountId: id,
      recordedAt: DateTime(2097, 12, 31, 23, 30),
      quantityGrams: 1000,
      ratePaisaPerKg: 10000,
    );
    await repository.createEntry(
      accountId: id,
      recordedAt: DateTime(2098, 1, 1, 0, 15),
      quantityGrams: 2000,
      ratePaisaPerKg: 10000,
    );
    final ledger = MonthlyLedgerRepository();
    final summary = await ledger.summary(
      accountId: id,
      month: DateTime(2097, 12),
    );
    expect(summary['milk_entries'], 1);
    expect(summary['milk_quantity_grams'], 1000);
    expect(await ledger.entries(
      accountId: id,
      month: DateTime(2097, 12),
    ), hasLength(1));
    await AppDatabase.instance.close();
  });

  test('monthly ledger carries advance forward and returns all monthly activities', () async {
    await AccountRepository().createAccount(
      customerName: 'Ledger Carry Forward Fixture 20261104',
      startAt: DateTime(2026, 1, 1),
      milkRatePaisa: 25000,
      fatEnabled: true,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Ledger Carry Forward Fixture 20261104'],
    )).single;
    final id = account['id'] as String;
    final milk = MilkEntryRepository();
    final payments = AdvanceRepository();

    await payments.addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 1, 5, 8),
      amountPaisa: 2000000,
    );
    await milk.createEntry(
      accountId: id,
      recordedAt: DateTime(2026, 1, 6, 8),
      quantityGrams: 40000,
      fatValue: 4.2,
      ratePaisaPerKg: 25000,
    );
    await milk.createEntry(
      accountId: id,
      recordedAt: DateTime(2026, 2, 1, 7, 30),
      quantityGrams: 73500,
      fatValue: 4.5,
      ratePaisaPerKg: 25000,
    );
    await payments.addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 2, 2, 9),
      amountPaisa: 1000000,
    );
    await payments.addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 2, 3, 10),
      amountPaisa: 20000,
    );
    await NoMilkRepository().markNoMilk(
      accountId: id,
      day: DateTime(2026, 2, 4),
      recordedTime: '07:45',
      note: 'Customer away',
    );

    final ledger = MonthlyLedgerRepository();
    final summary = await ledger.summary(
      accountId: id,
      month: DateTime(2026, 2),
    );
    expect(summary['milk_quantity_grams'], 73500);
    expect(summary['milk_total_paisa'], 1837500);
    expect(summary['opening_advance_paisa'], 1000000);
    expect(summary['remaining_advance_paisa'], 182500);
    expect(summary['balance_paisa'], -817500);
    expect(summary['month_days'], 28);
    expect((summary['average_fat'] as num).toDouble(), 4.5);
    expect(summary['fat_entries'], 1);
    expect(summary['no_milk_days'], 1);

    final activities = await ledger.activities(
      accountId: id,
      month: DateTime(2026, 2),
    );
    expect(activities.map((row) => row['activity_type']).toList(),
        ['milk', 'advance', 'naga']);
    expect(activities.last['note'], 'Customer away');

    await ledger.updateFatEnabled(accountId: id, enabled: false);
    final refreshed = await ledger.activeAccounts();
    final saved = refreshed.singleWhere((row) => row['id'] == id);
    expect(saved['fat_enabled'], 0);
    await AppDatabase.instance.close();
  });
}
