import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/data/milk_rate_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('rate changes affect future entries but preserve previous entry rates',
      () async {
    final accounts = AccountRepository();
    await accounts.createAccount(
      customerName: 'Phase8 Rate Customer',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Phase8 Rate Customer'],
    )).single;
    final id = account['id'] as String;
    final milkEntries = MilkEntryRepository();

    await milkEntries.createEntry(
      accountId: id,
      recordedAt: DateTime(2026, 11, 2),
      quantityGrams: 2000,
      ratePaisaPerKg: account['milk_rate_paisa'] as int,
    );

    final updated = await MilkRateRepository().updateRate(
      accountId: id,
      ratePaisaPerKg: 15000,
    );
    expect(updated, 1);

    final refreshed = (await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    await milkEntries.createEntry(
      accountId: id,
      recordedAt: DateTime(2026, 11, 3),
      quantityGrams: 2000,
      ratePaisaPerKg: refreshed['milk_rate_paisa'] as int,
    );

    final entries = await db.query(
      'milk_entries',
      where: 'account_id = ?',
      whereArgs: [id],
      orderBy: 'recorded_at ASC',
    );
    expect(entries.map((row) => row['rate_paisa_per_kg']).toList(),
        [10000, 15000]);
    expect(entries.map((row) => row['total_paisa']).toList(),
        [20000, 30000]);
    await AppDatabase.instance.close();
  });

  test('monthly rate change recalculates only selected month entries', () async {
    final accounts = AccountRepository();
    await accounts.createAccount(
      customerName: 'Monthly Isolation Customer',
      startAt: DateTime(2026, 1, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Monthly Isolation Customer'],
    )).single;
    final id = account['id'] as String;
    final entries = MilkEntryRepository();

    await entries.createEntry(
      accountId: id,
      recordedAt: DateTime.utc(2026, 1, 10),
      quantityGrams: 2000,
      ratePaisaPerKg: 10000,
    );
    await entries.createEntry(
      accountId: id,
      recordedAt: DateTime.utc(2026, 2, 10),
      quantityGrams: 3000,
      ratePaisaPerKg: 10000,
    );

    final changed = await MilkRateRepository().updateMonthEntries(
      accountIds: [id],
      month: DateTime(2026, 1),
      ratePaisaPerKg: 15000,
    );
    expect(changed, 1);

    final rows = await db.query(
      'milk_entries',
      where: 'account_id = ?',
      whereArgs: [id],
      orderBy: 'recorded_at ASC',
    );
    expect(rows.map((row) => row['rate_paisa_per_kg']).toList(),
        [15000, 10000]);
    expect(rows.map((row) => row['total_paisa']).toList(),
        [30000, 30000]);

    final accountBeforeFutureChange = (await db.query(
      'accounts', where: 'id = ?', whereArgs: [id],
    )).single;
    expect(accountBeforeFutureChange['milk_rate_paisa'], 10000);

    await MilkRateRepository().updateFutureRate(
      accountIds: [id],
      ratePaisaPerKg: 20000,
    );
    final updatedAccount = (await db.query(
      'accounts', where: 'id = ?', whereArgs: [id],
    )).single;
    expect(updatedAccount['milk_rate_paisa'], 20000);

    final unchangedRows = await db.query(
      'milk_entries',
      where: 'account_id = ?',
      whereArgs: [id],
      orderBy: 'recorded_at ASC',
    );
    expect(unchangedRows.map((row) => row['rate_paisa_per_kg']).toList(),
        [15000, 10000]);
    await AppDatabase.instance.close();
  });

}
