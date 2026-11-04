import '../data/app_database.dart';
import '../data/id_generator.dart';

class AdvanceRepository {
  AdvanceRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  Future<List<Map<String, Object?>>> activeAccounts() async => (await _database.database).query('accounts', columns: ['id','account_number','customer_name'], where: 'is_active = 1', orderBy: 'account_number ASC');
  Future<int> addAdvance({required String accountId, required DateTime recordedAt, required int amountPaisa, String note = ''}) async {
    if (accountId.trim().isEmpty) throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    if (amountPaisa <= 0) throw ArgumentError.value(amountPaisa, 'amountPaisa', 'Amount must be positive');
    final db = await _database.database; final rows = await db.query('accounts', columns: ['id'], where: 'id = ? AND is_active = 1', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) throw ArgumentError.value(accountId, 'accountId', 'Active account not found');
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('advances', {'id': newLocalId(), 'account_id': accountId, 'recorded_at': recordedAt.toUtc().toIso8601String(), 'amount_paisa': amountPaisa, 'direction': 'given_to_customer', 'note': note.trim(), 'created_at': now, 'updated_at': now});
  }
  Future<List<Map<String, Object?>>> history(String accountId) async => (await _database.database).query('advances', where: "account_id = ? AND direction = 'given_to_customer'", whereArgs: [accountId], orderBy: 'recorded_at DESC');
  Future<int> totalGiven(String accountId) async {
    final rows = await (await _database.database).rawQuery(
      "SELECT COALESCE(SUM(amount_paisa), 0) AS total FROM advances WHERE account_id = ? AND direction = 'given_to_customer'",
      [accountId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }
}
