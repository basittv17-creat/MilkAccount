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
    await db.insert('accounts', {
      'id': 'test-account-1',
      'account_number': 12,
      'customer_name': 'Ali Khan',
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
    expect((await repository.searchAccounts('Ali')).length, 1);
    expect((await repository.searchAccounts('12')).length, 1);
    expect((await repository.searchAccounts('Zain')).isEmpty, isTrue);
    await AppDatabase.instance.close();
  });
}
