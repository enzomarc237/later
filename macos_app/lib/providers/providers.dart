import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Export all providers
export 'preferences_repository.dart';
export 'settings_notifier.dart';
export 'app_notifier.dart';

// This provider is overridden in main.dart with the actual SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
  name: 'SharedPreferencesProvider',
);
