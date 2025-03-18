import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/backup_service.dart';
import '../utils/file_storage_service.dart';
import 'settings_notifier.dart';

// Export all providers
export 'preferences_repository.dart';
export 'settings_notifier.dart';
export 'app_notifier.dart';

// This provider is overridden in main.dart with the actual SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
  name: 'SharedPreferencesProvider',
);

// FileStorageService provider that uses the data folder path from settings
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  final settings = ref.watch(settingsNotifier);
  return FileStorageService(basePath: settings.dataFolderPath);
});

// BackupService provider that uses the FileStorageService
final backupServiceProvider = Provider<BackupService>((ref) {
  final fileStorage = ref.watch(fileStorageServiceProvider);
  return BackupService(fileStorage: fileStorage);
});
