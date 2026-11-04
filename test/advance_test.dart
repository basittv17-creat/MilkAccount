import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/advance_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('only advance given is saved and included in advance history', () async {
    await AccountRepository().createAccount(
      customerName: 'Phase6 Advance Customer',
      startAt: DateTime(2026, 11, 3),
      milkRatePaisa: 15000,
    );
    final db = await AppDatabase.instance.database;
    final account = (await db.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['Phase6 Advance Customer'],
    )).single;
    final id = account['id'] as String;
    final repository = AdvanceRepository();

    await repository.addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 11, 3),
      amountPaisa: 500000,
    );
    await repository.addAdvance(
      accountId: id,
      recordedAt: DateTime(2026, 11, 3, 10),
      amountPaisa: 125000,
    );

    expect(await repository.totalGiven(id), 625000);
    expect(await repository.history(id), hasLength(2));
    await AppDatabase.instance.close();
  });

  test('advance rejects invalid amount', () async {
    final repository = AdvanceRepository();
    await expectLater(
      repository.addAdvance(
        accountId: 'missing',
        recordedAt: DateTime.now(),
        amountPaisa: 0,
      ),
      throwsArgumentError,
    );
  });
}
