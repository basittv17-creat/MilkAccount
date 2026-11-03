import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

class BackupService {
  BackupService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<String?> exportBackup() async {
    final db = await _database.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final databasePath = await _database.getDatabasePath();
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Milk Account backup',
      fileName: 'milk_account_backup.db',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (destination == null || destination.trim().isEmpty) return null;

    await _database.close();
    try {
      await File(databasePath).copy(destination);
      return destination;
    } finally {
      await _database.database;
    }
  }

  Future<bool> restoreBackup() async {
    final selection = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Milk Account backup',
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
      withData: false,
    );
    if (selection == null || selection.files.isEmpty) return false;
    final sourcePath = selection.files.single.path;
    if (sourcePath == null) {
      throw const FormatException('The selected backup file cannot be accessed.');
    }

    final source = File(sourcePath);
    if (!await source.exists() || !await _isValidDatabase(sourcePath)) {
      throw const FormatException('This is not a valid Milk Account database backup.');
    }

    final databasePath = await _database.getDatabasePath();
    final safetyCopyPath = '$databasePath.before-restore-backup';
    await _database.close();
    try {
      final current = File(databasePath);
      if (await current.exists()) {
        await current.copy(safetyCopyPath);
      }
      await _removeSidecarFiles(databasePath);
      await source.copy(databasePath);
      final restored = await _database.database;
      final check = await restored.rawQuery('PRAGMA integrity_check');
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw const FormatException('The restored database failed its integrity check.');
      }
      return true;
    } catch (_) {
      await _database.close();
      final safetyCopy = File(safetyCopyPath);
      if (await safetyCopy.exists()) {
        await _removeSidecarFiles(databasePath);
        await safetyCopy.copy(databasePath);
      }
      await _database.database;
      rethrow;
    }
  }

  Future<bool> _isValidDatabase(String path) async {
    final file = File(path);
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      if (String.fromCharCodes(header) != 'SQLite format 3\u0000') {
        return false;
      }
    } finally {
      await handle.close();
    }

    Database? candidate;
    try {
      candidate = await openDatabase(path, readOnly: true);
      final tables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      return names.containsAll([
        'accounts',
        'milk_entries',
        'advances',
        'no_milk_days',
      ]);
    } catch (_) {
      return false;
    } finally {
      await candidate?.close();
    }
  }

  Future<void> _removeSidecarFiles(String path) async {
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }
}
