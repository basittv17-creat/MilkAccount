import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/data/id_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database creates the core offline tables and indexes', () async {
    final db = await AppDatabase.instance.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();

    expect(names, containsAll([
      'accounts',
      'milk_entries',
      'advances',
      'schema_info',
    ]));

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((row) => row['name']),
      containsAll([
        'idx_accounts_name',
        'idx_milk_account_date',
        'idx_advances_account_date',
      ]),
    );
    await AppDatabase.instance.close();
  });

  test('local IDs are UUID v4 shaped and unique', () {
    final first = newLocalId();
    final second = newLocalId();

    expect(
      first,
      matches(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
      ),
    );
    expect(first, isNot(second));
  });
}
