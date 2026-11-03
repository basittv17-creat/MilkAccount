import 'app_database.dart';
import 'reports_repository.dart';

class HomeDashboardRepository {
  HomeDashboardRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance,
        _reports = ReportsRepository(database: database);

  final AppDatabase _database;
  final ReportsRepository _reports;

  Future<Map<String, Object?>> load(DateTime now) async {
    final db = await _database.database;
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final today = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa), 0) AS amount, '
      'COALESCE(SUM(quantity_grams), 0) AS grams, COUNT(*) AS entries '
      'FROM milk_entries WHERE recorded_at >= ? AND recorded_at < ?',
      [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()],
    );
    final advances = await db.rawQuery(
      'SELECT direction, COALESCE(SUM(amount_paisa), 0) AS amount '
      'FROM advances GROUP BY direction',
    );
    var given = 0;
    var received = 0;
    for (final row in advances) {
      if (row['direction'] == 'given_to_customer') given = row['amount'] as int;
      if (row['direction'] == 'received_from_customer') received = row['amount'] as int;
    }
    final month = DateTime(now.year, now.month);
    return {
      'today_amount_paisa': today.first['amount'] as int,
      'today_quantity_grams': today.first['grams'] as int,
      'today_entries': today.first['entries'] as int,
      'advance_given_paisa': given,
      'remaining_advance_paisa': given - received,
      'month_summary': await _reports.summary(month),
      'daily_totals': await _reports.dailyTotals(month),
    };
  }
}
