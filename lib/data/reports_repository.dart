import 'app_database.dart';

class ReportsRepository {
  ReportsRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  ({String start, String end}) _localMonthBounds(DateTime month) {
    final startLocal = DateTime(month.year, month.month);
    final endLocal = DateTime(month.year, month.month + 1);
    return (
      start: startLocal.toUtc().toIso8601String(),
      end: endLocal.toUtc().toIso8601String(),
    );
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<Map<String, int>> summary(DateTime month) async {
    final db = await _database.database;
    final bounds = _localMonthBounds(month);
    final dateStart = DateTime.utc(month.year, month.month, 1).toIso8601String();
    final dateEnd =
        DateTime.utc(month.year, month.month + 1, 1).toIso8601String();
    final milk = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa), 0) AS amount, '
      'COALESCE(SUM(quantity_grams), 0) AS grams, COUNT(*) AS entries '
      'FROM milk_entries WHERE recorded_at >= ? AND recorded_at < ?',
      [bounds.start, bounds.end],
    );
    final advance = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_paisa), 0) AS amount FROM advances "
      "WHERE direction = 'given_to_customer' AND recorded_at >= ? AND recorded_at < ?",
      [bounds.start, bounds.end],
    );
    // no_milk_days.day is a calendar-date value, not a UTC timestamp.
    final noMilk = await db.rawQuery(
      'SELECT COUNT(*) AS days FROM no_milk_days WHERE day >= ? AND day < ?',
      [dateStart, dateEnd],
    );
    final given = (advance.first['amount'] as int?) ?? 0;
    final milkAmount = milk.first['amount'] as int;
    return {
      'milk_amount_paisa': milkAmount,
      'milk_quantity_grams': milk.first['grams'] as int,
      'milk_entries': milk.first['entries'] as int,
      'advance_given_paisa': given,
      'balance_paisa': given - milkAmount,
      'no_milk_days': noMilk.first['days'] as int,
    };
  }

  Future<List<Map<String, Object?>>> customerTotals(DateTime month) async {
    final db = await _database.database;
    final bounds = _localMonthBounds(month);
    return db.rawQuery(
      'SELECT a.id, a.account_number, a.customer_name, '
      'COALESCE(SUM(m.total_paisa), 0) AS amount_paisa, '
      'COALESCE(SUM(m.quantity_grams), 0) AS quantity_grams, '
      'COUNT(m.id) AS entries '
      'FROM accounts a LEFT JOIN milk_entries m ON m.account_id = a.id '
      'AND m.recorded_at >= ? AND m.recorded_at < ? '
      'WHERE a.is_active = 1 GROUP BY a.id '
      'ORDER BY amount_paisa DESC, a.account_number ASC',
      [bounds.start, bounds.end],
    );
  }

  Future<List<Map<String, Object?>>> dailyTotals(DateTime month) async {
    final db = await _database.database;
    final bounds = _localMonthBounds(month);
    final rows = await db.rawQuery(
      'SELECT recorded_at, total_paisa, quantity_grams '
      'FROM milk_entries WHERE recorded_at >= ? AND recorded_at < ? '
      'ORDER BY recorded_at ASC',
      [bounds.start, bounds.end],
    );
    final totals = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final local = DateTime.parse(row['recorded_at'] as String).toLocal();
      final key = _dayKey(local);
      final total = totals.putIfAbsent(key, () => {
            'day': key,
            'amount_paisa': 0,
            'quantity_grams': 0,
            'entries': 0,
          });
      total['amount_paisa'] =
          (total['amount_paisa'] as int) + (row['total_paisa'] as int);
      total['quantity_grams'] =
          (total['quantity_grams'] as int) + (row['quantity_grams'] as int);
      total['entries'] = (total['entries'] as int) + 1;
    }
    return totals.values.toList()..sort((a, b) =>
        (b['day'] as String).compareTo(a['day'] as String));
  }
}
