import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:small_mall/core/database/app_database.dart';

/// Metadata for a local database backup file
class BackupFileInfo {
  BackupFileInfo({
    required this.file,
    required this.fileName,
    required this.createdAt,
    required this.sizeInBytes,
  });

  final File file;
  final String fileName;
  final DateTime createdAt;
  final int sizeInBytes;

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd  hh:mm a').format(createdAt);
  }
}

/// Statistics about the local SQLite database
class DatabaseStats {
  DatabaseStats({
    required this.sizeInBytes,
    required this.totalProducts,
    required this.totalInvoices,
    required this.totalCustomers,
    required this.totalExpenses,
    required this.totalTreasuryTransactions,
  });

  final int sizeInBytes;
  final int totalProducts;
  final int totalInvoices;
  final int totalCustomers;
  final int totalExpenses;
  final int totalTreasuryTransactions;

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Enterprise-grade Local Database Backup & Recovery Service
class DatabaseBackupService {
  DatabaseBackupService({
    required this.database,
    this.documentsDirectoryProvider,
  });

  final AppDatabase database;
  final Future<Directory> Function()? documentsDirectoryProvider;

  Future<Directory> _getDocsFolder() async {
    if (documentsDirectoryProvider != null) {
      return documentsDirectoryProvider!();
    }
    return getApplicationDocumentsDirectory();
  }

  /// Path to the active small_mall.db database file
  Future<File> getActiveDatabaseFile() async {
    final dbFolder = await _getDocsFolder();
    return File(p.join(dbFolder.path, 'small_mall.db'));
  }

  /// Directory where local backups are stored
  Future<Directory> getBackupsDirectory() async {
    final docsFolder = await _getDocsFolder();
    final backupDir = Directory(p.join(docsFolder.path, 'SmallMall_Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Creates a timestamped local backup file
  Future<BackupFileInfo> createBackup({String? customLabel}) async {
    final dbFile = await getActiveDatabaseFile();
    if (!await dbFile.exists()) {
      throw Exception('Database file does not exist to backup.');
    }

    final backupDir = await getBackupsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final labelPart = (customLabel != null && customLabel.trim().isNotEmpty)
        ? '_${customLabel.trim().replaceAll(RegExp(r'[^\w\d_-]'), '_')}'
        : '';
    final backupFileName = 'small_mall_backup_$timestamp$labelPart.db';
    final destinationFile = File(p.join(backupDir.path, backupFileName));

    // Perform file copy
    await dbFile.copy(destinationFile.path);

    final stat = await destinationFile.stat();
    return BackupFileInfo(
      file: destinationFile,
      fileName: backupFileName,
      createdAt: stat.modified,
      sizeInBytes: stat.size,
    );
  }

  /// List all local backups sorted by newest first
  Future<List<BackupFileInfo>> listBackups() async {
    final backupDir = await getBackupsDirectory();
    if (!await backupDir.exists()) {
      return [];
    }

    final List<BackupFileInfo> list = [];
    final entities = backupDir.listSync();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.db')) {
        final stat = entity.statSync();
        list.add(
          BackupFileInfo(
            file: entity,
            fileName: p.basename(entity.path),
            createdAt: stat.modified,
            sizeInBytes: stat.size,
          ),
        );
      }
    }

    // Sort newest first
    list.sort((a, b) {
      final cmp = b.createdAt.compareTo(a.createdAt);
      if (cmp != 0) return cmp;
      return b.fileName.compareTo(a.fileName);
    });
    return list;
  }

  /// Safely restore a backup file into the active database
  Future<void> restoreBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw Exception('Backup file does not exist.');
    }

    final dbFile = await getActiveDatabaseFile();

    // 1. Create a safety checkpoint of the current state before overwriting
    if (await dbFile.exists()) {
      final backupDir = await getBackupsDirectory();
      final preRestoreName =
          'pre_restore_safety_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
      await dbFile.copy(p.join(backupDir.path, preRestoreName));
    }

    // 2. Safely close database connection so SQLite releases all file locks on Windows
    try {
      await database.close();
    } catch (_) {
      // In case already closed or testing
    }

    // Wait slightly to ensure Windows file handles are fully released
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // 3. Remove WAL and SHM journal files if present
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
    if (await shmFile.exists()) {
      try {
        await shmFile.delete();
      } catch (_) {}
    }

    // 4. Safely delete active db file first to avoid PathExistsException on Windows
    if (await dbFile.exists()) {
      try {
        await dbFile.delete();
      } catch (_) {
        // Fallback handled below
      }
    }

    // 5. Overwrite active database with chosen backup file
    try {
      await backupFile.copy(dbFile.path);
    } catch (_) {
      final bytes = await backupFile.readAsBytes();
      await dbFile.writeAsBytes(bytes, flush: true);
    }
  }

  /// Delete a backup file
  Future<void> deleteBackup(File backupFile) async {
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }

  /// Open the backups directory in the system file manager (e.g. Windows Explorer)
  Future<void> openBackupsFolder() async {
    final backupDir = await getBackupsDirectory();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [backupDir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [backupDir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [backupDir.path]);
    }
  }

  /// Get live statistics about the database records and file size
  Future<DatabaseStats> getDatabaseStats() async {
    final dbFile = await getActiveDatabaseFile();
    final size = await dbFile.exists() ? (await dbFile.length()) : 0;

    final prodCountExp = database.products.id.count();
    final invCountExp = database.invoices.id.count();
    final custCountExp = database.customers.id.count();
    final expCountExp = database.expenses.id.count();
    final treasuryCountExp = database.treasuryTransactions.id.count();

    final productsCount = await (database.selectOnly(database.products)..addColumns([prodCountExp]))
        .map((r) => r.read(prodCountExp) ?? 0)
        .getSingle();
    final invoicesCount = await (database.selectOnly(database.invoices)..addColumns([invCountExp]))
        .map((r) => r.read(invCountExp) ?? 0)
        .getSingle();
    final customersCount = await (database.selectOnly(database.customers)..addColumns([custCountExp]))
        .map((r) => r.read(custCountExp) ?? 0)
        .getSingle();
    final expensesCount = await (database.selectOnly(database.expenses)..addColumns([expCountExp]))
        .map((r) => r.read(expCountExp) ?? 0)
        .getSingle();
    final treasuryCount = await (database.selectOnly(database.treasuryTransactions)..addColumns([treasuryCountExp]))
        .map((r) => r.read(treasuryCountExp) ?? 0)
        .getSingle();

    return DatabaseStats(
      sizeInBytes: size,
      totalProducts: productsCount,
      totalInvoices: invoicesCount,
      totalCustomers: customersCount,
      totalExpenses: expensesCount,
      totalTreasuryTransactions: treasuryCount,
    );
  }
}
