import 'package:flutter_test/flutter_test.dart';
import 'package:milk_account/services/data_transfer_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _database() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      account_number INTEGER NOT NULL UNIQUE,
      customer_name TEXT NOT NULL,
      father_name TEXT NOT NULL DEFAULT '',
      country_code TEXT NOT NULL DEFAULT '+92',
      phone_number TEXT NOT NULL DEFAULT '',
      start_at TEXT NOT NULL,
      milk_rate_paisa INTEGER NOT NULL,
      fat_enabled INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE milk_entries (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      quantity_grams INTEGER NOT NULL,
      fat_value REAL,
      rate_paisa_per_kg INTEGER NOT NULL,
      total_paisa INTEGER NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE advances (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      amount_paisa INTEGER NOT NULL,
      direction TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE no_milk_days (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      day TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      recorded_time TEXT NOT NULL DEFAULT '00:00',
      UNIQUE(account_id, day),
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
    )
  ''');
  return db;
}

const _old = '2026-01-01T00:00:00.000Z';
const _new = '2026-02-01T00:00:00.000Z';

Map<String, Object?> _account({
  required String id,
  required int number,
  required String name,
  required String phone,
  String updatedAt = _new,
}) =>
    {
      'id': id,
      'account_number': number,
      'customer_name': name,
      'father_name': 'Hassan',
      'country_code': '+92',
      'phone_number': phone,
      'start_at': _old,
      'milk_rate_paisa': 12000,
      'fat_enabled': 0,
      'notes': '',
      'is_active': 1,
      'created_at': _old,
      'updated_at': updatedAt,
    };

Map<String, Object?> _milk({
  required String id,
  required String accountId,
  int quantity = 1000,
}) =>
    {
      'id': id,
      'account_id': accountId,
      'recorded_at': _new,
      'quantity_grams': quantity,
      'fat_value': null,
      'rate_paisa_per_kg': 12000,
      'total_paisa': 12000,
      'note': '',
      'created_at': _new,
      'updated_at': _new,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database senderDb;
  late Database receiverDb;

  setUp(() async {
    senderDb = await _database();
    receiverDb = await _database();
  });

  tearDown(() async {
    await senderDb.close();
    await receiverDb.close();
  });

  test('merges into matching customer, keeps receiver-only rows and is repeat-safe',
      () async {
    await senderDb.insert('accounts', _account(
      id: 'sender-customer',
      number: 88,
      name: 'Ali Hassan',
      phone: '3001234567',
    ));
    await senderDb.insert('milk_entries', _milk(
      id: 'sender-milk',
      accountId: 'sender-customer',
    ));

    await receiverDb.insert('accounts', _account(
      id: 'receiver-customer',
      number: 4,
      name: 'Ali Hassan',
      phone: '3001234567',
      updatedAt: _old,
    ));
    await receiverDb.insert('milk_entries', _milk(
      id: 'receiver-only-milk',
      accountId: 'receiver-customer',
      quantity: 1500,
    ));

    final sender = DataTransferService(database: senderDb);
    final receiver = DataTransferService(database: receiverDb);
    final bundle = await sender.createBundle(['sender-customer']);

    final first = await receiver.mergeBundle(bundle);
    expect(first.insertedAccounts, 0);
    expect(first.updatedAccounts, 1);
    expect(first.insertedMilkEntries, 1);

    final customer = (await receiverDb.query('accounts')).single;
    expect(customer['id'], 'receiver-customer');
    expect(customer['account_number'], 4);
    expect(customer['milk_rate_paisa'], 12000);

    final entries = await receiverDb.query('milk_entries');
    expect(entries.length, 2);
    expect(entries.map((row) => row['id']).toSet(),
        {'receiver-only-milk', 'sender-milk'});
    expect(entries.every((row) => row['account_id'] == 'receiver-customer'), isTrue);

    final second = await receiver.mergeBundle(bundle);
    expect(second.insertedAccounts, 0);
    expect(second.insertedMilkEntries, 0);
    expect((await receiverDb.query('milk_entries')).length, 2);
  });

  test('creates new customer with next local account number', () async {
    await senderDb.insert('accounts', _account(
      id: 'sender-new',
      number: 79,
      name: 'New Customer',
      phone: '3007654321',
    ));
    await receiverDb.insert('accounts', _account(
      id: 'receiver-existing',
      number: 12,
      name: 'Other Customer',
      phone: '3001111111',
    ));

    final bundle = await DataTransferService(database: senderDb)
        .createBundle(['sender-new']);
    final result = await DataTransferService(database: receiverDb)
        .mergeBundle(bundle);

    expect(result.insertedAccounts, 1);
    final inserted = await receiverDb.query(
      'accounts',
      where: 'customer_name = ?',
      whereArgs: ['New Customer'],
    );
    expect(inserted.single['account_number'], 13);
    expect(inserted.single['id'], 'sender-new');
  });

  test('ambiguous name and father-name match stops before changing data', () async {
    await senderDb.insert('accounts', _account(
      id: 'sender-ambiguous',
      number: 1,
      name: 'Ali Hassan',
      phone: '',
    ));
    await receiverDb.insert('accounts', _account(
      id: 'local-one',
      number: 1,
      name: 'Ali Hassan',
      phone: '',
    ));
    await receiverDb.insert('accounts', _account(
      id: 'local-two',
      number: 2,
      name: 'Ali Hassan',
      phone: '',
    ));

    final bundle = await DataTransferService(database: senderDb)
        .createBundle(['sender-ambiguous']);
    await expectLater(
      DataTransferService(database: receiverDb).mergeBundle(bundle),
      throwsA(isA<AmbiguousAccountMatchException>()),
    );
    expect((await receiverDb.query('accounts')).length, 2);
  });

  test('rejects invalid transfer before modifying receiver database', () async {
    await receiverDb.insert('accounts', _account(
      id: 'safe-local',
      number: 1,
      name: 'Safe Customer',
      phone: '3001111111',
    ));

    await expectLater(
      DataTransferService(database: receiverDb).mergeBundle('{"version":99}'),
      throwsFormatException,
    );
    final rows = await receiverDb.query('accounts');
    expect(rows.length, 1);
    expect(rows.single['id'], 'safe-local');
  });
}
