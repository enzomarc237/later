import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libsql_client/libsql_client.dart';
import 'package:uuid/uuid.dart';

// Assuming models.dart is in ../models/
// If this path is incorrect, it will need to be adjusted.
import '../models/models.dart';

// --- Provider Definition ---

// TODO: Replace with your Turso database URL
const _dbUrl = 'libsql://your-database.turso.io';
// TODO: Replace with your Turso auth token (if required by your setup)
const _authToken = 'YOUR_AUTH_TOKEN';

final libsqlClientProvider = Provider<LibsqlClient>((ref) {
  return LibsqlClient.create(url: _dbUrl, authToken: _authToken);
});

final preferencesRepositoryProvider = FutureProvider<PreferencesRepository>((ref) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final dbClient = ref.watch(libsqlClientProvider);
  final repository = PreferencesRepository(sharedPreferences, dbClient);
  await repository._createTablesIfNeeded();
  return repository;
});

// --- PreferencesRepository Class ---

class PreferencesRepository {
  final SharedPreferences _prefs;
  final LibsqlClient _db;
  final Uuid _uuid = const Uuid();

  PreferencesRepository(this._prefs, this._db);

  // --- Table Names ---
  static const String _categoriesTable = 'categories';
  static const String _urlItemsTable = 'url_items';

  // --- Initialization ---
  Future<void> _createTablesIfNeeded() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_categoriesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_urlItemsTable (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT,
        description TEXT,
        categoryId TEXT,
        tags TEXT,
        notes TEXT,
        isFavorite INTEGER DEFAULT 0,
        status TEXT,
        lastChecked TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        metadata TEXT,
        FOREIGN KEY (categoryId) REFERENCES $_categoriesTable(id) ON DELETE SET NULL
      )
    ''');
    // Consider ON DELETE CASCADE if categories should delete their items.
    // For now, SET NULL to allow items to exist without a category.
  }

  // --- Settings (using SharedPreferences) ---
  Settings getSettings() {
    final themeModeName = _prefs.getString('themeMode') ?? 'system';
    final themeOption = ThemeOption.values.firstWhere(
      (e) => e.name == themeModeName,
      orElse: () => ThemeOption.system,
    );
    final dataFolderPath = _prefs.getString('dataFolderPath') ?? '';
    final hideMenuBar = _prefs.getBool('hideMenuBar') ?? false;
    final openInBrowser = _prefs.getBool('openInBrowser') ?? false;

    return Settings(
      themeOption: themeOption,
      dataFolderPath: dataFolderPath,
      hideMenuBar: hideMenuBar,
      openInBrowser: openInBrowser,
    );
  }

  Future<void> saveSettings(Settings settings) async {
    await _prefs.setString('themeMode', settings.themeOption.name);
    await _prefs.setString('dataFolderPath', settings.dataFolderPath);
    await _prefs.setBool('hideMenuBar', settings.hideMenuBar);
    await _prefs.setBool('openInBrowser', settings.openInBrowser);
  }

  String get appVersion => _prefs.getString('appVersion') ?? '0.0.0';
  Future<void> setAppVersion(String version) => _prefs.setString('appVersion', version);

  String get currentDirectory => _prefs.getString('currentDirectory') ?? '';
  Future<void> setCurrentDirectory(String directory) => _prefs.setString('currentDirectory', directory);

  // --- Categories (using Turso) ---
  Future<List<Category>> getCategories() async {
    final resultSet = await _db.execute('SELECT * FROM $_categoriesTable');
    return resultSet.rows.map((row) => _categoryFromRow(row)).toList();
  }

  Future<void> saveCategories(List<Category> categories) async {
    // Using a transaction for atomicity
    final tx = await _db.transaction();
    try {
      for (final category in categories) {
        final categoryMap = _categoryToMap(category);
        // Using placeholder for UPSERT since LibSQL syntax might vary or not directly support it.
        // This is a common pattern: try to update, if not found, insert.
        // For robust UPSERT, specific database syntax is needed.
        // Example: INSERT INTO ... ON CONFLICT(id) DO UPDATE SET ...
        // For simplicity, we'll do a delete then insert for now, or rely on INSERT OR REPLACE if available.
        // LibSQL supports INSERT OR REPLACE
        await tx.execute(
          'INSERT OR REPLACE INTO $_categoriesTable (id, name, icon, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)',
          [categoryMap['id'], categoryMap['name'], categoryMap['icon'], categoryMap['createdAt'], categoryMap['updatedAt']],
        );
      }
      await tx.commit();
    } catch (e) {
      await tx.rollback();
      rethrow;
    }
  }

  Future<void> addCategory(Category category) async {
    final categoryMap = _categoryToMap(category);
    await _db.execute(
      'INSERT INTO $_categoriesTable (id, name, icon, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)',
      [categoryMap['id'], categoryMap['name'], categoryMap['icon'], categoryMap['createdAt'], categoryMap['updatedAt']],
    );
  }

  Future<void> updateCategory(Category category) async {
    final categoryMap = _categoryToMap(category);
    await _db.execute(
      'UPDATE $_categoriesTable SET name = ?, icon = ?, updatedAt = ? WHERE id = ?',
      [categoryMap['name'], categoryMap['icon'], categoryMap['updatedAt'], categoryMap['id']],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.execute('DELETE FROM $_categoriesTable WHERE id = ?', [categoryId]);
    // Also consider what to do with items in this category.
    // Current schema sets categoryId to NULL for items if category is deleted.
  }


  // --- URL Items (using Turso) ---
  Future<List<UrlItem>> getUrls() async {
    final resultSet = await _db.execute('SELECT * FROM $_urlItemsTable');
    return resultSet.rows.map((row) => _urlItemFromRow(row)).toList();
  }

  Future<List<UrlItem>> getUrlsByCategory(String categoryId) async {
    final resultSet = await _db.execute(
      'SELECT * FROM $_urlItemsTable WHERE categoryId = ?',
      [categoryId],
    );
    return resultSet.rows.map((row) => _urlItemFromRow(row)).toList();
  }

  Future<void> saveUrls(List<UrlItem> urlItems) async {
    final tx = await _db.transaction();
    try {
      for (final urlItem in urlItems) {
        final urlItemMap = _urlItemToMap(urlItem);
        // Using INSERT OR REPLACE for simplicity, assuming IDs are managed correctly.
        await tx.execute(
          '''
          INSERT OR REPLACE INTO $_urlItemsTable
            (id, url, title, description, categoryId, tags, notes, isFavorite, status, lastChecked, createdAt, updatedAt, metadata)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            urlItemMap['id'],
            urlItemMap['url'],
            urlItemMap['title'],
            urlItemMap['description'],
            urlItemMap['categoryId'],
            urlItemMap['tags'],
            urlItemMap['notes'],
            urlItemMap['isFavorite'],
            urlItemMap['status'],
            urlItemMap['lastChecked'],
            urlItemMap['createdAt'],
            urlItemMap['updatedAt'],
            urlItemMap['metadata'],
          ],
        );
      }
      await tx.commit();
    } catch (e) {
      await tx.rollback();
      rethrow;
    }
  }

  Future<void> addUrlItem(UrlItem urlItem) async {
    final urlItemMap = _urlItemToMap(urlItem);
    await _db.execute(
      '''
      INSERT INTO $_urlItemsTable
        (id, url, title, description, categoryId, tags, notes, isFavorite, status, lastChecked, createdAt, updatedAt, metadata)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        urlItemMap['id'],
        urlItemMap['url'],
        urlItemMap['title'],
        urlItemMap['description'],
        urlItemMap['categoryId'],
        urlItemMap['tags'],
        urlItemMap['notes'],
        urlItemMap['isFavorite'],
        urlItemMap['status'],
        urlItemMap['lastChecked'],
        urlItemMap['createdAt'],
        urlItemMap['updatedAt'],
        urlItemMap['metadata'],
      ],
    );
  }

  Future<void> updateUrlItem(UrlItem urlItem) async {
    final urlItemMap = _urlItemToMap(urlItem);
    await _db.execute(
      '''
      UPDATE $_urlItemsTable SET
        url = ?, title = ?, description = ?, categoryId = ?, tags = ?, notes = ?,
        isFavorite = ?, status = ?, lastChecked = ?, updatedAt = ?, metadata = ?
      WHERE id = ?
      ''',
      [
        urlItemMap['url'],
        urlItemMap['title'],
        urlItemMap['description'],
        urlItemMap['categoryId'],
        urlItemMap['tags'],
        urlItemMap['notes'],
        urlItemMap['isFavorite'],
        urlItemMap['status'],
        urlItemMap['lastChecked'],
        urlItemMap['updatedAt'],
        urlItemMap['metadata'],
        urlItemMap['id'],
      ],
    );
  }

  Future<void> deleteUrlItem(String urlItemId) async {
    await _db.execute('DELETE FROM $_urlItemsTable WHERE id = ?', [urlItemId]);
  }


  // --- Helper Methods for Data Conversion ---

  Category _categoryFromRow(Row row) {
    // The row from libsql_client is a Map<String, Value>
    // Value has types like Text, Integer, Blob, Null, Real
    // We need to cast them appropriately.
    return Category(
      id: row['id']!.text!,
      name: row['name']!.text!,
      icon: row['icon']?.text, // Handle null icon
      createdAt: DateTime.tryParse(row['createdAt']?.text ?? ''),
      updatedAt: DateTime.tryParse(row['updatedAt']?.text ?? ''),
    );
  }

  Map<String, dynamic> _categoryToMap(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'icon': category.icon,
      'createdAt': category.createdAt?.toIso8601String(),
      'updatedAt': category.updatedAt?.toIso8601String(),
    };
  }

  UrlItem _urlItemFromRow(Row row) {
    List<String> tags = [];
    final tagsString = row['tags']?.text;
    if (tagsString != null && tagsString.isNotEmpty) {
      try {
        tags = List<String>.from(jsonDecode(tagsString));
      } catch (e) {
        if (kDebugMode) {
          print("Error decoding tags: $e");
        }
        // Fallback or error handling for malformed JSON
      }
    }

    Map<String, dynamic> metadata = {};
    final metadataString = row['metadata']?.text;
    if (metadataString != null && metadataString.isNotEmpty) {
      try {
        metadata = Map<String, dynamic>.from(jsonDecode(metadataString));
      } catch (e) {
        if (kDebugMode) {
          print("Error decoding metadata: $e");
        }
        // Fallback or error handling
      }
    }

    String? categoryId = row['categoryId']?.text;
    if (categoryId != null && categoryId.isEmpty) {
        categoryId = null;
    }


    return UrlItem(
      id: row['id']!.text!,
      url: row['url']!.text!,
      title: row['title']?.text,
      description: row['description']?.text,
      categoryId: categoryId,
      tags: tags,
      notes: row['notes']?.text,
      isFavorite: row['isFavorite']?.integer == 1,
      status: UrlStatus.values.firstWhere(
        (e) => e.name == row['status']?.text,
        orElse: () => UrlStatus.unknown,
      ),
      lastChecked: DateTime.tryParse(row['lastChecked']?.text ?? ''),
      createdAt: DateTime.tryParse(row['createdAt']?.text ?? ''),
      updatedAt: DateTime.tryParse(row['updatedAt']?.text ?? ''),
      metadata: metadata,
    );
  }

  Map<String, dynamic> _urlItemToMap(UrlItem urlItem) {
    return {
      'id': urlItem.id,
      'url': urlItem.url,
      'title': urlItem.title,
      'description': urlItem.description,
      'categoryId': urlItem.categoryId,
      'tags': jsonEncode(urlItem.tags),
      'notes': urlItem.notes,
      'isFavorite': urlItem.isFavorite ? 1 : 0,
      'status': urlItem.status.name,
      'lastChecked': urlItem.lastChecked?.toIso8601String(),
      'createdAt': urlItem.createdAt?.toIso8601String(),
      'updatedAt': urlItem.updatedAt?.toIso8601String(),
      'metadata': jsonEncode(urlItem.metadata),
    };
  }
}
