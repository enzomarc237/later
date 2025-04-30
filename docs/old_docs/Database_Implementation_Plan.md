# Database Implementation Plan for Later App Using Turso DB

## 1. Introduction to Turso DB

Turso DB is a distributed database built on libSQL, which is an open-source fork of SQLite. It's designed to provide the simplicity and performance of SQLite with additional features for distributed applications, making it an excellent choice for the Later app.

### 1.1 Key Features of Turso DB

- **SQLite Compatibility**: Uses libSQL, which maintains compatibility with SQLite while adding extensions
- **Edge-Deployed Architecture**: Databases deployed globally, close to users for low latency
- **Embedded and Server Modes**: Can run embedded in the app or as a server
- **Synchronization**: Built-in capabilities for syncing data across devices
- **Offline-First**: Support for offline operations with automatic sync when online
- **Serverless**: No need to manage database infrastructure
- **High Performance**: Optimized for read-heavy workloads like the Later app

### 1.2 Why Turso DB for Later App

1. **Local-First Architecture**: Aligns with Later's desktop app approach
2. **Future Cloud Integration**: Provides a clear path for adding cloud sync later
3. **Multi-Device Support**: Facilitates syncing bookmarks across devices
4. **SQLite Compatibility**: Simplifies migration from file-based storage
5. **Performance**: Optimized for the types of queries Later performs
6. **Cost-Effective**: Pay-as-you-grow pricing model works well for a growing app

## 2. Database Schema Design

Based on the current Later app models, here's the proposed database schema for Turso DB implementation:

### 2.1 Tables Structure

#### Categories Table

```sql
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  icon_name TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT 0
);

CREATE INDEX idx_categories_uuid ON categories(uuid);
```

#### URL Items Table

```sql
CREATE TABLE url_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  url TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category_id TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  metadata TEXT, -- Stored as JSON
  status INTEGER NOT NULL DEFAULT 0, -- Corresponds to UrlStatus enum
  last_checked TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT 0,
  FOREIGN KEY (category_id) REFERENCES categories(uuid)
);

CREATE INDEX idx_url_items_uuid ON url_items(uuid);
CREATE INDEX idx_url_items_category_id ON url_items(category_id);
CREATE INDEX idx_url_items_url ON url_items(url);
```

#### Tags Table (for future implementation)

```sql
CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tags_uuid ON tags(uuid);
```

#### URL-Tag Relationship (for future implementation)

```sql
CREATE TABLE url_tags (
  url_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (url_id, tag_id),
  FOREIGN KEY (url_id) REFERENCES url_items(uuid),
  FOREIGN KEY (tag_id) REFERENCES tags(uuid)
);

CREATE INDEX idx_url_tags_url_id ON url_tags(url_id);
CREATE INDEX idx_url_tags_tag_id ON url_tags(tag_id);
```

#### Sync Status Table (for cloud synchronization)

```sql
CREATE TABLE sync_status (
  entity_type TEXT NOT NULL, -- 'category', 'url', 'tag'
  entity_id TEXT NOT NULL,
  last_synced_at TIMESTAMP,
  sync_status TEXT NOT NULL, -- 'pending', 'synced', 'conflict'
  remote_updated_at TIMESTAMP,
  PRIMARY KEY (entity_type, entity_id)
);

CREATE INDEX idx_sync_status_status ON sync_status(sync_status);
```

### 2.2 Schema Notes

1. **Soft Deletes**: Used `is_deleted` flags instead of hard deletes to maintain sync history
2. **UUID Primary Keys**: Essential for distributed database synchronization
3. **Indexes**: Created for frequently queried fields
4. **JSON Storage**: Metadata stored as JSON text for flexibility
5. **Sync Tracking**: Dedicated table for tracking sync status

## 3. Migration Strategy

Migrating from a file-based storage to Turso DB requires a careful approach to ensure data integrity and minimal disruption.

### 3.1 Migration Steps

1. **Database Schema Creation**
   - Create the database schema on first app launch after update
   - Verify schema creation success before proceeding

2. **Data Inventory**
   - Scan existing JSON files to identify all data to be migrated
   - Generate a migration manifest

3. **Data Migration**
   - Import categories first (since URLs reference categories)
   - Import URLs with references to categories
   - Verify count matches between source and destination

4. **Validation**
   - Run integrity checks on migrated data
   - Verify relationships between entities
   - Ensure all metadata is properly converted

5. **Rollback Capability**
   - Maintain original files as backup
   - Implement rollback mechanism if migration fails

### 3.2 Migration Code Structure

```dart
class DatabaseMigrator {
  final FileStorageService _fileStorage;
  final LaterDatabase _database;

  DatabaseMigrator(this._fileStorage, this._database);

  Future<MigrationResult> migrateData() async {
    final migrationResult = MigrationResult();
    
    try {
      // Step 1: Migrate categories
      final categories = await _fileStorage.readJsonListFile('categories.json');
      migrationResult.totalCategories = categories.length;
      
      for (final categoryJson in categories) {
        final category = Category.fromJson(categoryJson);
        await _database.insertCategory(CategoriesCompanion(
          uuid: Value(category.id),
          name: Value(category.name),
          iconName: Value(category.iconName),
          createdAt: Value(category.createdAt),
          updatedAt: Value(category.updatedAt),
        ));
        migrationResult.migratedCategories++;
      }
      
      // Step 2: Migrate URLs
      final urls = await _fileStorage.readJsonListFile('urls.json');
      migrationResult.totalUrls = urls.length;
      
      for (final urlJson in urls) {
        final url = UrlItem.fromJson(urlJson);
        await _database.insertUrl(UrlItemsCompanion(
          uuid: Value(url.id),
          url: Value(url.url),
          title: Value(url.title),
          description: Value(url.description),
          categoryId: Value(url.categoryId),
          createdAt: Value(url.createdAt),
          updatedAt: Value(url.updatedAt),
          metadata: Value(jsonEncode(url.metadata ?? {})),
          status: Value(url.status.index),
          lastChecked: Value(url.lastChecked),
        ));
        migrationResult.migratedUrls++;
      }
      
      migrationResult.success = true;
    } catch (e) {
      migrationResult.success = false;
      migrationResult.errorMessage = e.toString();
    }
    
    return migrationResult;
  }
}
```

### 3.3 Dual-Storage Period

To ensure a smooth transition, implement a dual-storage approach for a limited time:

1. Write to both storage systems during transition
2. Read primarily from Turso DB, fallback to files if needed
3. Include a migration status indicator in settings
4. After successful validation period, remove file-based storage code

## 4. Implementation Approach

### 4.1 Integration with Drift ORM

Drift is a type-safe ORM for Dart that works well with SQLite and can be adapted to work with Turso/libSQL:

```dart
import 'package:drift/drift.dart';

// Database tables definition
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get iconName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class UrlItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().references(Categories, #uuid)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get metadata => text().map(const JsonMapper()).nullable()();
  IntColumn get status => intEnum<UrlStatus>().withDefault(const Constant(0))();
  DateTimeColumn get lastChecked => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

// Database access class
@DriftDatabase(tables: [Categories, UrlItems])
class LaterDatabase extends _$LaterDatabase {
  LaterDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
  
  // Categories operations
  Future<List<Category>> getAllCategories() => 
      (select(categories)..where((c) => c.isDeleted.equals(false))).get();
      
  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);
      
  Future<bool> updateCategory(CategoriesCompanion category) =>
      update(categories).replace(category);
      
  Future<int> softDeleteCategory(String uuid) =>
      (update(categories)..where((c) => c.uuid.equals(uuid)))
        .write(const CategoriesCompanion(isDeleted: Value(true)));
  
  // URL operations
  Future<List<UrlItemData>> getUrlsByCategory(String categoryId) =>
      (select(urlItems)
        ..where((u) => u.categoryId.equals(categoryId) & u.isDeleted.equals(false)))
        .get();
        
  Future<List<UrlItemData>> getAllUrls() =>
      (select(urlItems)..where((u) => u.isDeleted.equals(false))).get();
}
```

### 4.2 Custom Platform Channel for Turso/libSQL

Since there isn't a direct Dart package for Turso yet, implement a custom platform channel:

```dart
// Native code bridge for Turso/libSQL
class TursoExecutor extends QueryExecutor {
  final TursoClient _client;
  
  TursoExecutor(this._client);
  
  @override
  Future<List<Map<String, dynamic>>> runSelect(String statement, List<Object?> parameters) async {
    final result = await _client.execute(statement, parameters);
    return result.rows.map((row) => row.asMap()).toList();
  }
  
  @override
  Future<int> runInsert(String statement, List<Object?> parameters) async {
    final result = await _client.execute(statement, parameters);
    return result.lastInsertId ?? 0;
  }
  
  // Implement other required methods: runUpdate, runDelete, etc.
}
```

### 4.3 Repository Pattern Implementation

Implement a repository layer to abstract database operations:

```dart
class UrlRepository {
  final LaterDatabase _db;
  
  UrlRepository(this._db);
  
  // URL operations
  Future<List<UrlItem>> getAllUrls() async {
    final results = await _db.getAllUrls();
    return results.map(_mapToModel).toList();
  }
  
  Future<List<UrlItem>> getUrlsByCategory(String categoryId) async {
    final results = await _db.getUrlsByCategory(categoryId);
    return results.map(_mapToModel).toList();
  }
  
  Future<void> addUrl(UrlItem url) async {
    await _db.insertUrl(_mapToCompanion(url));
  }
  
  Future<void> updateUrl(UrlItem url) async {
    await _db.updateUrl(_mapToCompanion(url));
  }
  
  Future<void> deleteUrl(String uuid) async {
    await _db.softDeleteUrl(uuid);
  }
  
  // Mapping methods
  UrlItem _mapToModel(UrlItemData data) {
    return UrlItem(
      id: data.uuid,
      url: data.url,
      title: data.title,
      // Map other fields...
    );
  }
  
  UrlItemsCompanion _mapToCompanion(UrlItem url) {
    return UrlItemsCompanion(
      uuid: Value(url.id),
      url: Value(url.url),
      title: Value(url.title),
      // Map other fields...
    );
  }
}
```

### 4.4 Riverpod Integration

Update the existing Riverpod providers to use the new database repositories:

```dart
// Database provider
final databaseProvider = Provider<LaterDatabase>((ref) {
  final executor = ref.watch(tursoExecutorProvider);
  return LaterDatabase(executor);
});

// Repository providers
final urlRepositoryProvider = Provider<UrlRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UrlRepository(db);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

// Data providers
final urlsProvider = FutureProvider.family<List<UrlItem>, String?>((ref, categoryId) {
  final repository = ref.watch(urlRepositoryProvider);
  if (categoryId == null) {
    return repository.getAllUrls();
  } else {
    return repository.getUrlsByCategory(categoryId);
  }
});
```

## 5. Phased Rollout Plan

### Phase 1: Local Database Implementation (1-2 months)

1. **Foundational Setup**
   - Implement database schema
   - Create Drift integration
   - Develop migration tool

2. **Basic CRUD Operations**
   - Convert file operations to database queries
   - Update repositories and providers
   - Implement transaction support

3. **Migration Testing**
   - Develop migration tests
   - Test with large datasets
   - Benchmark performance

4. **Local-Only Release**
   - Deploy to test users
   - Monitor performance metrics
   - Collect feedback

### Phase 2: Cloud Synchronization (2-3 months)

1. **Sync Infrastructure**
   - Create Turso cloud instance
   - Implement authentication system
   - Develop conflict resolution strategy

2. **Sync Protocol Implementation**
   - Track local changes
   - Implement background sync
   - Add network status monitoring

3. **User Controls**
   - Add sync toggle in settings
   - Implement manual sync trigger
   - Create sync status indicators
   - Add conflict resolution UI

4. **Testing & Stability**
   - Implement comprehensive sync tests
   - Test cross-device scenarios
   - Add error recovery mechanisms
   - Perform stress testing

5. **Beta Release**
   - Limited release to test users
   - Monitor sync performance
   - Track error rates
   - Gather user feedback

### Phase 3: Advanced Features & Optimization (2-3 months)

1. **Performance Optimization**
   - Implement query optimization
   - Add intelligent pre-fetching
   - Optimize sync data transfer size
   - Add compression for sync data

2. **Advanced Sync Features**
   - Selective sync (by category/tag)
   - Scheduled sync options
   - Bandwidth usage controls
   - Conflict resolution preferences

3. **Multi-Device Experience**
   - Device management UI
   - Device-specific settings
   - Last-sync reporting
   - Remote device operations

4. **Data Analytics**
   - Sync performance metrics
   - Usage patterns tracking
   - Storage utilization reporting
   - Health monitoring dashboard

5. **Security Enhancements**
   - End-to-end encryption
   - Data masking options
   - Security audit logging
   - Access control refinement

## 6. Implementation Best Practices

### 6.1 Performance Considerations

1. **Batch Operations**
   - Use transactions for related operations
   - Implement bulk insert/update operations
   - Batch sync operations to reduce network calls

2. **Query Optimization**
   - Use prepared statements
   - Leverage indexes for frequent queries
   - Implement pagination for large result sets
   - Cache frequently accessed data

3. **UI Responsiveness**
   - Move database operations off main thread
   - Implement loading states for async operations
   - Add background sync with notifications
   - Use optimistic UI updates

### 6.2 Security Considerations

1. **Authentication**
   - Implement OAuth or similar auth protocol
   - Use refresh tokens for persistent access
   - Add biometric authentication option for sensitive data

2. **Data Protection**
   - Encrypt sensitive data at rest
   - Use secure connections for sync
   - Implement data sanitization for imports

3. **Error Handling**
   - Create comprehensive error taxonomy
   - Implement centralized error logging
   - Add automatic recovery mechanisms
   - Provide clear user feedback on errors

## 7. Conclusion

Implementing Turso DB for the Later app represents a significant advancement in the application's architecture, enabling important improvements in several key areas:

### 7.1 Technical Benefits

1. **Performance**: Turso's optimized storage engine and query capabilities will significantly improve app responsiveness, especially with large URL collections.

2. **Scalability**: The database architecture supports growth from a few dozen bookmarks to thousands without degradation in performance.

3. **Data Integrity**: Proper relationships, constraints, and transactions ensure data remains consistent across operations.

4. **Developer Experience**: Type-safe queries with Drift, combined with the repository pattern, make database interactions safer and more maintainable.

### 7.2 User Experience Benefits

1. **Responsiveness**: Faster data retrieval means a more fluid user experience, even with large collections.

2. **Multi-Device**: The cloud sync capabilities will allow users to access their bookmarks across multiple devices.

3. **Reliability**: Better data integrity and error handling mean fewer data loss incidents and more resilient operation.

4. **Advanced Organization**: The database schema supports advanced features like tagging, enabling more flexible organization of bookmarks.

### 7.3 Business Benefits

1. **Reduced Maintenance**: More robust storage and sync mechanisms mean fewer support issues.

2. **Future-Proofing**: The architecture can easily accommodate planned features like sharing, collaboration, and AI integration.

3. **Analytics Potential**: Structured data enables better insights into user behavior and feature utilization.

4. **Expansion Path**: The infrastructure supports expanding to other platforms (mobile, web) in the future.

This implementation plan provides a clear path forward, balancing immediate improvements with a foundation for future enhancements. By migrating from file-based storage to Turso DB, the Later app will not only solve current performance challenges but also enable a new generation of features that were previously impractical to implement.

## 8. Addendum: Using libsql_dart Package

After reviewing the official `libsql_dart` package documentation, we can simplify our implementation by using this official client library instead of building a custom solution. This addendum updates the implementation approach to leverage the `libsql_dart` package.

### 8.1 Initializing and Connecting to Turso DB

The `libsql_dart` package provides a straightforward API for connecting to Turso DB in various modes:

```dart
import 'package:libsql_dart/libsql_dart.dart';
import 'package:path_provider/path_provider.dart';

class TursoDBService {
  late LibsqlClient _client;
  
  // Singleton pattern for the DB service
  static final TursoDBService _instance = TursoDBService._internal();
  factory TursoDBService() => _instance;
  TursoDBService._internal();
  
  bool _isInitialized = false;
  
  Future<void> initialize({
    required bool useCloud, 
    String? authToken, 
    String? remoteUrl,
    int syncIntervalSeconds = 5,
  }) async {
    if (_isInitialized) return;
    
    if (useCloud && (authToken == null || remoteUrl == null)) {
      throw Exception('Auth token and remote URL must be provided for cloud mode');
    }
    
    // For local development or before cloud sync is enabled
    if (!useCloud) {
      // Use local database only
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/later.db';
      _client = LibsqlClient(path);
    } else {
      // For embedded replica with cloud sync
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/later.db';
      _client = LibsqlClient(path)
        ..authToken = authToken
        ..syncUrl = remoteUrl
        ..syncIntervalSeconds = syncIntervalSeconds
        ..readYourWrites = true;
    }
    
    await _client.connect();
    _isInitialized = true;
  }
  
  // Get the underlying client for direct operations
  LibsqlClient get client => _client;
  
  // Force sync for embedded replica mode
  Future<void> sync() async {
    await _client.sync();
  }
  
  // Proper cleanup
  Future<void> dispose() async {
    if (_isInitialized) {
      await _client.close();
      _isInitialized = false;
    }
  }
}
```

### 8.2 Integrating with Drift ORM

Drift requires a `QueryExecutor` to perform database operations. We can create a custom executor that uses the `libsql_dart` client:

```dart
import 'package:drift/drift.dart';
import 'package:libsql_dart/libsql_dart.dart';

class LibsqlDriftExecutor extends QueryExecutor {
  final LibsqlClient _client;
  
  LibsqlDriftExecutor(this._client);
  
  @override
  Future<void> close() async {
    // No need to close here, as it's managed by the TursoDBService
  }
  
  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    final result = await _client.execute(statement, positional: args);
    return result.lastInsertRowId?.toInt() ?? 0;
  }
  
  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) async {
    final result = await _client.query(statement, positional: args);
    return result.rows.map((row) {
      final map = <String, Object?>{};
      for (int i = 0; i < row.columnNames.length; i++) {
        map[row.columnNames[i]] = row.values[i];
      }
      return map;
    }).toList();
  }
  
  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    final result = await _client.execute(statement, positional: args);
    return result.rowsAffected ?? 0;
  }
  
  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    final result = await _client.execute(statement, positional: args);
    return result.rowsAffected ?? 0;
  }
  
  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _client.execute(statement, positional: args ?? []);
  }
  
  @override
  TransactionExecutor beginTransaction() {
    return _LibsqlDriftTransactionExecutor(_client);
  }
}

// Transaction executor implementation
class _LibsqlDriftTransactionExecutor extends TransactionExecutor {
  final LibsqlClient _client;
  late final Future<Transaction> _transaction;
  
  _LibsqlDriftTransactionExecutor(this._client) {
    _transaction = _client.transaction();
  }
  
  @override
  Future<void> send() async {
    final tx = await _transaction;
    await tx.commit();
  }
  
  @override
  Future<void> rollback() async {
    final tx = await _transaction;
    await tx.rollback();
  }
  
  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) async {
    final tx = await _transaction;
    final result = await tx.query(statement, positional: args);
    return result.rows.map((row) {
      final map = <String, Object?>{};
      for (int i = 0; i < row.columnNames.length; i++) {
        map[row.columnNames[i]] = row.values[i];
      }
      return map;
    }).toList();
  }
  
  // Implement other methods similar to the main executor
  // ...
}

// Revise our LaterDatabase connection to use the new executor
@DriftDatabase(tables: [Categories, UrlItems])
class LaterDatabase extends _$LaterDatabase {
  LaterDatabase(LibsqlClient client) 
    : super(LibsqlDriftExecutor(client));
  
  // The rest of the database class remains the same
  // ...
}
```

### 8.3 Modified Repository Pattern Implementation

The repository implementation remains largely unchanged, but now it will work with our Turso-powered Drift database:

```dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Providers for Turso DB
final tursoDBServiceProvider = Provider<TursoDBService>((ref) {
  return TursoDBService();
});

// Database provider now uses the Turso client
final databaseProvider = Provider<LaterDatabase>((ref) {
  final tursoService = ref.watch(tursoDBServiceProvider);
  return LaterDatabase(tursoService.client);
});

// Repository implementations remain similar
final urlRepositoryProvider = Provider<UrlRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UrlRepository(db);
});

// Initialize Turso during app startup
Future<void> initTursoDatabase(Ref ref, {bool useCloud = false}) async {
  final settings = ref.read(settingsNotifier);
  
  // Get auth token and URL from secure storage if using cloud
  String? authToken;
  String? remoteUrl;
  
  if (useCloud) {
    // Retrieve credentials from secure storage
    // This would be implemented in a real app
    // authToken = await secureStorage.read(key: 'turso_auth_token');
    // remoteUrl = await secureStorage.read(key: 'turso_remote_url');
    
    // For example:
    authToken = settings.tursoAuthToken;
    remoteUrl = settings.tursoRemoteUrl;
  }
  
  await ref.read(tursoDBServiceProvider).initialize(
    useCloud: useCloud,
    authToken: authToken,
    remoteUrl: remoteUrl,
    syncIntervalSeconds: settings.syncIntervalSeconds ?? 5,
  );
}
```

### 8.4 Handling Synchronization with Embedded Replica Mode

The embedded replica mode in `libsql_dart` is perfect for our phased approach, allowing us to start with local-only storage and later add cloud sync:

```dart
class SyncService {
  final TursoDBService _tursoService;
  final AppNotifier _appNotifier;
  bool _isSyncing = false;
  
  SyncService(this._tursoService, this._appNotifier);
  
  // Perform a manual sync
  Future<SyncResult> performSync() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }
    
    _isSyncing = true;
    _appNotifier.setSyncStatus(SyncStatus.inProgress);
    
    try {
      // Perform the actual sync using libsql_dart
      await _tursoService.sync();
      
      _appNotifier.setSyncStatus(SyncStatus.completed);
      _isSyncing = false;
      return SyncResult(success: true);
    } catch (e) {
      _appNotifier.setSyncStatus(SyncStatus.failed, errorMessage: e.toString());
      _isSyncing = false;
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }
  
  // Start automatic background sync
  void startBackgroundSync({
    required Duration interval,
    required bool onlyWhenOnline,
  }) {
    // Implementation of periodic sync
    // ...
  }
  
  // Handle conflict resolution (if needed beyond what libsql_dart provides)
  Future<void> resolveConflict(ConflictResolution resolution) async {
    // Implementation of conflict resolution UI and logic
    // ...
  }
}

// Provider for the sync service
final syncServiceProvider = Provider<SyncService>((ref) {
  final tursoService = ref.watch(tursoDBServiceProvider);
  final appNotifier = ref.watch(appNotifier.notifier);
  return SyncService(tursoService, appNotifier);
});
```

### 8.5 Migration Updates

Using the `libsql_dart` package also simplifies our migration approach:

```dart
class DatabaseMigrator {
  final FileStorageService _fileStorage;
  final LibsqlClient _client;
  
  DatabaseMigrator(this._fileStorage, this._client);
  
  Future<MigrationResult> migrateData() async {
    final migrationResult = MigrationResult();
    
    try {
      // First, create the schema using DDL statements
      await _createSchema();
      
      // Then migrate the data
      await _migrateCategories(migrationResult);
      await _migrateUrls(migrationResult);
      
      migrationResult.success = true;
    } catch (e) {
      migrationResult.success = false;
      migrationResult.errorMessage = e.toString();
    }
    
    return migrationResult;
  }
  
  Future<void> _createSchema() async {
    // Create tables with transactions for atomicity
    final tx = await _client.transaction();
    
    try {
      // Categories table
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          icon_name TEXT,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          is_deleted BOOLEAN NOT NULL DEFAULT 0
        )
      ''');
      
      await tx.execute('CREATE INDEX IF NOT EXISTS idx_categories_uuid ON categories(uuid)');
      
      // URL Items table
      await tx.execute('''
        CREATE TABLE IF NOT EXISTS url_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          category_id TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          metadata TEXT,
          status INTEGER NOT NULL DEFAULT 0,
          last_checked TIMESTAMP,
          is_deleted BOOLEAN NOT NULL DEFAULT 0,
          FOREIGN KEY (category_id) REFERENCES categories(uuid)
        )
      ''');
      
      // Create other tables and indexes
      // ...
      
      await tx.commit();
    } catch (e) {
      await tx.rollback();
      throw Exception('Failed to create schema: $e');
    }
  }
  
  Future<void> _migrateCategories(MigrationResult result) async {
    // Implementation similar to before, but using _client.execute() instead
    // ...
  }
  
  Future<void> _migrateUrls(MigrationResult result) async {
    // Implementation similar to before, but using _client.execute() instead
    // ...
  }
}
```

### 8.6 Updated Implementation Timeline

Using the `libsql_dart` package simplifies our implementation but doesn't significantly change our phased approach:

1. **Phase 1: Local Database Implementation (Now 3-4 weeks)**
   - Add libsql_dart package
   - Create database schema
   - Implement the Drift integration with libsql_dart
   - Migrate data from file storage
   
2. **Phase 2: Cloud Synchronization (Now 6-8 weeks)**
   - Set up Turso cloud database
   - Implement authentication for Turso
   - Configure embedded replica mode
   - Add sync status UI and controls
   
3. **Phase 3: Advanced Features (Unchanged)**
   - Implement performance optimizations
   - Add advanced sync features
   - Enhance multi-device experience
   - Implement analytics and security features

By leveraging the `libsql_dart` package, we can accelerate the implementation timeline while still maintaining the phased approach to ensure stability and control over the migration process.

