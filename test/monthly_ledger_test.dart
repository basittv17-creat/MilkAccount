import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/data/advance_repository.dart';
import 'package:milk_account/data/monthly_ledger_repository.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  test('monthly ledger totals milk, advances and received payments for selected month', () async {
    await AccountRepository().createAccount(customerName: 'Phase7 Ledger Customer', startAt: DateTime(2026,11,1), milkRatePaisa: 10000);
    final db = await AppDatabase.instance.database;
    final a = (await db.query('accounts', where: 'customer_name = ?', whereArgs: ['Phase7 Ledger Customer'])).single;
    final id = a['id'] as String;
    await MilkEntryRepository().createEntry(accountId: id, recordedAt: DateTime(2026,11,3), quantityGrams: 2000, ratePaisaPerKg: 10000);
    await AdvanceRepository().addAdvance(accountId: id, recordedAt: DateTime(2026,11,3), amountPaisa: 50000, direction: 'given_to_customer');
    await AdvanceRepository().addAdvance(accountId: id, recordedAt: DateTime(2026,11,3), amountPaisa: 2500, direction: 'received_from_customer');
    final result = await MonthlyLedgerRepository().summary(accountId: id, month: DateTime(2026,11));
    expect(result['milk_total_paisa'], 20000);
    expect(result['advance_given_paisa'], 50000);
    expect(result['payment_received_paisa'], 2500);
    expect(result['balance_paisa'], 67500);
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
}
