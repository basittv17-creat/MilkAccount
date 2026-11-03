import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/advance_repository.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  test('advance and payment are saved and totaled separately', () async {
    await AccountRepository().createAccount(customerName: 'Phase6 Advance Customer', startAt: DateTime(2026, 11, 3), milkRatePaisa: 15000);
    final db = await AppDatabase.instance.database;
    final a = (await db.query('accounts', where: 'customer_name = ?', whereArgs: ['Phase6 Advance Customer'])).single;
    final r = AdvanceRepository();
    await r.addAdvance(accountId: a['id'] as String, recordedAt: DateTime(2026, 11, 3), amountPaisa: 500000, direction: 'given_to_customer');
    await r.addAdvance(accountId: a['id'] as String, recordedAt: DateTime(2026, 11, 3, 10), amountPaisa: 125000, direction: 'received_from_customer');
    final totals = await r.totals(a['id'] as String);
    expect(totals['given_to_customer'], 500000);
    expect(totals['received_from_customer'], 125000);
    expect(await r.history(a['id'] as String), hasLength(2));
    await AppDatabase.instance.close();
  });
  test('advance rejects invalid amount and direction', () async {
    final r = AdvanceRepository();
    await expectLater(r.addAdvance(accountId: 'missing', recordedAt: DateTime.now(), amountPaisa: 0, direction: 'given_to_customer'), throwsArgumentError);
    await expectLater(r.addAdvance(accountId: 'missing', recordedAt: DateTime.now(), amountPaisa: 100, direction: 'other'), throwsArgumentError);
  });
}
