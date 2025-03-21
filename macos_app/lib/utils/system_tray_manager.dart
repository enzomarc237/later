import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../models/category.dart';
import '../models/export_data.dart';
import '../models/url_item.dart';
import '../providers/providers.dart';
import 'dialog_service.dart';

class SystemTrayManager with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Ref _ref;

  SystemTrayManager(this._ref);

  Future<void> initSystemTray() async {
    final settings = _ref.read(settingsNotifier);

    // Initialize window manager
    await windowManager.ensureInitialized();

    // Add window listener to handle window events
    windowManager.addListener(this);

    // Set window options
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('Later');

    if (!settings.showSystemTrayIcon) return;

    // Initialize system tray
    String iconPath = Platform.isWindows ? 'assets/icons/mac256.png' : 'assets/icons/mac256.png';

    await _systemTray.initSystemTray(title: "", iconPath: iconPath, toolTip: "Later Bookmarker is running in background");

    // Create context menu items
    List<MenuItem> items = [
      MenuItem(
        label: 'Open Later App',
        onClicked: () => _showApp(),
      ),
      MenuItem(label: '--------------'),
      MenuItem(
        label: 'Import Tabs from Clipboard',
        onClicked: () => _importTabsFromClipboard(),
      ),
      MenuItem(
        label: 'Export All URLs',
        onClicked: () => _exportAllUrls(),
      ),
      MenuItem(
        label: 'Exit',
        onClicked: () => _exitApp(),
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

  // Window manager listener methods
  @override
  void onWindowClose() async {
    // Hide the window instead of closing it
    await _hideApp();

    // Show notification that app is still running
    _showNotification(
      'Later is still running',
      'The app is now minimized to the system tray. Click the icon to open it again.',
    );
  }

  Future<void> _showApp() async {
    try {
      bool isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }
      await windowManager.focus();

      _showNotification(
        'Later App',
        'Welcome back to Later!',
      );
    } catch (e) {
      debugPrint('Error showing app: $e');
    }
  }

  Future<void> _hideApp() async {
    try {
      await windowManager.hide();
      // On macOS, this removes the app from the dock
      if (Platform.isMacOS) {
        await windowManager.setSkipTaskbar(true);
      }
    } catch (e) {
      debugPrint('Error hiding app: $e');
    }
  }

  Future<void> _exitApp() async {
    try {
      // Force close the app
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Error exiting app: $e');
      exit(0); // Fallback to exit if window manager fails
    }
  }

  void _showNotification(String title, String body) {
    try {
      LocalNotification notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.show();
    } catch (e) {
      debugPrint('Error showing notification: $e');
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

            // Show application window if minimized
            await windowManager.show();

            // Show import dialog with the URLs
            final selectedUrls = await DialogService.showImportUrlsDialog(
              importData.urls,
              initialCategoryName: importData.categories.isNotEmpty ? importData.categories.first.name : 'Imported',
            );

            if (selectedUrls != null && selectedUrls.isNotEmpty) {
              // Import only the selected URLs
              for (final url in selectedUrls) {
                _ref.read(appNotifier.notifier).addUrl(url);
              }

              _showNotification(
                'URLs Imported',
                'Imported ${selectedUrls.length} URLs from clipboard',
              );
              debugPrint('Imported ${selectedUrls.length} URLs from clipboard');
            } else {
              debugPrint('Import cancelled or no URLs selected');
            }
          }
          // Check if it's from browser extension (just URLs array)
          else if (jsonData.containsKey('urls')) {
            final urlsData = (jsonData['urls'] as List).cast<Map<String, dynamic>>();
            final appState = _ref.read(appNotifier);

            // Default category
            String defaultCategoryName = 'Imported';
            if (appState.categories.isNotEmpty) {
              defaultCategoryName = appState.categories.first.name;
            }

            // Create URL items
            final urls = <UrlItem>[];
            for (final urlData in urlsData) {
              final url = UrlItem(
                url: urlData['url'] as String,
                title: urlData['title'] as String,
                description: urlData['description'] as String?,
                categoryId: '', // Will be set by the dialog
              );
              urls.add(url);
            }

            // Show import dialog
            final selectedUrls = await DialogService.showImportUrlsDialog(
              urls,
              initialCategoryName: defaultCategoryName,
            );

            if (selectedUrls != null && selectedUrls.isNotEmpty) {
              // Import only the selected URLs
              for (final url in selectedUrls) {
                _ref.read(appNotifier.notifier).addUrl(url);
              }

              _showNotification(
                'URLs Imported',
                'Imported ${selectedUrls.length} URLs from clipboard',
              );
              debugPrint('Imported ${selectedUrls.length} URLs from clipboard');
            } else {
              debugPrint('Import cancelled or no URLs selected');
            }
          }
        } catch (e) {
          // If not valid JSON, just import as a single URL
          if (text.startsWith('http')) {
            // For single URLs, we don't show the dialog
            _ref.read(appNotifier.notifier).addUrl(
                  UrlItem(
                    url: text,
                    title: 'Imported from clipboard',
                    categoryId: _ref.read(appNotifier).categories.isNotEmpty ? _ref.read(appNotifier).categories.first.id : '',
                  ),
                );
            _showNotification(
              'URL Imported',
              'Imported URL from clipboard',
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

      _showNotification(
        'URLs Exported',
        'Exported ${exportData.urls.length} URLs to clipboard',
      );
      debugPrint('Exported ${exportData.urls.length} URLs to clipboard');
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
    }
  }
}

final systemTrayManagerProvider = Provider<SystemTrayManager>((ref) {
  return SystemTrayManager(ref);
});
