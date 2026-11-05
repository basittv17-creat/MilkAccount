import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../data/id_generator.dart';

class TransferMergeResult {
  const TransferMergeResult({
    required this.insertedAccounts,
    required this.updatedAccounts,
    required this.insertedMilkEntries,
    required this.updatedMilkEntries,
    required this.insertedAdvances,
    required this.updatedAdvances,
    required this.insertedNoMilkDays,
    required this.updatedNoMilkDays,
  });

  final int insertedAccounts;
  final int updatedAccounts;
  final int insertedMilkEntries;
  final int updatedMilkEntries;
  final int insertedAdvances;
  final int updatedAdvances;
  final int insertedNoMilkDays;
  final int updatedNoMilkDays;
}

class AmbiguousAccountMatchException implements Exception {
  const AmbiguousAccountMatchException({
    required this.sourceAccount,
    required this.candidates,
  });

  final Map<String, Object?> sourceAccount;
  final List<Map<String, Object?>> candidates;

  @override
  String toString() =>
      'More than one local customer matches ${sourceAccount['customer_name']}.';
}

/// Exports selected customers and merges incoming data without deleting rows.
class DataTransferService {
  DataTransferService({Database? database}) : _injectedDatabase = database;

  final Database? _injectedDatabase;

  Future<Database> get _db async =>
      _injectedDatabase ?? await AppDatabase.instance.database;

  Future<String> createBundle(List<String> accountIds) async {
    if (accountIds.isEmpty) {
      throw ArgumentError('Select at least one customer before sending.');
    }
    final db = await _db;
    final accounts = await db.query(
      'accounts',
      where: 'id IN (${List.filled(accountIds.length, '?').join(',')})',
      whereArgs: accountIds,
      orderBy: 'account_number ASC',
    );
    if (accounts.length != accountIds.toSet().length) {
      throw StateError('One or more selected customers could not be found.');
    }

    final bundleAccounts = <Map<String, Object?>>[];
    for (final account in accounts) {
      final id = account['id'] as String;
      bundleAccounts.add({
        ...account,
        'milk_entries': await db.query(
          'milk_entries',
          where: 'account_id = ?',
          whereArgs: [id],
          orderBy: 'recorded_at ASC',
        ),
        'advances': await db.query(
          'advances',
          where: 'account_id = ?',
          whereArgs: [id],
          orderBy: 'recorded_at ASC',
        ),
        'no_milk_days': await db.query(
          'no_milk_days',
          where: 'account_id = ?',
          whereArgs: [id],
          orderBy: 'day ASC',
        ),
      });
    }

    return jsonEncode({
      'format': 'milk_account_transfer',
      'version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'accounts': bundleAccounts,
    });
  }

  Future<TransferMergeResult> mergeBundle(
    String encoded, {
    Map<String, String> resolutions = const {},
  }) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map ||
        decoded['format'] != 'milk_account_transfer' ||
        decoded['version'] != 1 ||
        decoded['accounts'] is! List) {
      throw const FormatException('This is not a supported Milk Account transfer.');
    }

    final incomingAccounts = <Map<String, Object?>>[];
    for (final value in decoded['accounts'] as List) {
      if (value is! Map) {
        throw const FormatException('The transfer contains an invalid customer.');
      }
      final account = Map<String, Object?>.from(value);
      _validateAccount(account);
      for (final key in ['milk_entries', 'advances', 'no_milk_days']) {
        if (account[key] is! List) {
          throw FormatException('The transfer has an invalid $key list.');
        }
        account[key] = (account[key] as List).map((row) {
          if (row is! Map) {
            throw FormatException('The transfer contains an invalid $key record.');
          }
          final map = Map<String, Object?>.from(row);
          _validateChild(key, map);
          if (map['account_id'] != account['id']) {
            throw const FormatException('A record is linked to the wrong customer.');
          }
          return map;
        }).toList();
      }
      incomingAccounts.add(account);
    }
    if (incomingAccounts.isEmpty) {
      throw const FormatException('The transfer does not contain any customers.');
    }

    final db = await _db;
    final localAccounts = await db.query('accounts');
    final accountMap = <String, String>{};
    final reservedTargets = <String>{};

    for (final incoming in incomingAccounts) {
      final sourceId = incoming['id'] as String;
      final chosenId = resolutions[sourceId];
      if (chosenId != null) {
        final exists = localAccounts.any((row) => row['id'] == chosenId);
        if (!exists) {
          throw const FormatException('A selected matching customer no longer exists.');
        }
        accountMap[sourceId] = chosenId;
        if (!reservedTargets.add(chosenId)) {
          throw const FormatException('Two transferred customers cannot be merged into one local customer.');
        }
        continue;
      }

      final phone = _phoneKey(incoming);
      final candidates = localAccounts.where((local) {
        if (phone.isNotEmpty) return _phoneKey(local) == phone;
        return _personKey(local) == _personKey(incoming);
      }).toList();

      if (candidates.length > 1) {
        throw AmbiguousAccountMatchException(
          sourceAccount: incoming,
          candidates: candidates,
        );
      }
      if (candidates.length == 1) {
        final targetId = candidates.single['id'] as String;
        accountMap[sourceId] = targetId;
        if (!reservedTargets.add(targetId)) {
          throw const FormatException('Two transferred customers match the same local customer.');
        }
      } else {
        final idAlreadyExists = localAccounts.any((row) => row['id'] == sourceId);
        final targetId = idAlreadyExists ? newLocalId() : sourceId;
        accountMap[sourceId] = targetId;
        if (!reservedTargets.add(targetId)) {
          throw const FormatException('The transfer contains duplicate customer identifiers.');
        }
      }
    }

    return db.transaction((txn) async {
      var nextAccountNumber = ((await txn.rawQuery(
        'SELECT COALESCE(MAX(account_number), 0) + 1 AS next_number FROM accounts',
      )).single['next_number'] as int?) ?? 1;

      var insertedAccounts = 0;
      var updatedAccounts = 0;
      var insertedMilk = 0;
      var updatedMilk = 0;
      var insertedAdvances = 0;
      var updatedAdvances = 0;
      var insertedNoMilk = 0;
      var updatedNoMilk = 0;

      for (final incoming in incomingAccounts) {
        final sourceId = incoming['id'] as String;
        final targetId = accountMap[sourceId]!;
        final localRows = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [targetId],
          limit: 1,
        );

        if (localRows.isEmpty) {
          await txn.insert('accounts', {
            'id': targetId,
            'account_number': nextAccountNumber++,
            ..._accountValues(incoming),
            'created_at': incoming['created_at'],
            'updated_at': incoming['updated_at'],
          });
          insertedAccounts++;
        } else if (_isNewer(incoming['updated_at'], localRows.single['updated_at'])) {
          await txn.update(
            'accounts',
            {
              ..._accountValues(incoming),
              'updated_at': incoming['updated_at'],
            },
            where: 'id = ?',
            whereArgs: [targetId],
          );
          updatedAccounts++;
        }

        for (final row in incoming['milk_entries'] as List<Map<String, Object?>>) {
          final result = await _mergeRecord(
            txn,
            table: 'milk_entries',
            source: row,
            targetAccountId: targetId,
            timestampColumn: 'updated_at',
          );
          if (result == 1) {
            insertedMilk++;
          } else if (result == 2) {
            updatedMilk++;
          }
        }
        for (final row in incoming['advances'] as List<Map<String, Object?>>) {
          final result = await _mergeRecord(
            txn,
            table: 'advances',
            source: row,
            targetAccountId: targetId,
            timestampColumn: 'updated_at',
          );
          if (result == 1) {
            insertedAdvances++;
          } else if (result == 2) {
            updatedAdvances++;
          }
        }
        for (final row in incoming['no_milk_days'] as List<Map<String, Object?>>) {
          final result = await _mergeNoMilkDay(txn, row, targetId);
          if (result == 1) {
            insertedNoMilk++;
          } else if (result == 2) {
            updatedNoMilk++;
          }
        }
      }

      return TransferMergeResult(
        insertedAccounts: insertedAccounts,
        updatedAccounts: updatedAccounts,
        insertedMilkEntries: insertedMilk,
        updatedMilkEntries: updatedMilk,
        insertedAdvances: insertedAdvances,
        updatedAdvances: updatedAdvances,
        insertedNoMilkDays: insertedNoMilk,
        updatedNoMilkDays: updatedNoMilk,
      );
    });
  }

  Future<int> _mergeRecord(
    Transaction txn, {
    required String table,
    required Map<String, Object?> source,
    required String targetAccountId,
    required String timestampColumn,
  }) async {
    final id = source['id'] as String;
    final existing = await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isEmpty) {
      await txn.insert(table, {...source, 'account_id': targetAccountId});
      return 1;
    }
    if (existing.single['account_id'] != targetAccountId) {
      throw FormatException('A record identifier conflict was found in $table.');
    }
    if (_isNewer(source[timestampColumn], existing.single[timestampColumn])) {
      final values = Map<String, Object?>.from(source)
        ..remove('id')
        ..remove('account_id');
      await txn.update(table, values, where: 'id = ?', whereArgs: [id]);
      return 2;
    }
    return 0;
  }

  Future<int> _mergeNoMilkDay(
    Transaction txn,
    Map<String, Object?> source,
    String targetAccountId,
  ) async {
    final id = source['id'] as String;
    final byId = await txn.query('no_milk_days', where: 'id = ?', whereArgs: [id], limit: 1);
    if (byId.isNotEmpty) {
      if (byId.single['account_id'] != targetAccountId) {
        throw const FormatException('A no-milk record identifier conflict was found.');
      }
      if (_isNewer(source['created_at'], byId.single['created_at'])) {
        await txn.update(
          'no_milk_days',
          {
            'day': source['day'],
            'note': source['note'],
            'created_at': source['created_at'],
            'recorded_time': source['recorded_time'],
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        return 2;
      }
      return 0;
    }

    final sameDay = await txn.query(
      'no_milk_days',
      where: 'account_id = ? AND day = ?',
      whereArgs: [targetAccountId, source['day']],
      limit: 1,
    );
    if (sameDay.isNotEmpty) {
      if (_isNewer(source['created_at'], sameDay.single['created_at'])) {
        await txn.update(
          'no_milk_days',
          {
            'note': source['note'],
            'created_at': source['created_at'],
            'recorded_time': source['recorded_time'],
          },
          where: 'id = ?',
          whereArgs: [sameDay.single['id']],
        );
        return 2;
      }
      return 0;
    }

    await txn.insert('no_milk_days', {...source, 'account_id': targetAccountId});
    return 1;
  }

  Map<String, Object?> _accountValues(Map<String, Object?> value) => {
        'customer_name': value['customer_name'],
        'father_name': value['father_name'],
        'country_code': value['country_code'],
        'phone_number': value['phone_number'],
        'start_at': value['start_at'],
        'milk_rate_paisa': value['milk_rate_paisa'],
        'fat_enabled': value['fat_enabled'],
        'notes': value['notes'],
        'is_active': value['is_active'],
      };

  void _validateAccount(Map<String, Object?> value) {
    _requiredString(value, 'id');
    _requiredString(value, 'customer_name');
    _requiredString(value, 'father_name');
    _requiredString(value, 'country_code');
    if (value['phone_number'] is! String) {
      throw const FormatException('A customer phone number is invalid.');
    }
    _requiredString(value, 'start_at');
    _requiredString(value, 'created_at');
    _requiredString(value, 'updated_at');
    _validDate(value['start_at'], 'start_at');
    _validDate(value['created_at'], 'created_at');
    _validDate(value['updated_at'], 'updated_at');
    _requiredInt(value, 'milk_rate_paisa', minimum: 0);
    _requiredInt(value, 'fat_enabled', minimum: 0, maximum: 1);
    _requiredInt(value, 'is_active', minimum: 0, maximum: 1);
    if (value['notes'] is! String) {
      throw const FormatException('A customer note is invalid.');
    }
    final phone = _phoneKey(value);
    if ((value['phone_number'] as String).trim().isNotEmpty &&
        (phone.length < 7 || phone.length > 18)) {
      throw const FormatException('A transferred phone number is invalid.');
    }
  }

  void _validateChild(String table, Map<String, Object?> value) {
    _requiredString(value, 'id');
    _requiredString(value, 'account_id');
    _requiredString(value, 'created_at');
    _validDate(value['created_at'], 'created_at');
    if (table != 'no_milk_days') {
      _requiredString(value, 'updated_at');
      _validDate(value['updated_at'], 'updated_at');
      _requiredString(value, 'recorded_at');
      _validDate(value['recorded_at'], 'recorded_at');
      if (value['note'] is! String) {
        throw const FormatException('A transferred record note is invalid.');
      }
    }
    if (table == 'milk_entries') {
      _requiredInt(value, 'quantity_grams', minimum: 1);
      _requiredInt(value, 'rate_paisa_per_kg', minimum: 0);
      _requiredInt(value, 'total_paisa', minimum: 0);
      final fat = value['fat_value'];
      if (fat != null && (fat is! num || !fat.isFinite || fat < 0 || fat > 15)) {
        throw const FormatException('A transferred milk FAT value is invalid.');
      }
    } else if (table == 'advances') {
      _requiredInt(value, 'amount_paisa', minimum: 1);
      if (!['given_to_customer', 'received_from_customer'].contains(value['direction'])) {
        throw const FormatException('A transferred advance direction is invalid.');
      }
    } else {
      _requiredString(value, 'day');
      _validDate(value['day'], 'day');
      _requiredString(value, 'recorded_time');
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value['recorded_time'] as String)) {
        throw const FormatException('A transferred no-milk time is invalid.');
      }
    }
  }

  void _requiredString(Map<String, Object?> value, String key) {
    if (value[key] is! String || (value[key] as String).trim().isEmpty) {
      throw FormatException('A required transfer field is missing: $key.');
    }
  }

  void _requiredInt(
    Map<String, Object?> value,
    String key, {
    required int minimum,
    int? maximum,
  }) {
    final number = value[key];
    if (number is! int || number < minimum || (maximum != null && number > maximum)) {
      throw FormatException('A transfer value is invalid: $key.');
    }
  }

  void _validDate(Object? value, String key) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('A transfer date is invalid: $key.');
    }
  }

  bool _isNewer(Object? incoming, Object? existing) {
    final a = incoming is String ? DateTime.tryParse(incoming) : null;
    final b = existing is String ? DateTime.tryParse(existing) : null;
    return a != null && (b == null || a.isAfter(b));
  }

  String _phoneKey(Map<String, Object?> account) {
    final phone = (account['phone_number'] ?? '').toString();
    if (phone.trim().isEmpty) return '';
    final country = (account['country_code'] ?? '').toString();
    final combined = phone.startsWith('+') ? phone : '$country$phone';
    return combined.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _personKey(Map<String, Object?> account) {
    String normalize(Object? value) => (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return '${normalize(account['customer_name'])}|${normalize(account['father_name'])}';
  }
}
