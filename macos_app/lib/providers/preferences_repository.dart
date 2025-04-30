import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/file_storage_service.dart';
import 'providers.dart';

class PreferencesRepository {
  final SharedPreferences _prefs;
  final FileStorageService? _fileStorage;
  bool _migrationPerformed = false;

  PreferencesRepository(this._prefs, [this._fileStorage]);

  // Check if file storage is enabled
  bool get _useFileStorage =>
      _fileStorage != null && _fileStorage!.dataFolderPath.isNotEmpty;

  // App version
  String get appVersion => _prefs.getString('appVersion') ?? '?';

  // Current directory
  Future<void> setCurrentDirectory(String currentDirectory) async {
    await _prefs.setString('currentDirectory', currentDirectory);
  }

  String get currentDirectory {
    return _prefs.getString('currentDirectory') ?? '.';
  }

  // Categories
  Future<List<Category>> getCategories() async {
    try {
      // If file storage is enabled, try to read from files first
      if (_useFileStorage) {
        // Check if migration is needed
        if (!_migrationPerformed && await _shouldMigrateData()) {
          await _migrateDataToFiles();
        }

        try {
          final categoriesJson =
              await _fileStorage!.readJsonListFile('categories.json');
          if (categoriesJson.isNotEmpty) {
            return categoriesJson
                .map((json) => Category.fromJson(json))
                .toList();
          }
        } catch (e) {
          debugPrint('Error reading categories from file storage: $e');
          // Continue to fallback if file storage fails
        }
      }

      // Fall back to SharedPreferences
      final categoriesJson = _prefs.getStringList('categories') ?? [];
      return categoriesJson
          .map((json) =>
              Category.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting categories: $e');
      // Return empty list as a last resort
      return [];
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    try {
      // Save to file if file storage is enabled
      if (_useFileStorage) {
        try {
          final categoriesJson =
              categories.map((category) => category.toJson()).toList();
          await _fileStorage!
              .writeJsonListFile('categories.json', categoriesJson);
          debugPrint(
              'Successfully saved ${categories.length} categories to file storage');
        } catch (e) {
          debugPrint('Error saving categories to file storage: $e');
          // Continue to save to SharedPreferences even if file storage fails
        }
      }

      // Always save to SharedPreferences as a fallback
      final categoriesJsonStrings =
          categories.map((category) => jsonEncode(category.toJson())).toList();
      await _prefs.setStringList('categories', categoriesJsonStrings);
    } catch (e) {
      debugPrint('Error saving categories: $e');
      // Rethrow to notify caller of failure
      rethrow;
    }
  }

  // URLs
  Future<List<UrlItem>> getUrls() async {
    try {
      // If file storage is enabled, try to read from files first
      if (_useFileStorage) {
        // Check if migration is needed
        if (!_migrationPerformed && await _shouldMigrateData()) {
          await _migrateDataToFiles();
        }

        try {
          final urlsJson = await _fileStorage!.readJsonListFile('urls.json');
          if (urlsJson.isNotEmpty) {
            return urlsJson.map((json) => UrlItem.fromJson(json)).toList();
          }
        } catch (e) {
          debugPrint('Error reading URLs from file storage: $e');
          // Continue to fallback if file storage fails
        }
      }

      // Fall back to SharedPreferences
      final urlsJson = _prefs.getStringList('urls') ?? [];
      return urlsJson
          .map((json) =>
              UrlItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting URLs: $e');
      // Return empty list as a last resort
      return [];
    }
  }

  Future<void> saveUrls(List<UrlItem> urls) async {
    try {
      // Save to file if file storage is enabled
      if (_useFileStorage) {
        try {
          final urlsJson = urls.map((url) => url.toJson()).toList();
          await _fileStorage!.writeJsonListFile('urls.json', urlsJson);
          debugPrint('Successfully saved ${urls.length} URLs to file storage');
        } catch (e) {
          debugPrint('Error saving URLs to file storage: $e');
          // Continue to save to SharedPreferences even if file storage fails
        }
      }

      // Always save to SharedPreferences as a fallback
      final urlsJsonStrings =
          urls.map((url) => jsonEncode(url.toJson())).toList();
      await _prefs.setStringList('urls', urlsJsonStrings);
    } catch (e) {
      debugPrint('Error saving URLs: $e');
      // Rethrow to notify caller of failure
      rethrow;
    }
  }

  // Settings
  Future<Settings> getSettings() async {
    try {
      // If file storage is enabled, try to read from files first
      if (_useFileStorage) {
        // Check if migration is needed
        if (!_migrationPerformed && await _shouldMigrateData()) {
          await _migrateDataToFiles();
        }

        try {
          final settingsJson =
              await _fileStorage!.readJsonFile('settings.json');
          if (settingsJson != null) {
            return Settings.fromJson(settingsJson);
          }
        } catch (e) {
          debugPrint('Error reading settings from file storage: $e');
          // Continue to fallback if file storage fails
        }
      }

      // Fall back to SharedPreferences
      final settingsJson = _prefs.getString('settings');
      if (settingsJson == null) {
        return Settings();
      }
      return Settings.fromJson(
          jsonDecode(settingsJson) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting settings: $e');
      // Return default settings as a last resort
      return Settings();
    }
  }

  Future<void> saveSettings(Settings settings) async {
    try {
      // Save to file if file storage is enabled
      if (_useFileStorage) {
        try {
          await _fileStorage!.writeJsonFile('settings.json', settings.toJson());
          debugPrint('Successfully saved settings to file storage');
        } catch (e) {
          debugPrint('Error saving settings to file storage: $e');
          // Continue to save to SharedPreferences even if file storage fails
        }
      }

      // Always save to SharedPreferences as a fallback
      await _prefs.setString('settings', jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // Rethrow to notify caller of failure
      rethrow;
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      // Clear data from files if file storage is enabled
      if (_useFileStorage) {
        try {
          await _fileStorage!.deleteFile('categories.json');
          await _fileStorage!.deleteFile('urls.json');
          // Don't clear settings or app version
          debugPrint('Successfully cleared data from file storage');
        } catch (e) {
          debugPrint('Error clearing data from file storage: $e');
          // Continue to clear from SharedPreferences even if file storage fails
        }
      }

      // Clear data from SharedPreferences
      await _prefs.remove('categories');
      await _prefs.remove('urls');
      // Don't clear settings or app version

      // Create empty files to ensure clean state
      if (_useFileStorage) {
        try {
          await _fileStorage!.writeJsonListFile('categories.json', []);
          await _fileStorage!.writeJsonListFile('urls.json', []);
        } catch (e) {
          debugPrint('Error creating empty files after clearing data: $e');
        }
      }
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      // Rethrow to notify caller of failure
      rethrow;
    }
  }

  // Check if data migration is needed
  Future<bool> _shouldMigrateData() async {
    if (!_useFileStorage) {
      return false;
    }
    if (_migrationPerformed) {
      return false; // Skip if migration already performed
    }

    // Check if files already exist
    final categoriesExist = await _fileStorage!.fileExists('categories.json');
    final urlsExist = await _fileStorage!.fileExists('urls.json');
    final settingsExist = await _fileStorage!.fileExists('settings.json');

    // If any of the files don't exist, we need to migrate
    return !categoriesExist || !urlsExist || !settingsExist;
  }

  // Migrate data from SharedPreferences to files
  Future<void> _migrateDataToFiles() async {
    if (!_useFileStorage) return;

    // Set flag before migration to prevent recursive calls
    _migrationPerformed = true;

    try {
      debugPrint('Migrating data to files...');

      // Get data directly from SharedPreferences to avoid recursive calls
      final categoriesJson = _prefs.getStringList('categories') ?? [];
      final urlsJson = _prefs.getStringList('urls') ?? [];
      final settingsJson = _prefs.getString('settings');

      // Migrate categories
      if (categoriesJson.isNotEmpty) {
        final categories = categoriesJson
            .map((json) =>
                Category.fromJson(jsonDecode(json) as Map<String, dynamic>))
            .toList();
        final categoriesJsonList =
            categories.map((category) => category.toJson()).toList();
        await _fileStorage!
            .writeJsonListFile('categories.json', categoriesJsonList);
      } else {
        // Create empty file
        await _fileStorage!.writeJsonListFile('categories.json', []);
      }

      // Migrate URLs
      if (urlsJson.isNotEmpty) {
        final urls = urlsJson
            .map((json) =>
                UrlItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
            .toList();
        final urlsJsonList = urls.map((url) => url.toJson()).toList();
        await _fileStorage!.writeJsonListFile('urls.json', urlsJsonList);
      } else {
        // Create empty file
        await _fileStorage!.writeJsonListFile('urls.json', []);
      }

      // Migrate settings
      if (settingsJson != null) {
        final settings =
            Settings.fromJson(jsonDecode(settingsJson) as Map<String, dynamic>);
        await _fileStorage!.writeJsonFile('settings.json', settings.toJson());
      } else {
        // Create empty settings file
        await _fileStorage!.writeJsonFile('settings.json', Settings().toJson());
      }

      debugPrint('Data migration completed successfully.');
    } catch (e) {
      debugPrint('Error migrating data to files: $e');
    }
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final fileStorage = ref.watch(fileStorageServiceProvider);
    return PreferencesRepository(prefs, fileStorage);
  },
);
