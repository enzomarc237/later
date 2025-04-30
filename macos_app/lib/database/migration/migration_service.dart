import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database.dart';
import '../database_provider.dart';
import '../../utils/file_storage_service.dart';
import 'database_migrator.dart';

/// Service for managing database migration.
class MigrationService {
  /// The database to migrate data to.
  final LaterDatabase _database;
  
  /// The file storage service to read data from.
  final FileStorageService _fileStorage;
  
  /// The shared preferences instance for storing migration status.
  final SharedPreferences _preferences;
  
  /// Key for storing migration status in preferences.
  static const String _migrationCompletedKey = 'database_migration_completed';
  
  /// Creates a new migration service.
  MigrationService(this._database, this._fileStorage, this._preferences);
  
  /// Checks if migration is needed.
  /// 
  /// Migration is needed if it hasn't been completed yet and there is data to migrate.
  Future<bool> isMigrationNeeded() async {
    // Check if migration has already been completed
    final migrationCompleted = _preferences.getBool(_migrationCompletedKey) ?? false;
    if (migrationCompleted) {
      return false;
    }
    
    // Check if there is data to migrate
    try {
      final hasCategories = await _fileStorage.fileExists('categories.json');
      final hasUrls = await _fileStorage.fileExists('urls.json');
      
      // Migration is needed if there are categories or URLs to migrate
      return hasCategories || hasUrls;
    } catch (e) {
      debugPrint('Error checking if migration is needed: $e');
      return false;
    }
  }
  
  /// Performs the migration from file-based storage to the database.
  /// 
  /// Parameters:
  /// - [onProgress]: Optional callback for migration progress updates.
  /// 
  /// Returns a [MigrationResult] indicating the success of the migration.
  Future<MigrationResult> performMigration({
    MigrationProgressCallback? onProgress,
  }) async {
    final migrator = DatabaseMigrator(_fileStorage, _database, onProgress: onProgress);
    
    try {
      final result = await migrator.migrateData();
      
      // If migration was successful, mark it as completed
      if (result.isSuccessful) {
        await _preferences.setBool(_migrationCompletedKey, true);
      }
      
      return result;
    } catch (e) {
      debugPrint('Error performing migration: $e');
      return MigrationResult();
    }
  }
  
  /// Rolls back the migration by clearing the database.
  Future<bool> rollbackMigration() async {
    final migrator = DatabaseMigrator(_fileStorage, _database);
    
    try {
      final result = await migrator.rollbackMigration();
      
      // If rollback was successful, mark migration as not completed
      if (result) {
        await _preferences.setBool(_migrationCompletedKey, false);
      }
      
      return result;
    } catch (e) {
      debugPrint('Error rolling back migration: $e');
      return false;
    }
  }
  
  /// Marks the migration as completed without actually performing it.
  /// 
  /// This is useful for testing or when migration is not needed.
  Future<void> markMigrationAsCompleted() async {
    await _preferences.setBool(_migrationCompletedKey, true);
  }
  
  /// Checks if migration has been completed.
  bool isMigrationCompleted() {
    return _preferences.getBool(_migrationCompletedKey) ?? false;
  }
}