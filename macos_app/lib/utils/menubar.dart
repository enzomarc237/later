import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';

import '../models/url_item.dart';
import '../pages/settings_page.dart';
import '../pages/import_dialog.dart';
import '../pages/import_urls_dialog.dart';
import '../pages/export_dialog.dart';
import '../providers/providers.dart';
import '../utils/import_export_manager.dart';

/// A utility class for building the application's menu bar.
class LaterMenuBar {
  /// Builds a menu bar with theme-aware styling.
  static Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => _buildMenuBar(context, ref),
    );
  }

  /// Internal implementation of the menu bar with WidgetRef
  static Widget _buildMenuBar(BuildContext context, WidgetRef ref) {
    final theme = MacosTheme.of(context);

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
              _buildMenuItem(context, 'Import Bookmarks', '⌘I', () {
                _showImportDialog(context, ref);
              }),
              _buildMenuItem(context, 'Export Bookmarks', '⌘E', () {
                _showExportDialog(context, ref);
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
  static Widget _buildMenuButton(
      BuildContext context, String label, List<Widget> menuItems) {
    return PopupMenuButton<String>(
      color: MacosTheme.of(context).canvasColor,
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: MacosTheme.brightnessOf(context) == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade300,
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
  static Widget _buildMenuItem(BuildContext context, String label,
      String? shortcut, VoidCallback onTap) {
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

  /// Shows the import dialog
  static void _showImportDialog(BuildContext context, WidgetRef ref) async {
    try {
      // Show the import dialog
      final importedUrls = await showMacosAlertDialog<List<UrlItem>>(
        context: context,
        builder: (_) => const ImportDialog(),
      );

      // If user canceled or no URLs were imported, do nothing
      if (importedUrls == null || importedUrls.isEmpty) return;

      // Show import dialog to let user select URLs and category
      final selectedUrls = await showImportUrlsDialog(
        context,
        importedUrls,
      );

      // If user canceled, do nothing
      if (selectedUrls == null || selectedUrls.isEmpty) return;

      // Import selected URLs
      final appNotifierRef = ref.read(appNotifier.notifier);

      // Add each URL
      for (final url in selectedUrls) {
        appNotifierRef.addUrl(url);
      }

      // Show notification
      LocalNotification(
        title: 'Import Successful',
        body: 'Imported ${selectedUrls.length} URLs',
      ).show();
    } catch (e) {
      debugPrint('Error importing URLs: $e');
      _showErrorDialog(context, 'Import Failed', 'Failed to import URLs: $e');
    }
  }

  /// Shows the export dialog
  static void _showExportDialog(BuildContext context, WidgetRef ref) async {
    try {
      // Get export data from AppNotifier
      final exportData = ref.read(appNotifier.notifier).exportData();

      // Show export format dialog
      final exportConfig = await showExportDialog(context);
      if (exportConfig == null) return;

      // Use ImportExportManager to handle the export
      final importExportManager = ImportExportManager();
      await importExportManager.exportBookmarks(
          context, exportData, exportConfig);

      // Show notification
      LocalNotification(
        title: 'Export Successful',
        body:
            'Exported ${exportData.urls.length} URLs to ${exportConfig.format.displayName} file',
      ).show();
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
      _showErrorDialog(context, 'Export Failed', 'Failed to export URLs: $e');
    }
  }

  /// Shows an error dialog
  static void _showErrorDialog(
      BuildContext context, String title, String message) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.exclamationmark_triangle,
          size: 56,
          color: MacosColors.systemRedColor,
        ),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ),
    );
  }
}
