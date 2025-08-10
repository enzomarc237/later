import 'dart:io';

import 'package:libsql_dart/libsql_dart.dart';
import 'package:path_provider/path_provider.dart';

import '../models/category.dart';
import '../models/url_item.dart';

class DatabaseService {
  late LibsqlClient _client;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/later.db';

    _client = LibsqlClient(path);
    await _client.connect();

    await _client.execute("""
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    """);

    await _client.execute("""
      CREATE TABLE IF NOT EXISTS url_items (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        categoryId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      );
    """);

    _isInitialized = true;
  }

  Future<List<Category>> getCategories() async {
    final ResultSet rs = await _client.query("SELECT * FROM categories ORDER BY name ASC");
    return rs.rows.map((row) => Category.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> saveCategory(Category category) async {
    await _client.execute(
      "INSERT OR REPLACE INTO categories (id, name, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
      positional: [
        category.id,
        category.name,
        category.createdAt.toIso8601String(),
        category.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client.execute("DELETE FROM categories WHERE id = ?", positional: [categoryId]);
  }

  Future<List<UrlItem>> getUrlItems() async {
    final ResultSet rs = await _client.query("SELECT * FROM url_items ORDER BY createdAt DESC");
    return rs.rows.map((row) => UrlItem.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> saveUrlItem(UrlItem urlItem) async {
    await _client.execute(
      "INSERT OR REPLACE INTO url_items (id, url, title, description, categoryId, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?, ?)",
      positional: [
        urlItem.id,
        urlItem.url,
        urlItem.title,
        urlItem.description,
        urlItem.categoryId,
        urlItem.createdAt.toIso8601String(),
        urlItem.updatedAt.toIso8601String(),
      ],
    );
  }

  Future<void> deleteUrlItem(String urlItemId) async {
    await _client.execute("DELETE FROM url_items WHERE id = ?", positional: [urlItemId]);
  }

  Future<void> clearAllData() async {
    await _client.execute("DELETE FROM url_items");
    await _client.execute("DELETE FROM categories");
  }
  Future<Settings> getSettings() async {
    await initialize();
    final ResultSet rs = await _client.query('SELECT value FROM settings WHERE key = ?', positional: ['settings']);
    if (rs.rows.isEmpty) {
      return Settings();
    }
    try {
      final value = rs.rows.first['value'] as String?;
      if (value == null) {
        return Settings();
      }
      final Map<String, dynamic> json = jsonDecode(value);
      return Settings.fromJson(json);
    } catch (e) {
      return Settings();
    }
  }

  Future<void> saveSettings(Settings settings) async {
    await initialize();
    final jsonString = jsonEncode(settings.toJson());
    await _client.execute(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      positional: ['settings', jsonString],
    );
  }

  Future<void> _createSettingsTable() async {
    await initialize();
    await _client.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/later.db';

    _client = LibsqlClient(path);
    await _client.connect();

    // Create tables if they don't exist
    await _client.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await _client.execute('''
      CREATE TABLE IF NOT EXISTS url_items (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        categoryId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      );
    ''');

    await _createSettingsTable();

    _isInitialized = true;
  }

  Future<void> close() async {
    if (_isInitialized) {
      await _client.close();
      _isInitialized = false;

