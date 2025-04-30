// ignore_for_file: directives_ordering
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// Import tables
import 'tables/categories.dart';
import 'tables/url_items.dart';
import 'tables/tags.dart';
import 'tables/url_tags.dart';
import 'tables/sync_status.dart';

part 'database.g.dart';

/// The main database class for the Later app.
/// 
/// This database uses drift (formerly moor) for type-safe database access.
/// It defines the tables and provides methods for accessing and manipulating data.
@DriftDatabase(
  tables: [
    Categories,
    UrlItems,
    Tags,
    UrlTags,
    SyncStatus,
  ],
)
class LaterDatabase extends _$LaterDatabase {
  /// Creates a database instance using the provided [executor].
  LaterDatabase(QueryExecutor executor) : super(executor);

  /// The current schema version of the database.
  @override
  int get schemaVersion => 1;

  /// Performs necessary migrations when the database schema version changes.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
      beforeOpen: (details) async {
        // Perform any initialization before opening the database
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  // CATEGORY OPERATIONS

  /// Gets all categories that are not marked as deleted.
  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..where((c) => c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .get();
  }

  /// Watches all categories that are not marked as deleted.
  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
          ..where((c) => c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  /// Gets a category by its UUID.
  Future<Category?> getCategoryByUuid(String uuid) {
    return (select(categories)
          ..where((c) => c.uuid.equals(uuid) & c.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserts a new category.
  Future<int> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  /// Updates an existing category.
  Future<bool> updateCategory(CategoriesCompanion category) {
    return update(categories).replace(category);
  }

  /// Soft deletes a category by marking it as deleted.
  Future<int> softDeleteCategory(String uuid) {
    return (update(categories)
          ..where((c) => c.uuid.equals(uuid)))
        .write(const CategoriesCompanion(
          isDeleted: Value(true),
          updatedAt: Value.absent(),
        ));
  }

  // URL OPERATIONS

  /// Gets all URLs that are not marked as deleted.
  Future<List<UrlItem>> getAllUrls() {
    return (select(urlItems)
          ..where((u) => u.isDeleted.equals(false))
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Watches all URLs that are not marked as deleted.
  Stream<List<UrlItem>> watchAllUrls() {
    return (select(urlItems)
          ..where((u) => u.isDeleted.equals(false))
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Gets URLs for a specific category.
  Future<List<UrlItem>> getUrlsForCategory(String categoryId) {
    return (select(urlItems)
          ..where((u) => u.categoryId.equals(categoryId) & u.isDeleted.equals(false))
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Watches URLs for a specific category.
  Stream<List<UrlItem>> watchUrlsForCategory(String categoryId) {
    return (select(urlItems)
          ..where((u) => u.categoryId.equals(categoryId) & u.isDeleted.equals(false))
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Gets a URL by its UUID.
  Future<UrlItem?> getUrlByUuid(String uuid) {
    return (select(urlItems)
          ..where((u) => u.uuid.equals(uuid) & u.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Inserts a new URL.
  Future<int> insertUrl(UrlItemsCompanion url) {
    return into(urlItems).insert(url);
  }

  /// Updates an existing URL.
  Future<bool> updateUrl(UrlItemsCompanion url) {
    return update(urlItems).replace(url);
  }

  /// Soft deletes a URL by marking it as deleted.
  Future<int> softDeleteUrl(String uuid) {
    return (update(urlItems)
          ..where((u) => u.uuid.equals(uuid)))
        .write(const UrlItemsCompanion(
          isDeleted: Value(true),
          updatedAt: Value.absent(),
        ));
  }

  /// Soft deletes all URLs in a category.
  Future<int> softDeleteUrlsInCategory(String categoryId) {
    return (update(urlItems)
          ..where((u) => u.categoryId.equals(categoryId) & u.isDeleted.equals(false)))
        .write(const UrlItemsCompanion(
          isDeleted: Value(true),
          updatedAt: Value.absent(),
        ));
  }

  /// Updates the status of a URL.
  Future<int> updateUrlStatus(String uuid, UrlStatus status) {
    return (update(urlItems)
          ..where((u) => u.uuid.equals(uuid)))
        .write(UrlItemsCompanion(
          status: Value(status),
          lastChecked: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// Searches for URLs by title, description, or URL.
  Future<List<UrlItem>> searchUrls(String query) {
    final searchTerm = '%$query%';
    return (select(urlItems)
          ..where((u) => 
              (u.title.like(searchTerm) | 
               u.description.like(searchTerm) | 
               u.url.like(searchTerm)) & 
              u.isDeleted.equals(false))
          ..orderBy([(u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Counts the number of URLs in a category.
  Future<int> countUrlsInCategory(String categoryId) async {
    final query = selectCount(urlItems)
      ..where((u) => u.categoryId.equals(categoryId) & u.isDeleted.equals(false));
    return await query.getSingle();
  }

  // TRANSACTION HELPERS

  /// Runs a transaction that performs multiple database operations atomically.
  Future<T> runTransaction<T>(Future<T> Function() action) {
    return transaction(action);
  }

  /// Performs a batch insert of categories.
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) async {
    await batch((batch) {
      batch.insertAll(this.categories, categories);
    });
  }

  /// Performs a batch insert of URLs.
  Future<void> batchInsertUrls(List<UrlItemsCompanion> urls) async {
    await batch((batch) {
      batch.insertAll(this.urlItems, urls);
    });
  }
}

/// Creates a database connection using a file in the application documents directory.
Future<LaterDatabase> createDatabase() async {
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDir.path, 'Later', 'database.sqlite');
  
  // Ensure the directory exists
  final dbDir = Directory(p.dirname(dbPath));
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  
  final executor = NativeDatabase(File(dbPath));
  return LaterDatabase(executor);
}