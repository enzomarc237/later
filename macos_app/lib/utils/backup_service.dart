import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'file_storage_service.dart';

/// A service for creating and managing backups of user data.
class BackupService {
  /// The file storage service used to read and write data.
  final FileStorageService _fileStorage;

  /// The maximum number of backups to keep.
  final int maxBackups;

  /// Creates a new [BackupService] with the specified file storage service.
  BackupService({
    required FileStorageService fileStorage,
    this.maxBackups = 10,
  }) : _fileStorage = fileStorage;

  /// Gets the backup directory.
  Future<Directory> get _backupDirectory async {
    final baseDir = _fileStorage.basePath.isEmpty ? (await getApplicationDocumentsDirectory()).path : _fileStorage.basePath;

    final backupDir = Directory('$baseDir/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  /// Creates a backup of the user's data.
  Future<String?> createBackup({
    required List<Category> categories,
    required List<UrlItem> urls,
    required Settings settings,
    String? backupName,
  }) async {
    try {
      final timestamp = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(timestamp);
      final backupFileName = backupName ?? 'backup_$formattedDate.json';

      final backupDir = await _backupDirectory;
      final backupFile = File('${backupDir.path}/$backupFileName');

      // Create backup data
      final backupData = {
        'timestamp': timestamp.toIso8601String(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'urls': urls.map((u) => u.toJson()).toList(),
        'settings': settings.toJson(),
      };

      // Write backup to file
      await backupFile.writeAsString(jsonEncode(backupData));

      // Clean up old backups if needed
      await _cleanupOldBackups();

      return backupFileName;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  /// Lists all available backups.
  Future<List<BackupInfo>> listBackups() async {
    try {
      final backupDir = await _backupDirectory;
      final files = await backupDir.list().toList();

      final backups = <BackupInfo>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;

            final timestamp = DateTime.parse(data['timestamp'] as String);
            final categoriesCount = (data['categories'] as List).length;
            final urlsCount = (data['urls'] as List).length;

            backups.add(BackupInfo(
              fileName: file.path.split('/').last,
              timestamp: timestamp,
              categoriesCount: categoriesCount,
              urlsCount: urlsCount,
            ));
          } catch (e) {
            debugPrint('Error parsing backup file ${file.path}: $e');
          }
        }
      }

      // Sort backups by timestamp (newest first)
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return backups;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// Restores data from a backup.
  Future<bool> restoreBackup(String backupFileName) async {
    try {
      final backupDir = await _backupDirectory;
      final backupFile = File('${backupDir.path}/$backupFileName');

      if (!await backupFile.exists()) {
        debugPrint('Backup file not found: $backupFileName');
        return false;
      }

      final content = await backupFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final categories = (data['categories'] as List).map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();

      final urls = (data['urls'] as List).map((json) => UrlItem.fromJson(json as Map<String, dynamic>)).toList();

      final settings = Settings.fromJson(data['settings'] as Map<String, dynamic>);

      // Write restored data to storage
      await _fileStorage.writeJsonListFile('categories.json', data['categories'] as List);
      await _fileStorage.writeJsonListFile('urls.json', data['urls'] as List);
      await _fileStorage.writeJsonFile('settings.json', data['settings'] as Map<String, dynamic>);

      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  /// Deletes a backup.
  Future<bool> deleteBackup(String backupFileName) async {
    try {
      final backupDir = await _backupDirectory;
      final backupFile = File('${backupDir.path}/$backupFileName');

      if (await backupFile.exists()) {
        await backupFile.delete();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Cleans up old backups, keeping only the most recent ones.
  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await listBackups();

      if (backups.length <= maxBackups) {
        return;
      }

      // Delete oldest backups
      final backupsToDelete = backups.sublist(maxBackups);

      for (final backup in backupsToDelete) {
        await deleteBackup(backup.fileName);
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
