import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import '../pages/settings_page.dart';

/// A utility class for building the application's menu bar.
class LaterMenuBar {
  /// Builds a menu bar with theme-aware styling.
  static Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final brightness = theme.brightness;
    final primaryColor = theme.primaryColor;

    // Create a menu bar using MacosUI components
    return Container(
      color: theme.canvasColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildMenuButton(
            context,
            'Later',
            [
              _buildMenuItem(context, 'About Later', null, () {
                // TODO: Implement about dialog
              }),
              _buildMenuItem(context, 'Preferences', '⌘,', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }),
              const Divider(),
              _buildMenuItem(context, 'Quit Later', '⌘Q', () {
                // TODO: Implement graceful app exit
              }),
            ],
          ),
          _buildMenuButton(
            context,
            'File',
            [
              _buildMenuItem(context, 'Import Tabs', '⌘I', () {
                // TODO: Implement tab import
              }),
              _buildMenuItem(context, 'Export URLs', '⌘E', () {
                // TODO: Implement URL export
              }),
            ],
          ),
          _buildMenuButton(
            context,
            'Edit',
            [
              _buildMenuItem(context, 'Cut', '⌘X', () {}),
              _buildMenuItem(context, 'Copy', '⌘C', () {}),
              _buildMenuItem(context, 'Paste', '⌘V', () {}),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a menu button that shows a dropdown menu when clicked.
  static Widget _buildMenuButton(BuildContext context, String label, List<Widget> menuItems) {
    return PopupMenuButton<String>(
      color: MacosTheme.of(context).canvasColor,
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: MacosTheme.brightnessOf(context) == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: MacosTheme.of(context).typography.body,
        ),
      ),
      itemBuilder: (context) => [
        for (final item in menuItems)
          PopupMenuItem<String>(
            padding: EdgeInsets.zero,
            child: item,
          ),
      ],
    );
  }

  /// Builds a menu item with an optional keyboard shortcut.
  static Widget _buildMenuItem(BuildContext context, String label, String? shortcut, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MacosTheme.of(context).typography.body,
            ),
            if (shortcut != null)
              Text(
                shortcut,
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: MacosTheme.of(context).primaryColor,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
