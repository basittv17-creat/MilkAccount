import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('account search matches customer names and account numbers', () async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.utc(2026, 1, 1).toIso8601String();
    // The FFI database is shared by test suites, so choose an account number
    // that cannot collide with fixtures left by another test.
    final nextNumber = await db.rawQuery(
      'SELECT COALESCE(MAX(account_number), 0) + 1 AS next_number FROM accounts',
    );
    // Use a high, distinctive number so partial-number search cannot match another fixture.
    final accountNumber = (nextNumber.single['next_number'] as int) + 1000000;
    await db.insert('accounts', {
      'id': 'test-account-1',
      'account_number': accountNumber,
      'customer_name': 'MilkAccountSearchFixture20261104QXZ',
      'father_name': 'Ahmed Khan',
      'country_code': '+92',
      'phone_number': '3001234567',
      'start_at': now,
      'milk_rate_paisa': 15000,
      'fat_enabled': 0,
      'created_at': now,
      'updated_at': now,
    });

    final repository = AccountRepository();
    expect((await repository.searchAccounts('MilkAccountSearchFixture20261104QXZ')).length, 1);
    expect((await repository.searchAccounts(accountNumber.toString())).length, 1);
    expect((await repository.searchAccounts('Zain')).isEmpty, isTrue);
    await AppDatabase.instance.close();
  });
}
