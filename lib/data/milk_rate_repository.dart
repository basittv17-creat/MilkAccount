import '../data/app_database.dart';

class MilkRateRepository {
  MilkRateRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async {
    return (await _database.database).query(
      'accounts',
      columns: ['id', 'account_number', 'customer_name', 'milk_rate_paisa', 'country_code', 'phone_number'],
      where: 'is_active = 1',
      orderBy: 'account_number ASC',
    );
  }

  /// Changes only existing milk entries in the selected calendar month.
  /// Account default rates and entries in every other month remain untouched.
  Future<int> updateMonthEntries({
    required List<String> accountIds,
    required DateTime month,
    required int ratePaisaPerKg,
  }) async {
    _validate(accountIds, ratePaisaPerKg);
    final startLocal = DateTime(month.year, month.month, 1);
    final endLocal = DateTime(month.year, month.month + 1, 1);
    final start = startLocal.toUtc().toIso8601String();
    final end = endLocal.toUtc().toIso8601String();
    final db = await _database.database;
    return db.transaction((txn) async {
      var changed = 0;
      for (final id in accountIds) {
        changed += await txn.rawUpdate(
          '''UPDATE milk_entries
             SET rate_paisa_per_kg = ?,
                 total_paisa = CAST((quantity_grams * ? + 500) / 1000 AS INTEGER),
                 updated_at = ?
             WHERE account_id = ? AND recorded_at >= ? AND recorded_at < ?''',
          [
            ratePaisaPerKg,
            ratePaisaPerKg,
            DateTime.now().toUtc().toIso8601String(),
            id,
            start,
            end,
          ],
        );
      }
      return changed;
    });
  }


  /// Updates saved entries from the selected local month onward, then changes
  /// the account's default rate for new entries.
  Future<int> updateFromMonth({
    required List<String> accountIds,
    required DateTime month,
    required int ratePaisaPerKg,
  }) async {
    _validate(accountIds, ratePaisaPerKg);
    final startLocal = DateTime(month.year, month.month, 1);
    final start = startLocal.toUtc().toIso8601String();
    final db = await _database.database;
    return db.transaction((txn) async {
      var changed = 0;
      final now = DateTime.now().toUtc().toIso8601String();
      for (final id in accountIds) {
        changed += await txn.rawUpdate(
          '''UPDATE milk_entries
             SET rate_paisa_per_kg = ?,
                 total_paisa = CAST((quantity_grams * ? + 500) / 1000 AS INTEGER),
                 updated_at = ?
             WHERE account_id = ? AND recorded_at >= ?''',
          [ratePaisaPerKg, ratePaisaPerKg, now, id, start],
        );
        await txn.update(
          'accounts',
          {'milk_rate_paisa': ratePaisaPerKg, 'updated_at': now},
          where: 'id = ? AND is_active = 1',
          whereArgs: [id],
        );
      }
      return changed;
    });
  }

  /// Changes account defaults only; saved historical entries are immutable.
  Future<int> updateFutureRate({
    required List<String> accountIds,
    required int ratePaisaPerKg,
  }) async {
    _validate(accountIds, ratePaisaPerKg);
    final db = await _database.database;
    return db.transaction((txn) async {
      var changed = 0;
      for (final id in accountIds) {
        changed += await txn.update(
          'accounts',
          {
            'milk_rate_paisa': ratePaisaPerKg,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ? AND is_active = 1',
          whereArgs: [id],
        );
      }
      return changed;
    });
  }

  void _validate(List<String> accountIds, int ratePaisaPerKg) {
    if (accountIds.isEmpty || accountIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Select at least one valid account');
    }
    if (ratePaisaPerKg < 0 || ratePaisaPerKg > 100000000) {
      throw ArgumentError.value(
        ratePaisaPerKg,
        'ratePaisaPerKg',
        'Rate must be between 0 and 1,000,000 rupees',
      );
    }
  }

  Future<int> updateRate({
    required String accountId,
    required int ratePaisaPerKg,
  }) async {
    return updateFutureRate(
      accountIds: [accountId],
      ratePaisaPerKg: ratePaisaPerKg,
    );
  }
}
