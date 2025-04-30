import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/category.dart' as model_category;
import '../../models/url_item.dart' as model_url;
import '../../utils/file_storage_service.dart';
import '../database.dart';

/// Result of a migration operation.
class MigrationResult {
  /// Total number of categories to migrate.
  int totalCategories = 0;
  
  /// Number of categories successfully migrated.
  int migratedCategories = 0;
  
  /// Total number of URLs to migrate.
  int totalUrls = 0;
  
  /// Number of URLs successfully migrated.
  int migratedUrls = 0;
  
  /// Whether the migration was successful.
  bool get isSuccessful => 
      totalCategories == migratedCategories && 
      totalUrls == migratedUrls;
  
  /// Percentage of categories migrated.
  double get categoryPercentage => 
      totalCategories > 0 ? (migratedCategories / totalCategories) * 100 : 0;
  
  /// Percentage of URLs migrated.
  double get urlPercentage => 
      totalUrls > 0 ? (migratedUrls / totalUrls) * 100 : 0;
  
  /// Overall percentage of migration completed.
  double get overallPercentage => 
      (categoryPercentage + urlPercentage) / 2;
  
  @override
  String toString() {
    return 'MigrationResult(categories: $migratedCategories/$totalCategories, '
        'urls: $migratedUrls/$totalUrls, '
        'success: $isSuccessful)';
  }
}

/// Callback for migration progress updates.
typedef MigrationProgressCallback = void Function(MigrationResult progress);

/// Class responsible for migrating data from file-based storage to the database.
class DatabaseMigrator {
  /// The file storage service to read data from.
  final FileStorageService _fileStorage;
  
  /// The database to migrate data to.
  final LaterDatabase _database;
  
  /// Callback for migration progress updates.
  final MigrationProgressCallback? _onProgress;
  
  /// Creates a new database migrator.
  /// 
  /// Parameters:
  /// - [fileStorage]: The file storage service to read data from.
  /// - [database]: The database to migrate data to.
  /// - [onProgress]: Optional callback for migration progress updates.
  DatabaseMigrator(this._fileStorage, this._database, {
    MigrationProgressCallback? onProgress,
  }) : _onProgress = onProgress;
  
  /// Migrates data from file-based storage to the database.
  /// 
  /// Returns a [MigrationResult] indicating the success of the migration.
  Future<MigrationResult> migrateData() async {
    final migrationResult = MigrationResult();
    
    try {
      // Step 1: Migrate categories
      final categories = await _fileStorage.readJsonListFile('categories.json');
      migrationResult.totalCategories = categories.length;
      
      // Report initial progress
      _reportProgress(migrationResult);
      
      for (final categoryJson in categories) {
        try {
          final category = model_category.Category.fromJson(categoryJson);
          await _database.insertCategory(CategoriesCompanion(
            uuid: Value(category.id),
            name: Value(category.name),
            iconName: Value(category.iconName),
            createdAt: Value(category.createdAt),
            updatedAt: Value(category.updatedAt),
            isDeleted: const Value(false),
          ));
          migrationResult.migratedCategories++;
          
          // Report progress after each category
          _reportProgress(migrationResult);
        } catch (e) {
          debugPrint('Error migrating category: $e');
          // Continue with next category
        }
      }
      
      // Step 2: Migrate URLs
      final urls = await _fileStorage.readJsonListFile('urls.json');
      migrationResult.totalUrls = urls.length;
      
      // Report progress after categories are done
      _reportProgress(migrationResult);
      
      for (final urlJson in urls) {
        try {
          final url = model_url.UrlItem.fromJson(urlJson);
          
          // Convert metadata to JSON string
          String? metadataJson;
          if (url.metadata != null) {
            metadataJson = url.metadata.toString();
          }
          
          await _database.insertUrl(UrlItemsCompanion(
            uuid: Value(url.id),
            url: Value(url.url),
            title: Value(url.title),
            description: Value(url.description),
            categoryId: Value(url.categoryId),
            createdAt: Value(url.createdAt),
            updatedAt: Value(url.updatedAt),
            metadata: Value(metadataJson),
            status: Value(url.status),
            lastChecked: Value(url.lastChecked),
            isDeleted: const Value(false),
          ));
          migrationResult.migratedUrls++;
          
          // Report progress after each URL
          _reportProgress(migrationResult);
        } catch (e) {
          debugPrint('Error migrating URL: $e');
          // Continue with next URL
        }
      }
      
      // Step 3: Verify migration
      final verificationResult = await _verifyMigration(
        migrationResult.totalCategories, 
        migrationResult.totalUrls
      );
      
      if (!verificationResult) {
        debugPrint('Migration verification failed');
        // If verification fails, we still return the current progress
        // The caller can decide what to do based on the result
      }
      
      return migrationResult;
    } catch (e) {
      debugPrint('Error during migration: $e');
      return migrationResult;
    }
  }
  
  /// Verifies that the migration was successful by checking counts.
  Future<bool> _verifyMigration(int expectedCategories, int expectedUrls) async {
    try {
      // Count categories
      final categoryCount = await _database.customSelect(
        'SELECT COUNT(*) as count FROM categories WHERE is_deleted = 0',
      ).getSingle().then((row) => row.read<int>('count'));
      
      // Count URLs
      final urlCount = await _database.customSelect(
        'SELECT COUNT(*) as count FROM url_items WHERE is_deleted = 0',
      ).getSingle().then((row) => row.read<int>('count'));
      
      // Verify counts match expected values
      return categoryCount == expectedCategories && urlCount == expectedUrls;
    } catch (e) {
      debugPrint('Error verifying migration: $e');
      return false;
    }
  }
  
  /// Reports migration progress through the callback if provided.
  void _reportProgress(MigrationResult progress) {
    if (_onProgress != null) {
      _onProgress!(progress);
    }
  }
  
  /// Rolls back the migration by clearing the database.
  Future<bool> rollbackMigration() async {
    try {
      // Delete all URLs
      await _database.customStatement('DELETE FROM url_items');
      
      // Delete all categories
      await _database.customStatement('DELETE FROM categories');
      
      return true;
    } catch (e) {
      debugPrint('Error rolling back migration: $e');
      return false;
    }
  }
}