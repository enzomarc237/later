import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'providers.dart';

class PreferencesRepository {
  final DatabaseService _databaseService;

  PreferencesRepository(this._databaseService);

  // App version
  String get appVersion => '?'; // Not stored in DB currently

  // Current directory
  Future<void> setCurrentDirectory(String currentDirectory) async {
    // Not stored in DB currently
  }

  String get currentDirectory {
    return '.'; // Not stored in DB currently
  }

  // Categories
  Future<List<Category>> getCategories() async {
    try {
      return await _databaseService.getCategories();
    } catch (e) {
      debugPrint('Error getting categories: $e');
      // Return empty list as a last resort
      return [];
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    try {
      for (final category in categories) {
        await _databaseService.saveCategory(category);
      }
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _databaseService.deleteCategory(categoryId);
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  // URLs
  Future<List<UrlItem>> getUrls() async {
    try {
      return await _databaseService.getUrlItems();
    } catch (e) {
      debugPrint('Error getting URLs: $e');
      return [];
    }
  }

  Future<void> saveUrls(List<UrlItem> urls) async {
    try {
      for (final urlItem in urls) {
        await _databaseService.saveUrlItem(urlItem);
      }
    } catch (e) {
      debugPrint('Error saving URLs: $e');
    }
  }

  Future<void> deleteUrl(String urlId) async {
    try {
      await _databaseService.deleteUrlItem(urlId);
    } catch (e) {
      debugPrint('Error deleting URL: $e');
    }
  }

  // Settings
  Future<Settings> getSettings() async {
    try {
      return await _databaseService.getSettings();
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return Settings();
    }
  }

  Future<void> saveSettings(Settings settings) async {
    try {
      await _databaseService.saveSettings(settings);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      await _databaseService.clearAllData();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) {
    final databaseService = ref.read(databaseServiceProvider);
    return PreferencesRepository(databaseService);
  },
);

