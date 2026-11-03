import '../data/app_database.dart';
import '../data/id_generator.dart';

class AccountRepository {
  AccountRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> searchAccounts(String query) async {
    final db = await _database.database;
    final term = query.trim();
    if (term.isEmpty) {
      return db.query('accounts', where: 'is_active = 1', orderBy: 'account_number ASC');
    }
    return db.query('accounts',
      where: "is_active = 1 AND (customer_name LIKE ? COLLATE NOCASE OR CAST(account_number AS TEXT) LIKE ?)",
      whereArgs: ['%$term%', '%$term%'], orderBy: 'account_number ASC');
  }

  Future<Map<String, Object?>?> getAccount(String id) async {
    final rows = await (await _database.database).query('accounts',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> createAccount({
    required String customerName, String fatherName = '', String countryCode = '+92',
    String phoneNumber = '', required DateTime startAt, required int milkRatePaisa,
    bool fatEnabled = false, String notes = '',
  }) async {
    final values = _values(customerName, fatherName, countryCode, phoneNumber,
        startAt, milkRatePaisa, fatEnabled, notes);
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
          'SELECT COALESCE(MAX(account_number), 0) + 1 AS next_number FROM accounts');
      final number = (rows.first['next_number'] as int?) ?? 1;
      return txn.insert('accounts', {
        'id': newLocalId(), 'account_number': number, ...values,
        'is_active': 1, 'created_at': now, 'updated_at': now,
      });
    });
  }

  Future<int> updateAccount({
    required String id, required String customerName, required String fatherName,
    required String countryCode, required String phoneNumber, required DateTime startAt,
    required int milkRatePaisa, required bool fatEnabled, required String notes,
  }) async {
    final values = _values(customerName, fatherName, countryCode, phoneNumber,
        startAt, milkRatePaisa, fatEnabled, notes);
    return (await _database.database).update('accounts', {
      ...values, 'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _values(String customerName, String fatherName,
      String countryCode, String phoneNumber, DateTime startAt,
      int milkRatePaisa, bool fatEnabled, String notes) {
    final name = customerName.trim();
    if (name.isEmpty) throw ArgumentError.value(customerName, 'customerName', 'Name is required');
    if (milkRatePaisa < 0) throw ArgumentError.value(milkRatePaisa, 'milkRatePaisa', 'Rate cannot be negative');
    final phone = phoneNumber.trim();
    final normalized = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}).hasMatch(normalized)) {
      throw ArgumentError.value(phoneNumber, 'phoneNumber', 'Invalid phone number');
    }
    return {
      'customer_name': name, 'father_name': fatherName.trim(),
      'country_code': countryCode.trim().isEmpty ? '+92' : countryCode.trim(),
      'phone_number': phone, 'start_at': startAt.toUtc().toIso8601String(),
      'milk_rate_paisa': milkRatePaisa, 'fat_enabled': fatEnabled ? 1 : 0,
      'notes': notes.trim(),
    };
  }
}
).hasMatch(normalized)) {
      throw ArgumentError.value(phoneNumber, 'phoneNumber', 'Invalid phone number');
    }
    return {
      'customer_name': name, 'father_name': fatherName.trim(),
      'country_code': countryCode.trim().isEmpty ? '+92' : countryCode.trim(),
      'phone_number': phone, 'start_at': startAt.toUtc().toIso8601String(),
      'milk_rate_paisa': milkRatePaisa, 'fat_enabled': fatEnabled ? 1 : 0,
      'notes': notes.trim(),
    };
  }
}
