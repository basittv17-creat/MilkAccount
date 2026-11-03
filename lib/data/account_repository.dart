import '../data/app_database.dart';

class AccountRepository {
  AccountRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Map<String, Object?>>> searchAccounts(String query) async {
    final db = await _database.database;
    final term = query.trim();
    if (term.isEmpty) {
      return db.query(
        'accounts',
        where: 'is_active = 1',
        orderBy: 'account_number ASC',
      );
    }
    return db.query(
      'accounts',
      where: "is_active = 1 AND (customer_name LIKE ? COLLATE NOCASE OR CAST(account_number AS TEXT) LIKE ?)",
      whereArgs: ['%$term%', '%$term%'],
      orderBy: 'account_number ASC',
    );
  }
}
