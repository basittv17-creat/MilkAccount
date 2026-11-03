import '../data/app_database.dart';
import '../data/id_generator.dart';

class MilkEntryRepository {
  MilkEntryRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Map<String, Object?>>> activeAccounts() async {
    return (await _database.database).query(
      'accounts',
      columns: ['id', 'account_number', 'customer_name', 'milk_rate_paisa', 'fat_enabled'],
      where: 'is_active = 1',
      orderBy: 'account_number ASC',
    );
  }

  Future<int> createEntry({
    required String accountId,
    required DateTime recordedAt,
    required int quantityGrams,
    double? fatValue,
    required int ratePaisaPerKg,
    String note = '',
  }) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Account is required');
    }
    if (quantityGrams <= 0) {
      throw ArgumentError.value(quantityGrams, 'quantityGrams', 'Quantity must be positive');
    }
    if (ratePaisaPerKg < 0) {
      throw ArgumentError.value(ratePaisaPerKg, 'ratePaisaPerKg', 'Rate cannot be negative');
    }
    if (fatValue != null && (!fatValue.isFinite || fatValue < 0 || fatValue > 15)) {
      throw ArgumentError.value(fatValue, 'fatValue', 'FAT must be between 0 and 15');
    }
    final db = await _database.database;
    final account = await db.query('accounts',
        columns: ['id'], where: 'id = ? AND is_active = 1',
        whereArgs: [accountId], limit: 1);
    if (account.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Active account not found');
    }
    final totalPaisa = (quantityGrams * ratePaisaPerKg / 1000).round();
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('milk_entries', {
      'id': newLocalId(),
      'account_id': accountId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'quantity_grams': quantityGrams,
      'fat_value': fatValue,
      'rate_paisa_per_kg': ratePaisaPerKg,
      'total_paisa': totalPaisa,
      'note': note.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }
}
