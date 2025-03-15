import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'providers.dart';

class PreferencesRepository {
  final SharedPreferences _prefs;

  PreferencesRepository(this._prefs);

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
    final categoriesJson = _prefs.getStringList('categories') ?? [];
    return categoriesJson.map((json) => Category.fromJson(jsonDecode(json) as Map<String, dynamic>)).toList();
  }

  Future<void> saveCategories(List<Category> categories) async {
    final categoriesJson = categories.map((category) => jsonEncode(category.toJson())).toList();
    await _prefs.setStringList('categories', categoriesJson);
  }

  // URLs
  Future<List<UrlItem>> getUrls() async {
    final urlsJson = _prefs.getStringList('urls') ?? [];
    return urlsJson.map((json) => UrlItem.fromJson(jsonDecode(json) as Map<String, dynamic>)).toList();
  }

  Future<void> saveUrls(List<UrlItem> urls) async {
    final urlsJson = urls.map((url) => jsonEncode(url.toJson())).toList();
    await _prefs.setStringList('urls', urlsJson);
  }

  // Settings
  Future<Settings> getSettings() async {
    final settingsJson = _prefs.getString('settings');
    if (settingsJson == null) {
      return Settings();
    }
    return Settings.fromJson(jsonDecode(settingsJson) as Map<String, dynamic>);
  }

  Future<void> saveSettings(Settings settings) async {
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _prefs.remove('categories');
    await _prefs.remove('urls');
    // Don't clear settings or app version
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(
    ref.read(sharedPreferencesProvider),
  ),
);
