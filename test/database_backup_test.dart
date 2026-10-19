import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/services/database_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseBackupService Tests', () {
    late Directory tempDir;
    late AppDatabase database;
    late DatabaseBackupService backupService;
    late File activeDbFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('small_mall_backup_test_');
      database = AppDatabase.forTesting(NativeDatabase.memory());
      backupService = DatabaseBackupService(
        database: database,
        documentsDirectoryProvider: () async => tempDir,
      );

      // Create an initial active database file with sample content
      activeDbFile = File(p.join(tempDir.path, 'small_mall.db'));
      await activeDbFile.writeAsString('INITIAL_DATABASE_DATA_V1');
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('BackupFileInfo formatting formats bytes, KB, and MB correctly', () {
      final file = File('dummy.db');
      final now = DateTime(2026, 10, 19, 14, 30);

      final small = BackupFileInfo(
        file: file,
        fileName: 'small.db',
        createdAt: now,
        sizeInBytes: 500,
      );
      expect(small.formattedSize, '500 B');

      final medium = BackupFileInfo(
        file: file,
        fileName: 'medium.db',
        createdAt: now,
        sizeInBytes: 15360, // 15 KB
      );
      expect(medium.formattedSize, '15.0 KB');

      final large = BackupFileInfo(
        file: file,
        fileName: 'large.db',
        createdAt: now,
        sizeInBytes: 5242880, // 5 MB
      );
      expect(large.formattedSize, '5.00 MB');
      expect(small.formattedDate.isNotEmpty, true);
    });

    test('DatabaseStats formats size correctly', () {
      final stats = DatabaseStats(
        sizeInBytes: 2048,
        totalProducts: 10,
        totalInvoices: 5,
        totalCustomers: 2,
        totalExpenses: 3,
        totalTreasuryTransactions: 4,
      );

      expect(stats.formattedSize, '2.0 KB');
      expect(stats.totalProducts, 10);
      expect(stats.totalInvoices, 5);
      expect(stats.totalCustomers, 2);
      expect(stats.totalExpenses, 3);
      expect(stats.totalTreasuryTransactions, 4);
    });

    test('createBackup creates timestamped backup file in backups directory', () async {
      final backup = await backupService.createBackup();

      expect(await backup.file.exists(), true);
      expect(backup.fileName.startsWith('small_mall_backup_'), true);
      expect(backup.fileName.endsWith('.db'), true);
      expect(backup.sizeInBytes, await activeDbFile.length());

      final content = await backup.file.readAsString();
      expect(content, 'INITIAL_DATABASE_DATA_V1');
    });

    test('createBackup with customLabel sanitizes and includes label', () async {
      final backup = await backupService.createBackup(
        customLabel: 'weekly audit #1',
      );

      expect(backup.fileName.contains('weekly_audit__1'), true);
      expect(await backup.file.exists(), true);
    });

    test('listBackups lists all backups sorted newest first', () async {
      final backup1 = await backupService.createBackup(customLabel: 'first');
      final backup2 = await backupService.createBackup(customLabel: 'second');
      await backup1.file.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));
      await backup2.file.setLastModified(DateTime.now());

      final list = await backupService.listBackups();
      expect(list.length, 2);
      expect(list.first.fileName, backup2.fileName);
      expect(list.last.fileName, backup1.fileName);
    });

    test('restoreBackup creates pre-restore safety checkpoint and restores chosen backup', () async {
      // 1. Create a baseline backup of V1
      final backupV1 = await backupService.createBackup(customLabel: 'v1');

      // 2. Mutate active database file to V2
      await activeDbFile.writeAsString('MODIFIED_ACTIVE_DATA_V2');
      expect(await activeDbFile.readAsString(), 'MODIFIED_ACTIVE_DATA_V2');

      // 3. Restore V1
      await backupService.restoreBackup(backupV1.file);

      // 4. Verify active file reverted to V1
      expect(await activeDbFile.readAsString(), 'INITIAL_DATABASE_DATA_V1');

      // 5. Verify pre-restore safety checkpoint was created
      final allFiles = await backupService.listBackups();
      final hasSafetyPoint = allFiles.any((f) => f.fileName.startsWith('pre_restore_safety_'));
      expect(hasSafetyPoint, true);
    });

    test('deleteBackup removes the backup file', () async {
      final backup = await backupService.createBackup(customLabel: 'to_delete');
      expect(await backup.file.exists(), true);

      await backupService.deleteBackup(backup.file);
      expect(await backup.file.exists(), false);

      final list = await backupService.listBackups();
      expect(list.any((f) => f.fileName == backup.fileName), false);
    });

    test('getDatabaseStats reads live database tables and file size', () async {
      final stats = await backupService.getDatabaseStats();
      expect(stats.sizeInBytes, greaterThan(0));
      expect(stats.totalProducts, 0);
      expect(stats.totalInvoices, 0);
    });
  });
}
