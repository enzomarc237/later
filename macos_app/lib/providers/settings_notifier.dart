// ignore_for_file: public_member_api_docs, sort_constructors_first, avoid_print
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import 'providers.dart';

class SettingsNotifier extends Notifier<Settings> {
  late PreferencesRepository _preferencesRepository;

  @override
  Settings build() {
    _preferencesRepository = ref.read(preferencesRepositoryProvider);
    _loadSettings();
    return Settings();
  }

  Future<void> _loadSettings() async {
    final settings = await _preferencesRepository.getSettings();
    state = settings;

    // Initialize the dataFolderPathProvider with the current data folder path
    ref.read(dataFolderPathProvider.notifier).state = settings.dataFolderPath;
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await _saveSettings();
  }

  Future<void> setDataFolderPath(String path) async {
    state = state.copyWith(dataFolderPath: path);
    await _saveSettings();

    // Update the dataFolderPathProvider with the new path
    ref.read(dataFolderPathProvider.notifier).state = path;
  }

  Future<void> setShowSystemTrayIcon(bool show) async {
    state = state.copyWith(showSystemTrayIcon: show);
    await _saveSettings();
  }

  Future<void> setStartMinimized(bool minimized) async {
    state = state.copyWith(startMinimized: minimized);
    await _saveSettings();
  }

  Future<void> setAutoImportFromClipboard(bool autoImport) async {
    state = state.copyWith(autoImportFromClipboard: autoImport);
    await _saveSettings();
  }

  // Backup settings
  Future<void> setAutoBackupEnabled(bool enabled) async {
    state = state.copyWith(autoBackupEnabled: enabled);
    await _saveSettings();

    // Update the AppNotifier's auto backup setting
    ref.read(appNotifier.notifier).setAutoBackup(enabled);
  }

  Future<void> setMaxBackups(int maxBackups) async {
    state = state.copyWith(maxBackups: maxBackups);
    await _saveSettings();
  }

  // Custom theme settings
  Future<void> setCustomThemeId(String themeId) async {
    state = state.copyWith(customThemeId: themeId);
    await _saveSettings();
  }

  Future<void> setUseCustomTheme(bool useCustomTheme) async {
    state = state.copyWith(useCustomTheme: useCustomTheme);
    await _saveSettings();
  }

  Future<void> clearAllData() async {
    await _preferencesRepository.clearAllData();

    // Also clear the app state
    await ref.read(appNotifier.notifier).clearData();
  }

  Future<void> _saveSettings() async {
    await _preferencesRepository.saveSettings(state);
  }
}

final settingsNotifier = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
