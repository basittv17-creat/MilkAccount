import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:milk_account/data/account_repository.dart';
import 'package:milk_account/data/app_database.dart';
import 'package:milk_account/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDatabaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Give this test suite its own SQLite directory. Flutter may execute
    // different test files concurrently, and the default FFI path is shared.
    testDatabaseDirectory = await Directory.systemTemp.createTemp(
      'milk_account_backup_test_',
    );
    await databaseFactory.setDatabasesPath(testDatabaseDirectory.path);
  });

  setUp(() async {
    await AppDatabase.instance.close();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
    if (await testDatabaseDirectory.exists()) {
      await testDatabaseDirectory.delete(recursive: true);
    }
  });

  test('creates a complete SQLite backup snapshot with account data', () async {
    final customerName = 'Backup Test ${DateTime.now().microsecondsSinceEpoch}';
    await AccountRepository().createAccount(
      customerName: customerName,
      startAt: DateTime.now(),
      milkRatePaisa: 12500,
      fatherName: 'Backup Test Father',
      phoneNumber: '03001234567',
    );

    final bytes = await BackupService().createBackupBytes();
    expect(bytes.length, greaterThan(16));
    expect(
      String.fromCharCodes(bytes.take(16)),
      'SQLite format 3\u0000',
    );

    final backupFile = File(
      Directory.systemTemp.path +
          '/milk_account_backup_test_' +
          DateTime.now().microsecondsSinceEpoch.toString() +
          '.db',
    );
    await backupFile.writeAsBytes(bytes, flush: true);

    Database? snapshot;
    try {
      snapshot = await openDatabase(backupFile.path, readOnly: true);
      final rows = await snapshot.query(
        'accounts',
        where: 'customer_name = ?',
        whereArgs: [customerName],
      );
      expect(rows, hasLength(1));
      expect(rows.single['father_name'], 'Backup Test Father');
      expect(rows.single['phone_number'], '03001234567');

      final tableRows = await snapshot.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows.map((row) => row['name']).toSet();
      expect(
        tableNames,
        containsAll(['accounts', 'milk_entries', 'advances', 'no_milk_days']),
      );
    } finally {
      await snapshot?.close();
      if (await backupFile.exists()) await backupFile.delete();
    }
  });
}
