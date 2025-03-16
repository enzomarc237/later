import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class SystemTrayManager {
  final SystemTray _systemTray = SystemTray();
  final Ref _ref;

  SystemTrayManager(this._ref);

  Future<void> initSystemTray() async {
    final settings = _ref.read(settingsNotifier);
    if (!settings.showSystemTrayIcon) return;

    // We first init the systray menu
    String iconPath = Platform.isWindows ? 'assets/icons/mac256.png' : 'assets/icons/mac256.png';

    await _systemTray.initSystemTray(title: "Later", iconPath: iconPath, toolTip: "Later Bookmarker is running in background");

    // Create context menu items
    List<MenuItem> items = [
      MenuItem(
        label: 'Open Later',
        onClicked: () => _showApp(),
      ),
      MenuItem(label: '-'), // Separator
      MenuItem(
        label: 'Import Tabs from Clipboard',
        onClicked: () => _importTabsFromClipboard(),
      ),
      MenuItem(
        label: 'Export All URLs',
        onClicked: () => _exportAllUrls(),
      ),
      MenuItem(label: '-'), // Separator
      MenuItem(
        label: 'Exit',
        onClicked: () => exit(0),
      ),
    ];

    // Set the context menu
    await _systemTray.setContextMenu(items);

    // Handle system tray events
    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("System tray event: $eventName");
      if (eventName == "leftMouseDown") {
        _showApp();
      } else if (eventName == "rightMouseDown") {
        _systemTray.popUpContextMenu();
      }
    });
  }

  Future<void> _showApp() async {
    try {
      // Show and focus the window
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing app: $e');
    }
  }

  Future<void> _importTabsFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!;

        // Try to parse as JSON
        try {
          final jsonData = jsonDecode(text) as Map<String, dynamic>;

          // Check if it's in our export format
          if (jsonData.containsKey('urls') && jsonData.containsKey('exportedAt')) {
            final importData = ExportData.fromJson(jsonData);
            _ref.read(appNotifier.notifier).importData(importData);
            debugPrint('Imported ${importData.urls.length} URLs from clipboard');
          }
          // Check if it's from browser extension (just URLs array)
          else if (jsonData.containsKey('urls')) {
            final urls = (jsonData['urls'] as List).cast<Map<String, dynamic>>();

            // Get default category or create one
            final appState = _ref.read(appNotifier);
            String categoryId;

            if (appState.categories.isEmpty) {
              // Create a default category
              final defaultCategory = Category(name: 'Imported');
              _ref.read(appNotifier.notifier).addCategory(defaultCategory);
              categoryId = defaultCategory.id;
            } else {
              categoryId = appState.categories.first.id;
            }

            // Import URLs
            for (final urlData in urls) {
              final url = UrlItem(
                url: urlData['url'] as String,
                title: urlData['title'] as String,
                description: urlData['description'] as String?,
                categoryId: categoryId,
              );
              _ref.read(appNotifier.notifier).addUrl(url);
            }

            debugPrint('Imported ${urls.length} URLs from clipboard');
          }
        } catch (e) {
          // If not valid JSON, just import as a single URL
          if (text.startsWith('http')) {
            _ref.read(appNotifier.notifier).addUrl(
                  UrlItem(
                    url: text,
                    title: 'Imported from clipboard',
                    categoryId: _ref.read(appNotifier).categories.isNotEmpty ? _ref.read(appNotifier).categories.first.id : '',
                  ),
                );
            debugPrint('Imported single URL from clipboard');
          } else {
            debugPrint('Clipboard content is not a valid URL or JSON: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing tabs from clipboard: $e');
    }
  }

  Future<void> _exportAllUrls() async {
    try {
      // Get export data
      final exportData = _ref.read(appNotifier.notifier).exportData();

      // Convert to JSON
      final jsonString = jsonEncode(exportData.toJson());

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: jsonString));

      debugPrint('Exported ${exportData.urls.length} URLs to clipboard');
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
    }
  }
}

final systemTrayManagerProvider = Provider<SystemTrayManager>((ref) {
  return SystemTrayManager(ref);
});
