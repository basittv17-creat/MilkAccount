import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database. The schema is deliberately independent of the UI.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int schemaVersion = 1;
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    final path = p.join(root, 'milk_account.db');
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: _createSchema,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        account_number INTEGER NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        father_name TEXT NOT NULL DEFAULT '',
        country_code TEXT NOT NULL DEFAULT '+92',
        phone_number TEXT NOT NULL DEFAULT '',
        start_at TEXT NOT NULL,
        milk_rate_paisa INTEGER NOT NULL CHECK (milk_rate_paisa >= 0),
        fat_enabled INTEGER NOT NULL DEFAULT 0 CHECK (fat_enabled IN (0, 1)),
        notes TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE milk_entries (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        quantity_grams INTEGER NOT NULL CHECK (quantity_grams > 0),
        fat_value REAL,
        rate_paisa_per_kg INTEGER NOT NULL CHECK (rate_paisa_per_kg >= 0),
        total_paisa INTEGER NOT NULL CHECK (total_paisa >= 0),
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
        amount_paisa INTEGER NOT NULL CHECK (amount_paisa > 0),
        direction TEXT NOT NULL CHECK (direction IN ('given_to_customer', 'received_from_customer')),
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_accounts_name ON accounts(customer_name COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_milk_account_date ON milk_entries(account_id, recorded_at)');
    await db.execute('CREATE INDEX idx_advances_account_date ON advances(account_id, recorded_at)');
    await db.execute('''
      CREATE TABLE schema_info (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('schema_info', {'key': 'created_version', 'value': '$version'});
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    // Add future schema migrations here; never drop user data during upgrades.
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
