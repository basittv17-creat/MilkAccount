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
    await AccountRepository().createAccount(
      customerName: 'Phase10 Report Customer',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Phase10 Report Customer'])).single;
    final id = account['id'] as String;
    await MilkEntryRepository().createEntry(
      accountId: id,
      recordedAt: DateTime(2026, 11, 3),
      quantityGrams: 2000,
      ratePaisaPerKg: 10000,
    );
    await AdvanceRepository().addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 11, 3),
      amountPaisa: 1000,
      direction: 'received_from_customer',
    );
    final repo = ReportsRepository();
    final summary = await repo.summary(DateTime(2026, 11));
    expect(summary['milk_amount_paisa'], 20000);
    expect(summary['payment_received_paisa'], 1000);
    expect(summary['balance_paisa'], 19000);
    expect((await repo.customerTotals(DateTime(2026, 11))).single['entries'], 1);
    expect((await repo.dailyTotals(DateTime(2026, 11))).single['quantity_grams'], 2000);
    await AppDatabase.instance.close();
  });
}
