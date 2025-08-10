import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/database_service.dart';
import '../utils/backup_service.dart';
import '../utils/metadata_service.dart';

// Export all providers
export 'preferences_repository.dart';
export 'settings_notifier.dart';
export 'app_notifier.dart';

// DatabaseService provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// StateProvider for data folder path to break circular dependency
final dataFolderPathProvider = StateProvider<String>((ref) => '');

// BackupService provider that uses the FileStorageService
final backupServiceProvider = Provider<BackupService>((ref) {
  // Note: FileStorageService is removed, so backup service might need re-evaluation
  // For now, it will use a dummy fileStorage or be refactored later.
  return BackupService(fileStorage: null); // Placeholder for now
});

// MetadataService provider for fetching website metadata and favicons
final metadataServiceProvider = Provider<MetadataService>((ref) {
  return MetadataService();
});
