import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/advance_repository.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/data/reports_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('monthly reports aggregate milk, payments, customers and days', () async {
    // Keep this fixture in a unique month so other tests cannot affect totals.
    const reportYear = 2098;
    const reportMonth = 11;
    await AccountRepository().createAccount(
      customerName: 'Phase10 Report Customer',
      startAt: DateTime(reportYear, reportMonth, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Phase10 Report Customer'])).single;
    final id = account['id'] as String;
    await MilkEntryRepository().createEntry(
      accountId: id,
      recordedAt: DateTime(reportYear, reportMonth, 3),
      quantityGrams: 2000,
      ratePaisaPerKg: 10000,
    );
    await AdvanceRepository().addAdvance(
      accountId: id,
      recordedAt: DateTime(reportYear, reportMonth, 3),
      amountPaisa: 1000,
      direction: 'received_from_customer',
    );
    final repo = ReportsRepository();
    final month = DateTime(reportYear, reportMonth);
    final summary = await repo.summary(month);
    expect(summary['milk_amount_paisa'], 20000);
    expect(summary['payment_received_paisa'], 1000);
    expect(summary['balance_paisa'], 19000);
    final customerRows = await repo.customerTotals(month);
    expect(customerRows.firstWhere((row) => row['id'] == id)['entries'], 1);
    expect((await repo.dailyTotals(month)).single['quantity_grams'], 2000);
    await AppDatabase.instance.close();
  });
  test('monthly report uses device-local month and local calendar days', () async {
    const year = 2097;
    const month = 12;
    await AccountRepository().createAccount(
      customerName: 'Local Time Report Boundary',
      startAt: DateTime(year, month, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Local Time Report Boundary'])).single;
    final id = account['id'] as String;
    final repository = MilkEntryRepository();

    await repository.createEntry(
      accountId: id,
      recordedAt: DateTime(year, month, 31, 23, 30),
      quantityGrams: 1000,
      ratePaisaPerKg: 10000,
    );
    await repository.createEntry(
      accountId: id,
      recordedAt: DateTime(year + 1, 1, 1, 0, 15),
      quantityGrams: 2000,
      ratePaisaPerKg: 10000,
    );

    final summary = await ReportsRepository().summary(DateTime(year, month));
    expect(summary['milk_entries'], 1);
    expect(summary['milk_quantity_grams'], 1000);
    final daily = await ReportsRepository().dailyTotals(DateTime(year, month));
    expect(daily, hasLength(1));
    expect(daily.single['day'], '2097-12-31');
    await AppDatabase.instance.close();
  });
}
