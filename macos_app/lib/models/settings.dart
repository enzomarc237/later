import 'package:flutter/material.dart';

class Settings {
  final ThemeMode themeMode;
  final String dataFolderPath;
  final bool showSystemTrayIcon;
  final bool startMinimized;
  final bool autoImportFromClipboard;

  Settings({
    this.themeMode = ThemeMode.system,
    this.dataFolderPath = '',
    this.showSystemTrayIcon = true,
    this.startMinimized = false,
    this.autoImportFromClipboard = false,
  });

  Settings copyWith({
    ThemeMode? themeMode,
    String? dataFolderPath,
    bool? showSystemTrayIcon,
    bool? startMinimized,
    bool? autoImportFromClipboard,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      dataFolderPath: dataFolderPath ?? this.dataFolderPath,
      showSystemTrayIcon: showSystemTrayIcon ?? this.showSystemTrayIcon,
      startMinimized: startMinimized ?? this.startMinimized,
      autoImportFromClipboard: autoImportFromClipboard ?? this.autoImportFromClipboard,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'dataFolderPath': dataFolderPath,
      'showSystemTrayIcon': showSystemTrayIcon,
      'startMinimized': startMinimized,
      'autoImportFromClipboard': autoImportFromClipboard,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      themeMode: ThemeMode.values[json['themeMode'] as int],
      dataFolderPath: json['dataFolderPath'] as String,
      showSystemTrayIcon: json['showSystemTrayIcon'] as bool,
      startMinimized: json['startMinimized'] as bool,
      autoImportFromClipboard: json['autoImportFromClipboard'] as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Settings &&
      other.themeMode == themeMode &&
      other.dataFolderPath == dataFolderPath &&
      other.showSystemTrayIcon == showSystemTrayIcon &&
      other.startMinimized == startMinimized &&
      other.autoImportFromClipboard == autoImportFromClipboard;
  }

  @override
  int get hashCode {
    return themeMode.hashCode ^
      dataFolderPath.hashCode ^
      showSystemTrayIcon.hashCode ^
      startMinimized.hashCode ^
      autoImportFromClipboard.hashCode;
  }

  @override
  String toString() {
    return 'Settings(themeMode: $themeMode, dataFolderPath: $dataFolderPath, showSystemTrayIcon: $showSystemTrayIcon, startMinimized: $startMinimized, autoImportFromClipboard: $autoImportFromClipboard)';
  }
}