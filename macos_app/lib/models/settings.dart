import 'package:flutter/material.dart';

class Settings {
  final ThemeMode themeMode;
  final String dataFolderPath;
  final bool showSystemTrayIcon;
  final bool startMinimized;
  final bool autoImportFromClipboard;

  // Backup settings
  final bool autoBackupEnabled;
  final int maxBackups;

  Settings({
    this.themeMode = ThemeMode.system,
    this.dataFolderPath = '',
    this.showSystemTrayIcon = true,
    this.startMinimized = false,
    this.autoImportFromClipboard = false,
    this.autoBackupEnabled = true,
    this.maxBackups = 10,
  });

  Settings copyWith({
    ThemeMode? themeMode,
    String? dataFolderPath,
    bool? showSystemTrayIcon,
    bool? startMinimized,
    bool? autoImportFromClipboard,
    bool? autoBackupEnabled,
    int? maxBackups,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      dataFolderPath: dataFolderPath ?? this.dataFolderPath,
      showSystemTrayIcon: showSystemTrayIcon ?? this.showSystemTrayIcon,
      startMinimized: startMinimized ?? this.startMinimized,
      autoImportFromClipboard: autoImportFromClipboard ?? this.autoImportFromClipboard,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      maxBackups: maxBackups ?? this.maxBackups,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'dataFolderPath': dataFolderPath,
      'showSystemTrayIcon': showSystemTrayIcon,
      'startMinimized': startMinimized,
      'autoImportFromClipboard': autoImportFromClipboard,
      'autoBackupEnabled': autoBackupEnabled,
      'maxBackups': maxBackups,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      themeMode: ThemeMode.values[json['themeMode'] as int],
      dataFolderPath: json['dataFolderPath'] as String? ?? '',
      showSystemTrayIcon: json['showSystemTrayIcon'] as bool? ?? true,
      startMinimized: json['startMinimized'] as bool? ?? false,
      autoImportFromClipboard: json['autoImportFromClipboard'] as bool? ?? false,
      autoBackupEnabled: json['autoBackupEnabled'] as bool? ?? true,
      maxBackups: json['maxBackups'] as int? ?? 10,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Settings && other.themeMode == themeMode && other.dataFolderPath == dataFolderPath && other.showSystemTrayIcon == showSystemTrayIcon && other.startMinimized == startMinimized && other.autoImportFromClipboard == autoImportFromClipboard && other.autoBackupEnabled == autoBackupEnabled && other.maxBackups == maxBackups;
  }

  @override
  int get hashCode {
    return themeMode.hashCode ^ dataFolderPath.hashCode ^ showSystemTrayIcon.hashCode ^ startMinimized.hashCode ^ autoImportFromClipboard.hashCode ^ autoBackupEnabled.hashCode ^ maxBackups.hashCode;
  }

  @override
  String toString() {
    return 'Settings(themeMode: $themeMode, dataFolderPath: $dataFolderPath, showSystemTrayIcon: $showSystemTrayIcon, startMinimized: $startMinimized, autoImportFromClipboard: $autoImportFromClipboard, autoBackupEnabled: $autoBackupEnabled, maxBackups: $maxBackups)';
  }
}
