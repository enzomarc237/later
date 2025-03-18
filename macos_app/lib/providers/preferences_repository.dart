import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  bool get _useFileStorage => _fileStorage != null && _fileStorage!.basePath.isNotEmpty;

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
    // If file storage is enabled, try to read from files first
    if (_useFileStorage) {
      // Check if migration is needed
      if (!_migrationPerformed && await _shouldMigrateData()) {
        await _migrateDataToFiles();
      }

      final categoriesJson = await _fileStorage!.readJsonListFile('categories.json');
      if (categoriesJson.isNotEmpty) {
        return categoriesJson.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
      }
    }

    // Fall back to SharedPreferences
    final categoriesJson = _prefs.getStringList('categories') ?? [];
    return categoriesJson.map((json) => Category.fromJson(jsonDecode(json) as Map<String, dynamic>)).toList();
  }

  Future<void> saveCategories(List<Category> categories) async {
    // Save to file if file storage is enabled
    if (_useFileStorage) {
      final categoriesJson = categories.map((category) => category.toJson()).toList();
      await _fileStorage!.writeJsonListFile('categories.json', categoriesJson);
    }

    // Always save to SharedPreferences as a fallback
    final categoriesJsonStrings = categories.map((category) => jsonEncode(category.toJson())).toList();
    await _prefs.setStringList('categories', categoriesJsonStrings);
  }

  // URLs
  Future<List<UrlItem>> getUrls() async {
    // If file storage is enabled, try to read from files first
    if (_useFileStorage) {
      // Check if migration is needed
      if (!_migrationPerformed && await _shouldMigrateData()) {
        await _migrateDataToFiles();
      }

      final urlsJson = await _fileStorage!.readJsonListFile('urls.json');
      if (urlsJson.isNotEmpty) {
        return urlsJson.map((json) => UrlItem.fromJson(json as Map<String, dynamic>)).toList();
      }
    }

    // Fall back to SharedPreferences
    final urlsJson = _prefs.getStringList('urls') ?? [];
    return urlsJson.map((json) => UrlItem.fromJson(jsonDecode(json) as Map<String, dynamic>)).toList();
  }

  Future<void> saveUrls(List<UrlItem> urls) async {
    // Save to file if file storage is enabled
    if (_useFileStorage) {
      final urlsJson = urls.map((url) => url.toJson()).toList();
      await _fileStorage!.writeJsonListFile('urls.json', urlsJson);
    }

    // Always save to SharedPreferences as a fallback
    final urlsJsonStrings = urls.map((url) => jsonEncode(url.toJson())).toList();
    await _prefs.setStringList('urls', urlsJsonStrings);
  }

  // Settings
  Future<Settings> getSettings() async {
    // If file storage is enabled, try to read from files first
    if (_useFileStorage) {
      // Check if migration is needed
      if (!_migrationPerformed && await _shouldMigrateData()) {
        await _migrateDataToFiles();
      }

      final settingsJson = await _fileStorage!.readJsonFile('settings.json');
      if (settingsJson != null) {
        return Settings.fromJson(settingsJson);
      }
    }

    // Fall back to SharedPreferences
    final settingsJson = _prefs.getString('settings');
    if (settingsJson == null) {
      return Settings();
    }
    return Settings.fromJson(jsonDecode(settingsJson) as Map<String, dynamic>);
  }

  Future<void> saveSettings(Settings settings) async {
    // Save to file if file storage is enabled
    if (_useFileStorage) {
      await _fileStorage!.writeJsonFile('settings.json', settings.toJson());
    }

    // Always save to SharedPreferences as a fallback
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // Clear all data
  Future<void> clearAllData() async {
    // Clear data from files if file storage is enabled
    if (_useFileStorage) {
      await _fileStorage!.deleteFile('categories.json');
      await _fileStorage!.deleteFile('urls.json');
      // Don't clear settings or app version
    }

    // Clear data from SharedPreferences
    await _prefs.remove('categories');
    await _prefs.remove('urls');
    // Don't clear settings or app version
  }

  // Check if data migration is needed
  Future<bool> _shouldMigrateData() async {
    if (!_useFileStorage) return false;

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

    try {
      debugPrint('Migrating data to files...');

      // Migrate categories
      final categories = await getCategories();
      if (categories.isNotEmpty) {
        final categoriesJson = categories.map((category) => category.toJson()).toList();
        await _fileStorage!.writeJsonListFile('categories.json', categoriesJson);
      }

      // Migrate URLs
      final urls = await getUrls();
      if (urls.isNotEmpty) {
        final urlsJson = urls.map((url) => url.toJson()).toList();
        await _fileStorage!.writeJsonListFile('urls.json', urlsJson);
      }

      // Migrate settings
      final settings = await getSettings();
      await _fileStorage!.writeJsonFile('settings.json', settings.toJson());

      _migrationPerformed = true;
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
