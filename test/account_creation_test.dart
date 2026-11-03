import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/account_repository.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  test('new accounts persist fields and receive sequential numbers', () async {
    final repo = AccountRepository();
    final a = await repo.createAccount(customerName: ' Ali Khan ', fatherName: 'Ahmed', phoneNumber: '3001234567', startAt: DateTime(2026,11,3), milkRatePaisa: 15000, fatEnabled: true);
    final b = await repo.createAccount(customerName: 'Sara', startAt: DateTime(2026,11,3), milkRatePaisa: 12000);
    final rows = await (await AppDatabase.instance.database).query('accounts', where: 'account_number IN (?,?)', whereArgs: [a,b], orderBy: 'account_number');
    expect(b, a + 1); expect(rows.first['customer_name'], 'Ali Khan'); expect(rows.first['father_name'], 'Ahmed'); expect(rows.first['fat_enabled'], 1); expect(rows.last['customer_name'], 'Sara');
    await AppDatabase.instance.close();
  });
  test('empty customer name is rejected', () async {
    expect(() => AccountRepository().createAccount(customerName: ' ', startAt: DateTime.now(), milkRatePaisa: 100), throwsArgumentError);
  });
}