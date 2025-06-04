import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/backup_service.dart';
import '../utils/metadata_service.dart';

// Export all providers
export 'preferences_repository.dart';
export 'settings_notifier.dart';
export 'app_notifier.dart';

// This provider is overridden in main.dart with the actual SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
  name: 'SharedPreferencesProvider',
);

// BackupService provider
final backupServiceProvider = Provider<BackupService>((ref) {
  // This provides a basic instance. AppNotifier will configure maxBackups.
  return BackupService();
});

// MetadataService provider for fetching website metadata and favicons
final metadataServiceProvider = Provider<MetadataService>((ref) {
  return MetadataService();
});
