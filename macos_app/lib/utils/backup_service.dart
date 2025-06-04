import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
// import 'file_storage_service.dart'; // Removed

/// A service for creating and managing backups of user data.
class BackupService {
  /// The maximum number of backups to keep.
  int maxBackups; // Made non-final to be updatable

  /// Creates a new [BackupService].
  BackupService({
    this.maxBackups = 10, // Default value
  });

  /// Gets the backup directory path.
  Future<String> get _backupDirectoryPath async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${documentsDir.path}/LaterBackups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  /// Creates a backup from the provided data.
  Future<String?> createBackup({
    required List<Category> categories,
    required List<UrlItem> urls,
    required Settings settings,
    String? backupName,
  }) async {
    try {
      final timestamp = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(timestamp);
      // Ensure backupName is a valid filename, if provided, otherwise generate one.
      final safeBackupName = backupName?.replaceAll(RegExp(r'[^\w.-]'), '_') ?? 'backup_$formattedDate';
      final backupFileName = safeBackupName.endsWith('.json') ? safeBackupName : '$safeBackupName.json';

      final backupDir = await _backupDirectoryPath;

      final exportData = ExportData(
        categories: categories,
        urls: urls,
        settings: settings, // Assuming ExportData includes settings or we adapt it
        version: '1.0.0', // Use app version or a backup version
        createdAt: timestamp,
      );

      final backupJson = jsonEncode(exportData.toJson());

      final backupFile = File('$backupDir/$backupFileName');
      final tempFile = File('$backupDir/$backupFileName.tmp');

      await tempFile.writeAsString(backupJson, flush: true);

      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await tempFile.rename(backupFile.path);

      await _cleanupOldBackups();

      debugPrint('Successfully created backup: $backupFileName');
      return backupFileName;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    try {
      final backupDir = await _backupDirectoryPath;
      final dir = Directory(backupDir);
      if (!await dir.exists()) {
        return [];
      }
      final files = await dir.list().toList();
      final backups = <BackupInfo>[];

      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.endsWith('.json')) {
          try {
            final content = await fileEntity.readAsString();
            // Attempt to decode to check if it's a valid JSON, and get timestamp if stored
            final data = jsonDecode(content) as Map<String, dynamic>;

            DateTime timestamp;
            // Check for 'createdAt' (from ExportData) or 'timestamp' (older format)
            if (data.containsKey('createdAt') && data['createdAt'] != null) {
              timestamp = DateTime.parse(data['createdAt'] as String);
            } else if (data.containsKey('timestamp') && data['timestamp'] != null) {
               timestamp = DateTime.parse(data['timestamp'] as String);
            } else {
              // Fallback to file modification time if no timestamp in JSON
              timestamp = await fileEntity.lastModified();
            }

            // Try to get counts, default to 0 if not present
            final categoriesCount = (data['categories'] as List?)?.length ?? 0;
            final urlsCount = (data['urls'] as List?)?.length ?? 0;

            backups.add(BackupInfo(
              fileName: fileEntity.path.split('/').last,
              timestamp: timestamp,
              categoriesCount: categoriesCount,
              urlsCount: urlsCount,
            ));
          } catch (e) {
            debugPrint('Error parsing backup file ${fileEntity.path}: $e');
            // Could add as a backup with error state or skip
          }
        }
      }
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return backups;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  Future<ExportData?> restoreBackup(String backupFileName) async {
    try {
      final backupDir = await _backupDirectoryPath;
      final backupFile = File('$backupDir/$backupFileName');

      if (!await backupFile.exists()) {
        debugPrint('Backup file not found: $backupFileName');
        return null;
      }

      final content = await backupFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Assuming ExportData.fromJson handles validation
      final exportData = ExportData.fromJson(data);

      debugPrint('Successfully read backup for restore: $backupFileName');
      return exportData;
    } catch (e) {
      debugPrint('Error restoring backup $backupFileName: $e');
      return null;
    }
  }

  Future<bool> deleteBackup(String backupFileName) async {
    try {
      final backupDir = await _backupDirectoryPath;
      final backupFile = File('$backupDir/$backupFileName');

      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('Successfully deleted backup: $backupFileName');
        return true;
      }
      debugPrint('Backup file not found for deletion: $backupFileName');
      return false;
    } catch (e) {
      debugPrint('Error deleting backup $backupFileName: $e');
      return false;
    }
  }

  Future<void> _cleanupOldBackups() async {
    if (maxBackups <= 0) return; // maxBackups = 0 or less means keep all

    try {
      var backups = await listBackups(); // Already sorted newest first

      if (backups.length <= maxBackups) {
        return;
      }

      // Delete oldest backups that exceed the maxBackups limit
      final backupsToDelete = backups.sublist(maxBackups);

      for (final backupInfo in backupsToDelete) {
        await deleteBackup(backupInfo.fileName);
         debugPrint('Cleaned up old backup: ${backupInfo.fileName}');
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }
}

/// Information about a backup.
class BackupInfo {
  /// The file name of the backup.
  final String fileName;

  /// The timestamp when the backup was created.
  final DateTime timestamp;

  /// The number of categories in the backup.
  final int categoriesCount;

  /// The number of URLs in the backup.
  final int urlsCount;

  /// Creates a new [BackupInfo].
  BackupInfo({
    required this.fileName,
    required this.timestamp,
    required this.categoriesCount,
    required this.urlsCount,
  });
}
