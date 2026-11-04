import 'app_database.dart';

class AccountActivityRepository {
  AccountActivityRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> load({
    required String accountId,
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    final start = DateTime(startDay.year, startDay.month, startDay.day);
    final end = DateTime(endDay.year, endDay.month, endDay.day + 1);
    final from = start.toUtc().toIso8601String();
    final until = end.toUtc().toIso8601String();
    final db = await _database.database;
    final milk = await db.query('milk_entries',
      where: 'account_id = ? AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [accountId, from, until], orderBy: 'recorded_at ASC');
    final advances = await db.query('advances',
      where: "account_id = ? AND direction = 'given_to_customer' AND recorded_at >= ? AND recorded_at < ?",
      whereArgs: [accountId, from, until], orderBy: 'recorded_at ASC');
    final firstDay = DateTime.utc(start.year, start.month, start.day).toIso8601String();
    final lastDay = DateTime.utc(end.year, end.month, end.day).toIso8601String();
    final naga = await db.query('no_milk_days',
      where: 'account_id = ? AND day >= ? AND day < ?',
      whereArgs: [accountId, firstDay, lastDay], orderBy: 'day ASC');
    final result = <Map<String, Object?>>[
      ...milk.map((row) => <String, Object?>{
        ...row, 'activity_type': 'milk',
        'sort_at': row['recorded_at'],
      }),
      ...advances.map((row) => <String, Object?>{
        ...row, 'activity_type': 'advance',
        'sort_at': row['recorded_at'],
      }),
      ...naga.map((row) => <String, Object?>{
        ...row, 'activity_type': 'naga',
        'sort_at': '${row['day'].toString().substring(0, 10)}T${row['recorded_time'] ?? '00:00'}',
      }),
    ];
    result.sort((a, b) => (b['sort_at'] as String).compareTo(a['sort_at'] as String));
    return result;
  }
}
