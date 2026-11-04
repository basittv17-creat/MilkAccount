import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('new accounts persist fields and receive sequential numbers', () async {
    final repo = AccountRepository();
    final firstPreview = await repo.nextAccountNumber();
    await repo.createAccount(customerName: 'Phase3 Ali Khan', fatherName: 'Ahmed',
      phoneNumber: '3001234567', startAt: DateTime(2026, 11, 3),
      milkRatePaisa: 15000, fatEnabled: true);
    await repo.createAccount(customerName: 'Phase3 Sara',
      startAt: DateTime(2026, 11, 3), milkRatePaisa: 12000);
    final db = await AppDatabase.instance.database;
    final rows = await db.query('accounts',
      where: 'customer_name IN (?, ?)',
      whereArgs: ['Phase3 Ali Khan', 'Phase3 Sara'],
      orderBy: 'account_number ASC');
    expect(rows, hasLength(2));
    expect(rows[0]['customer_name'], 'Phase3 Ali Khan');
    expect(rows[0]['father_name'], 'Ahmed');
    expect(rows[0]['phone_number'], '3001234567');
    expect(rows[0]['fat_enabled'], 1);
    expect(rows[1]['customer_name'], 'Phase3 Sara');
    expect(rows[1]['account_number'], (rows[0]['account_number'] as int) + 1);
    expect(rows.first['account_number'], firstPreview);
    expect(await repo.nextAccountNumber(), firstPreview + 2);
    await AppDatabase.instance.close();
  });

  test('empty customer name is rejected', () async {
    expect(() => AccountRepository().createAccount(customerName: ' ',
      startAt: DateTime.now(), milkRatePaisa: 100), throwsArgumentError);
  });
}
