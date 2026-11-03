import '../data/app_database.dart';
import '../data/id_generator.dart';

class AccountRepository {
  AccountRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> searchAccounts(String query) async {
    final db = await _database.database;
    final term = query.trim();
    if (term.isEmpty) return db.query('accounts', where: 'is_active = 1', orderBy: 'account_number ASC');
    return db.query('accounts',
      where: "is_active = 1 AND (customer_name LIKE ? COLLATE NOCASE OR CAST(account_number AS TEXT) LIKE ?)",
      whereArgs: ['%$term%', '%$term%'], orderBy: 'account_number ASC');
  }

  Future<int> createAccount({
    required String customerName, String fatherName = '', String countryCode = '+92',
    String phoneNumber = '', required DateTime startAt, required int milkRatePaisa,
    bool fatEnabled = false, String notes = '',
  }) async {
    final name = customerName.trim();
    if (name.isEmpty) throw ArgumentError.value(customerName, 'customerName', 'Name is required');
    if (milkRatePaisa < 0) throw ArgumentError.value(milkRatePaisa, 'milkRatePaisa', 'Rate cannot be negative');
    final phone = phoneNumber.trim();
    final normalized = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      throw ArgumentError.value(phoneNumber, 'phoneNumber', 'Invalid phone number');
    }
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.transaction((txn) async {
      final rows = await txn.rawQuery('SELECT COALESCE(MAX(account_number), 0) + 1 AS next_number FROM accounts');
      final number = (rows.first['next_number'] as int?) ?? 1;
      return txn.insert('accounts', {
        'id': newLocalId(), 'account_number': number, 'customer_name': name,
        'father_name': fatherName.trim(), 'country_code': countryCode.trim().isEmpty ? '+92' : countryCode.trim(),
        'phone_number': phone, 'start_at': startAt.toUtc().toIso8601String(),
        'milk_rate_paisa': milkRatePaisa, 'fat_enabled': fatEnabled ? 1 : 0,
        'notes': notes.trim(), 'is_active': 1, 'created_at': now, 'updated_at': now,
      });
    });
  }
}