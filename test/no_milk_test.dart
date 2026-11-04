import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/milk_entry_repository.dart';
import 'package:milk_account/data/no_milk_repository.dart';
import 'package:milk_account/data/monthly_ledger_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('records no-milk day and includes it in monthly ledger', () async {
    await AccountRepository().createAccount(
      customerName: 'Phase9 Naga Customer',
      countryCode: '+44',
      phoneNumber: '7700900123',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Phase9 Naga Customer'])).single;
    final id = account['id'] as String;
    final nagaAccounts = await NoMilkRepository().activeAccounts();
    final nagaAccount = nagaAccounts.singleWhere((row) => row['id'] == id);
    expect(nagaAccount['country_code'], '+44');
    expect(nagaAccount['phone_number'], '7700900123');
    await NoMilkRepository().markNoMilk(
      accountId: id,
      day: DateTime(2026, 11, 3),
      note: 'Customer absent',
      recordedTime: '08:30',
    );
    final savedNaga = (await db.query(
      'no_milk_days',
      where: 'account_id = ?',
      whereArgs: [id],
    )).single;
    expect(savedNaga['recorded_time'], '08:30');
    final summary = await MonthlyLedgerRepository().summary(
      accountId: id, month: DateTime(2026, 11));
    expect(summary['no_milk_days'], 1);
    expect(summary['milk_total_paisa'], 0);
    await AppDatabase.instance.close();
  });

  test('does not allow a no-milk day when milk was already recorded', () async {
    await AccountRepository().createAccount(
      customerName: 'Phase9 Conflict Customer',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Phase9 Conflict Customer'])).single;
    final id = account['id'] as String;
    await MilkEntryRepository().createEntry(
      accountId: id, recordedAt: DateTime(2026, 11, 3),
      quantityGrams: 1000, ratePaisaPerKg: 10000);
    await expectLater(
      NoMilkRepository().markNoMilk(accountId: id, day: DateTime(2026, 11, 3)),
      throwsStateError,
    );
    await AppDatabase.instance.close();
  });
  test('no-milk conflict check uses the selected device-local calendar day', () async {
    await AccountRepository().createAccount(
      customerName: 'Local Day Naga Boundary',
      startAt: DateTime(2098, 2, 1),
      milkRatePaisa: 10000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query('accounts',
      where: 'customer_name = ?', whereArgs: ['Local Day Naga Boundary'])).single;
    final id = account['id'] as String;
    await MilkEntryRepository().createEntry(
      accountId: id,
      recordedAt: DateTime(2098, 2, 12, 23, 45),
      quantityGrams: 1000,
      ratePaisaPerKg: 10000,
    );
    await expectLater(
      NoMilkRepository().markNoMilk(
        accountId: id,
        day: DateTime(2098, 2, 12),
        recordedTime: '23:50',
      ),
      throwsStateError,
    );
    await AppDatabase.instance.close();
  });
}

  test('records a no-milk day for multiple selected accounts on the same date', () async {
    final accounts = AccountRepository();
    await accounts.createAccount(
      customerName: 'Multi Naga Customer Alpha',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );
    await accounts.createAccount(
      customerName: 'Multi Naga Customer Beta',
      startAt: DateTime(2026, 11, 1),
      milkRatePaisa: 10000,
    );

    final db = await AppDatabase.instance.database;
    final first = (await db.query(
      'accounts',
      columns: ['id'],
      where: 'customer_name = ?',
      whereArgs: ['Multi Naga Customer Alpha'],
    )).single['id'] as String;
    final second = (await db.query(
      'accounts',
      columns: ['id'],
      where: 'customer_name = ?',
      whereArgs: ['Multi Naga Customer Beta'],
    )).single['id'] as String;

    final repository = NoMilkRepository();
    await repository.markNoMilk(
      accountId: first,
      day: DateTime(2026, 11, 4),
      note: 'Route closed',
      recordedTime: '07:45',
    );
    await repository.markNoMilk(
      accountId: second,
      day: DateTime(2026, 11, 4),
      note: 'Route closed',
      recordedTime: '07:45',
    );

    final savedRows = await db.query(
      'no_milk_days',
      where: 'account_id IN (?, ?) AND day = ?',
      whereArgs: [
        first,
        second,
        DateTime.utc(2026, 11, 4).toIso8601String(),
      ],
    );
    expect(savedRows, hasLength(2));
    expect(savedRows.map((row) => row['recorded_time']).toSet(), {'07:45'});
    expect(savedRows.map((row) => row['note']).toSet(), {'Route closed'});
    await AppDatabase.instance.close();
  });
