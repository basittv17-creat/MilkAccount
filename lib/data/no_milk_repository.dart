import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import 'id_generator.dart';

class NoMilkRepository {
  NoMilkRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async =>
      (await _database.database).query(
        'accounts',
        columns: [
          'id',
          'account_number',
          'customer_name',
          'country_code',
          'phone_number',
        ],
        where: 'is_active = 1',
        orderBy: 'account_number ASC',
      );

  Future<void> markNoMilk({
    required String accountId,
    required DateTime day,
    String note = '',
    String recordedTime = '00:00',
  }) async {
    final timeParts = recordedTime.split(':');
    final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) : null;
    final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) : null;
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError.value(recordedTime, 'recordedTime', 'Expected HH:mm');
    }
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    }
    final db = await _database.database;
    final account = await db.query('accounts',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [accountId],
        limit: 1);
    if (account.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Active account not found');
    }
    final normalizedDay = DateTime.utc(day.year, day.month, day.day)
        .toIso8601String();
    final existingMilk = await db.query('milk_entries',
        columns: ['id'],
        where: 'account_id = ? AND recorded_at >= ? AND recorded_at < ?',
        whereArgs: [
          accountId,
          normalizedDay,
          DateTime.utc(day.year, day.month, day.day + 1).toIso8601String()
        ],
        limit: 1);
    if (existingMilk.isNotEmpty) {
      throw StateError('Milk is already recorded for this account and day');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.insert('no_milk_days', {
        'id': newLocalId(),
        'account_id': accountId,
        'day': normalizedDay,
        'note': note.trim(),
        'created_at': now,
        'recorded_time': recordedTime,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('No-milk day is already recorded for this account');
      }
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> days({
    required String accountId,
    required DateTime month,
  }) async {
    final start = DateTime.utc(month.year, month.month, 1).toIso8601String();
    final end = DateTime.utc(month.year, month.month + 1, 1).toIso8601String();
    return (await _database.database).query(
      'no_milk_days',
      where: 'account_id = ? AND day >= ? AND day < ?',
      whereArgs: [accountId, start, end],
      orderBy: 'day ASC',
    );
  }
}
