import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

/// A model class representing a custom theme option.
class ThemeOption {
  /// The unique identifier for this theme.
  final String id;

  /// The display name of this theme.
  final String name;

  /// The primary color of this theme.
  final Color primaryColor;

  /// The accent color of this theme.
  final Color accentColor;

  /// Whether this theme is a dark theme.
  final bool isDark;

  /// Creates a new [ThemeOption].
  const ThemeOption({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
  });

  /// Creates a [MacosThemeData] from this theme option.
  MacosThemeData toMacosThemeData() {
    final baseTheme = isDark ? MacosThemeData.dark() : MacosThemeData.light();

    return baseTheme.copyWith(
      primaryColor: primaryColor,
      pushButtonTheme: PushButtonThemeData(
        // Use accent color for buttons
        secondaryColor: accentColor,
      ),
      iconButtonTheme: MacosIconButtonThemeData(
        backgroundColor: Colors.transparent,
        hoverColor: accentColor.withOpacity(0.1),
      ),
      dividerColor: isDark ? const Color(0xFF3F3F3F) : MacosColors.separatorColor,
      canvasColor: isDark ? const Color(0xFF1E1E1E) : MacosColors.windowBackgroundColor,
    );
  }

  /// Predefined theme options.
  static List<ThemeOption> predefinedThemes = [
    // Default Light Theme
    const ThemeOption(
      id: 'default_light',
      name: 'Default Light',
      primaryColor: MacosColors.controlAccentColor,
      accentColor: MacosColors.controlAccentColor,
      isDark: false,
    ),

    // Default Dark Theme
    const ThemeOption(
      id: 'default_dark',
      name: 'Default Dark',
      primaryColor: Colors.white,
      accentColor: MacosColors.controlAccentColor,
      isDark: true,
    ),

    // Blue Theme
    ThemeOption(
      id: 'blue',
      name: 'Blue',
      primaryColor: Colors.blue.shade700,
      accentColor: Colors.blue.shade500,
      isDark: false,
    ),

    // Dark Blue Theme
    ThemeOption(
      id: 'dark_blue',
      name: 'Dark Blue',
      primaryColor: Colors.blue.shade300,
      accentColor: Colors.blue.shade200,
      isDark: true,
    ),

    // Green Theme
    ThemeOption(
      id: 'green',
      name: 'Green',
      primaryColor: Colors.green.shade700,
      accentColor: Colors.green.shade500,
      isDark: false,
    ),

    // Dark Green Theme
    ThemeOption(
      id: 'dark_green',
      name: 'Dark Green',
      primaryColor: Colors.green.shade300,
      accentColor: Colors.green.shade200,
      isDark: true,
    ),

    // Purple Theme
    ThemeOption(
      id: 'purple',
      name: 'Purple',
      primaryColor: Colors.purple.shade700,
      accentColor: Colors.purple.shade500,
      isDark: false,
    ),

    // Dark Purple Theme
    ThemeOption(
      id: 'dark_purple',
      name: 'Dark Purple',
      primaryColor: Colors.purple.shade300,
      accentColor: Colors.purple.shade200,
      isDark: true,
    ),

    // High Contrast Light
    const ThemeOption(
      id: 'high_contrast_light',
      name: 'High Contrast Light',
      primaryColor: Colors.black,
      accentColor: Colors.black,
      isDark: false,
    ),

    // High Contrast Dark
    const ThemeOption(
      id: 'high_contrast_dark',
      name: 'High Contrast Dark',
      primaryColor: Colors.white,
      accentColor: Colors.white,
      isDark: true,
    ),
  ];

  /// Get a theme option by ID.
  static ThemeOption getById(String id) {
    return predefinedThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => predefinedThemes[0], // Default to first theme if not found
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor.value,
      'accentColor': accentColor.value,
      'isDark': isDark,
    };
  }

  /// Create from JSON.
  factory ThemeOption.fromJson(Map<String, dynamic> json) {
    return ThemeOption(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryColor: Color(json['primaryColor'] as int),
      accentColor: Color(json['accentColor'] as int),
      isDark: json['isDark'] as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ThemeOption && other.id == id && other.name == name && other.primaryColor == primaryColor && other.accentColor == accentColor && other.isDark == isDark;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ primaryColor.hashCode ^ accentColor.hashCode ^ isDark.hashCode;
  }
}
