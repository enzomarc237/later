import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database.dart';

/// Provider for the database instance.
/// 
/// This provider creates and maintains a singleton instance of the database.
/// It ensures that the database is properly initialized and closed when needed.
final databaseProvider = Provider<LaterDatabase>((ref) {
  // Create the database
  final database = createSyncLaterDatabase();
  
  // Dispose the database when the provider is disposed
  ref.onDispose(() {
    database.close();
  });
  
  return database;
});

/// Creates a database instance synchronously.
/// 
/// This is used by the provider to create a database instance.
/// It uses a synchronous approach to ensure the database is available immediately.
LaterDatabase createSyncLaterDatabase() {
  final dbFile = File(getDatabasePath());
  
  // Ensure the directory exists
  final dbDir = Directory(p.dirname(dbFile.path));
  if (!dbDir.existsSync()) {
    dbDir.createSync(recursive: true);
  }
  
  return LaterDatabase(createDriftExecutor(dbFile));
}

/// Gets the path to the database file.
/// 
/// This is a synchronous version that uses the current directory as a fallback.
/// It's used for the initial database creation.
String getDatabasePath() {
  try {
    final appDir = Directory(p.join(Directory.current.path, 'Later'));
    final dbPath = p.join(appDir.path, 'database.sqlite');
    return dbPath;
  } catch (e) {
    // Fallback to a temporary path
    return p.join(Directory.systemTemp.path, 'Later', 'database.sqlite');
  }
}

/// Creates a drift executor for the database.
/// 
/// This function creates a NativeDatabase executor for the given file.
QueryExecutor createDriftExecutor(File file) {
  return NativeDatabase(file);
}

/// Provider for the database path.
/// 
/// This provider gets the path to the database file asynchronously.
/// It's used for operations that need to know the database location.
final databasePathProvider = FutureProvider<String>((ref) async {
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'Later', 'database.sqlite');
});