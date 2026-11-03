import '../data/app_database.dart';

class MonthlyLedgerRepository {
  MonthlyLedgerRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async =>
      (await _database.database).query(
        'accounts',
        columns: ['id', 'account_number', 'customer_name'],
        where: 'is_active = 1',
        orderBy: 'account_number ASC',
      );

  ({String start, String end}) _localMonthBounds(DateTime month) {
    final startLocal = DateTime(month.year, month.month);
    final endLocal = DateTime(month.year, month.month + 1);
    return (
      start: startLocal.toUtc().toIso8601String(),
      end: endLocal.toUtc().toIso8601String(),
    );
  }

  Future<Map<String, int>> summary({
    required String accountId,
    required DateTime month,
  }) async {
    final bounds = _localMonthBounds(month);
    final dateStart = DateTime.utc(month.year, month.month, 1).toIso8601String();
    final dateEnd =
        DateTime.utc(month.year, month.month + 1, 1).toIso8601String();
    final db = await _database.database;
    final milk = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa),0) AS total, '
      'COALESCE(SUM(quantity_grams),0) AS grams, COUNT(*) AS entries '
      'FROM milk_entries WHERE account_id = ? AND recorded_at >= ? AND recorded_at < ?',
      [accountId, bounds.start, bounds.end],
    );
    final advances = await db.rawQuery(
      'SELECT direction, COALESCE(SUM(amount_paisa),0) AS total '
      'FROM advances WHERE account_id = ? AND recorded_at >= ? AND recorded_at < ? '
      'GROUP BY direction',
      [accountId, bounds.start, bounds.end],
    );
    final noMilk = await db.rawQuery(
      'SELECT COUNT(*) AS days FROM no_milk_days '
      'WHERE account_id = ? AND day >= ? AND day < ?',
      [accountId, dateStart, dateEnd],
    );
    var given = 0;
    var received = 0;
    for (final row in advances) {
      if (row['direction'] == 'given_to_customer') {
        given = row['total'] as int;
      }
      if (row['direction'] == 'received_from_customer') {
        received = row['total'] as int;
      }
    }
    final milkTotal = milk.first['total'] as int;
    return {
      'milk_total_paisa': milkTotal,
      'milk_quantity_grams': milk.first['grams'] as int,
      'milk_entries': milk.first['entries'] as int,
      'no_milk_days': noMilk.first['days'] as int,
      'advance_given_paisa': given,
      'payment_received_paisa': received,
      'balance_paisa': milkTotal + given - received,
    };
  }

  Future<List<Map<String, Object?>>> entries({
    required String accountId,
    required DateTime month,
  }) async {
    final bounds = _localMonthBounds(month);
    return (await _database.database).query(
      'milk_entries',
      where: 'account_id = ? AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [accountId, bounds.start, bounds.end],
      orderBy: 'recorded_at ASC',
    );
  }
}
