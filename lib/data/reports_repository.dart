import 'app_database.dart';

class ReportsRepository {
  ReportsRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  String _start(DateTime month) =>
      DateTime.utc(month.year, month.month, 1).toIso8601String();
  String _end(DateTime month) =>
      DateTime.utc(month.year, month.month + 1, 1).toIso8601String();

  Future<Map<String, int>> summary(DateTime month) async {
    final db = await _database.database;
    final start = _start(month);
    final end = _end(month);
    final milk = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa), 0) AS amount, '
      'COALESCE(SUM(quantity_grams), 0) AS grams, COUNT(*) AS entries '
      'FROM milk_entries WHERE recorded_at >= ? AND recorded_at < ?',
      [start, end],
    );
    final advance = await db.rawQuery(
      'SELECT direction, COALESCE(SUM(amount_paisa), 0) AS amount '
      'FROM advances WHERE recorded_at >= ? AND recorded_at < ? '
      'GROUP BY direction',
      [start, end],
    );
    final noMilk = await db.rawQuery(
      'SELECT COUNT(*) AS days FROM no_milk_days WHERE day >= ? AND day < ?',
      [start, end],
    );
    var given = 0;
    var received = 0;
    for (final row in advance) {
      if (row['direction'] == 'given_to_customer') {
        given = row['amount'] as int;
      } else if (row['direction'] == 'received_from_customer') {
        received = row['amount'] as int;
      }
    }
    final milkAmount = milk.first['amount'] as int;
    return {
      'milk_amount_paisa': milkAmount,
      'milk_quantity_grams': milk.first['grams'] as int,
      'milk_entries': milk.first['entries'] as int,
      'advance_given_paisa': given,
      'payment_received_paisa': received,
      'balance_paisa': milkAmount + given - received,
      'no_milk_days': noMilk.first['days'] as int,
    };
  }

  Future<List<Map<String, Object?>>> customerTotals(DateTime month) async {
    final db = await _database.database;
    return db.rawQuery(
      'SELECT a.id, a.account_number, a.customer_name, '
      'COALESCE(SUM(m.total_paisa), 0) AS amount_paisa, '
      'COALESCE(SUM(m.quantity_grams), 0) AS quantity_grams, '
      'COUNT(m.id) AS entries '
      'FROM accounts a LEFT JOIN milk_entries m ON m.account_id = a.id '
      'AND m.recorded_at >= ? AND m.recorded_at < ? '
      'WHERE a.is_active = 1 GROUP BY a.id '
      'ORDER BY amount_paisa DESC, a.account_number ASC',
      [_start(month), _end(month)],
    );
  }

  Future<List<Map<String, Object?>>> dailyTotals(DateTime month) async {
    final db = await _database.database;
    return db.rawQuery(
      'SELECT substr(recorded_at, 1, 10) AS day, '
      'COALESCE(SUM(total_paisa), 0) AS amount_paisa, '
      'COALESCE(SUM(quantity_grams), 0) AS quantity_grams, '
      'COUNT(*) AS entries '
      'FROM milk_entries WHERE recorded_at >= ? AND recorded_at < ? '
      'GROUP BY substr(recorded_at, 1, 10) ORDER BY day DESC',
      [_start(month), _end(month)],
    );
  }
}
