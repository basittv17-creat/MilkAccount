import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

class MonthlyLedgerRepository {
  MonthlyLedgerRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async =>
      (await _database.database).query(
        'accounts',
        columns: [
          'id',
          'account_number',
          'customer_name',
          'father_name',
          'country_code',
          'phone_number',
          'start_at',
          'milk_rate_paisa',
          'fat_enabled',
        ],
        where: 'is_active = 1',
        orderBy: 'account_number ASC',
      );

  ({String start, String end}) _localMonthBounds(DateTime month) {
    final startLocal = DateTime(month.year, month.month, 1);
    final endLocal = DateTime(month.year, month.month + 1, 1);
    return (
      start: startLocal.toUtc().toIso8601String(),
      end: endLocal.toUtc().toIso8601String(),
    );
  }

  ({String start, String end}) _storedDayBounds(DateTime month) {
    final start = DateTime.utc(month.year, month.month, 1);
    final end = DateTime.utc(month.year, month.month + 1, 1);
    return (
      start: start.toIso8601String(),
      end: end.toIso8601String(),
    );
  }

  /// Totals for the selected local calendar month.
  ///
  /// The existing month-only balance remains available as balance_paisa.
  /// The opening and remaining advance values are carried forward from the
  /// account's full history: a positive running balance represents advance
  /// credit held for the customer.
  Future<Map<String, Object?>> summary({
    required String accountId,
    required DateTime month,
  }) async {
    final bounds = _localMonthBounds(month);
    final dayBounds = _storedDayBounds(month);
    final db = await _database.database;

    final milk = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa), 0) AS total, '
      'COALESCE(SUM(quantity_grams), 0) AS grams, '
      'COUNT(*) AS entries, AVG(fat_value) AS average_fat, '
      'COUNT(fat_value) AS fat_entries '
      'FROM milk_entries '
      'WHERE account_id = ? AND recorded_at >= ? AND recorded_at < ?',
      [accountId, bounds.start, bounds.end],
    );

    final monthAdvance = await _advanceTotal(
      db,
      accountId: accountId,
      whereClause: 'recorded_at >= ? AND recorded_at < ?',
      whereArgs: [bounds.start, bounds.end],
    );

    final previousMilk = await db.rawQuery(
      'SELECT COALESCE(SUM(total_paisa), 0) AS total '
      'FROM milk_entries WHERE account_id = ? AND recorded_at < ?',
      [accountId, bounds.start],
    );
    final previousAdvance = await _advanceTotal(
      db,
      accountId: accountId,
      whereClause: 'recorded_at < ?',
      whereArgs: [bounds.start],
    );

    final noMilk = await db.rawQuery(
      'SELECT COUNT(*) AS days FROM no_milk_days '
      'WHERE account_id = ? AND day >= ? AND day < ?',
      [accountId, dayBounds.start, dayBounds.end],
    );

    final milkTotal = (milk.first['total'] as int?) ?? 0;
    final grams = (milk.first['grams'] as int?) ?? 0;
    final given = monthAdvance;
    final monthlyBalance = given - milkTotal;

    final historicMilk = (previousMilk.first['total'] as int?) ?? 0;
    final openingBalance = previousAdvance - historicMilk;
    final closingBalance = openingBalance + monthlyBalance;

    return {
      'milk_total_paisa': milkTotal,
      'milk_quantity_grams': grams,
      'milk_entries': (milk.first['entries'] as int?) ?? 0,
      'no_milk_days': (noMilk.first['days'] as int?) ?? 0,
      'advance_given_paisa': given,
      'balance_paisa': monthlyBalance,
      'opening_balance_paisa': openingBalance,
      'opening_advance_paisa': openingBalance > 0 ? openingBalance : 0,
      'closing_balance_paisa': closingBalance,
      'remaining_advance_paisa': closingBalance > 0 ? closingBalance : 0,
      'month_days': DateTime(month.year, month.month + 1, 0).day,
      'average_fat': milk.first['average_fat'] as num? ?? 0,
      'fat_entries': (milk.first['fat_entries'] as int?) ?? 0,
    };
  }

  Future<int> _advanceTotal(
    DatabaseExecutor db, {
    required String accountId,
    required String whereClause,
    required List<Object?> whereArgs,
  }) async {
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_paisa), 0) AS total "
      "FROM advances WHERE account_id = ? AND direction = 'given_to_customer' AND $whereClause",
      [accountId, ...whereArgs],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Returns every activity in the selected month in chronological order.
  Future<List<Map<String, Object?>>> activities({
    required String accountId,
    required DateTime month,
  }) async {
    final bounds = _localMonthBounds(month);
    final dayBounds = _storedDayBounds(month);
    final db = await _database.database;

    final milk = await db.query(
      'milk_entries',
      where: 'account_id = ? AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [accountId, bounds.start, bounds.end],
      orderBy: 'recorded_at ASC',
    );

    final advances = await db.query(
      'advances',
      where: "account_id = ? AND direction = 'given_to_customer' AND recorded_at >= ? AND recorded_at < ?",
      whereArgs: [accountId, bounds.start, bounds.end],
      orderBy: 'recorded_at ASC',
    );

    final noMilk = await db.query(
      'no_milk_days',
      where: 'account_id = ? AND day >= ? AND day < ?',
      whereArgs: [accountId, dayBounds.start, dayBounds.end],
      orderBy: 'day ASC',
    );

    final result = <Map<String, Object?>>[
      ...milk.map((row) {
        final localTime = DateTime.parse(row['recorded_at'] as String)
            .toLocal()
            .toIso8601String();
        return <String, Object?>{
          ...row,
          'activity_type': 'milk',
          'sort_at': localTime,
        };
      }),
      ...advances.map((row) {
        final localTime = DateTime.parse(row['recorded_at'] as String)
            .toLocal()
            .toIso8601String();
        return <String, Object?>{
          ...row,
          'activity_type': 'advance',
          'sort_at': localTime,
        };
      }),
      ...noMilk.map((row) {
        final day = row['day'].toString().substring(0, 10);
        final time = (row['recorded_time'] ?? '00:00').toString();
        return <String, Object?>{
          ...row,
          'activity_type': 'naga',
          'sort_at': day + 'T' + time + ':00',
        };
      }),
    ];

    result.sort(
      (a, b) => (a['sort_at'] as String).compareTo(b['sort_at'] as String),
    );
    return result;
  }

  /// Retained for callers that need only milk-entry rows.
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

  Future<int> updateFatEnabled({
    required String accountId,
    required bool enabled,
  }) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    }
    return (await _database.database).update(
      'accounts',
      {
        'fat_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND is_active = 1',
      whereArgs: [accountId],
    );
  }
}
