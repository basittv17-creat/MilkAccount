import '../data/app_database.dart';
import '../data/id_generator.dart';

class AdvanceRepository {
  AdvanceRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  Future<List<Map<String, Object?>>> activeAccounts() async => (await _database.database).query('accounts', columns: ['id','account_number','customer_name'], where: 'is_active = 1', orderBy: 'account_number ASC');
  Future<int> addAdvance({required String accountId, required DateTime recordedAt, required int amountPaisa, required String direction, String note = ''}) async {
    if (accountId.trim().isEmpty) throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    if (amountPaisa <= 0) throw ArgumentError.value(amountPaisa, 'amountPaisa', 'Amount must be positive');
    if (direction != 'given_to_customer' && direction != 'received_from_customer') throw ArgumentError.value(direction, 'direction', 'Invalid payment direction');
    final db = await _database.database; final rows = await db.query('accounts', columns: ['id'], where: 'id = ? AND is_active = 1', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) throw ArgumentError.value(accountId, 'accountId', 'Active account not found');
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('advances', {'id': newLocalId(), 'account_id': accountId, 'recorded_at': recordedAt.toUtc().toIso8601String(), 'amount_paisa': amountPaisa, 'direction': direction, 'note': note.trim(), 'created_at': now, 'updated_at': now});
  }
  Future<List<Map<String, Object?>>> history(String accountId) async => (await _database.database).query('advances', where: 'account_id = ?', whereArgs: [accountId], orderBy: 'recorded_at DESC');
  Future<Map<String, int>> totals(String accountId) async {
    final rows = await (await _database.database).rawQuery('SELECT direction, COALESCE(SUM(amount_paisa),0) AS total FROM advances WHERE account_id = ? GROUP BY direction', [accountId]);
    final result = <String,int>{'given_to_customer':0,'received_from_customer':0}; for (final row in rows) { result[row['direction'] as String] = row['total'] as int; } return result;
  }
}
