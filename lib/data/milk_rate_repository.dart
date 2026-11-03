import '../data/app_database.dart';

class MilkRateRepository {
  MilkRateRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async {
    return (await _database.database).query(
      'accounts',
      columns: ['id', 'account_number', 'customer_name', 'milk_rate_paisa'],
      where: 'is_active = 1',
      orderBy: 'account_number ASC',
    );
  }

  Future<int> updateRate({
    required String accountId,
    required int ratePaisaPerKg,
  }) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    }
    if (ratePaisaPerKg < 0 || ratePaisaPerKg > 100000000) {
      throw ArgumentError.value(ratePaisaPerKg, 'ratePaisaPerKg',
          'Rate must be between 0 and 1,000,000 rupees');
    }
    return (await _database.database).update(
      'accounts',
      {
        'milk_rate_paisa': ratePaisaPerKg,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND is_active = 1',
      whereArgs: [accountId],
    );
  }
}
