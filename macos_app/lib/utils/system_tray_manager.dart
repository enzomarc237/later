import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

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
    String iconPath = Platform.isWindows
        ? 'assets/icons/mac256.png'
        : 'assets/icons/mac256.png';

    await _systemTray.initSystemTray(
        title: "",
        iconPath: iconPath,
        toolTip: "Later Bookmarker is running in background");

    // Create context menu items
    final List<MenuItem> items = [
      MenuItem(
        label: 'Open Later App',
        onClicked: () => _showApp(),
      ),
      MenuItem(label: '--------------'),
    ];

    // Add quick actions
    items.add(MenuItem(
      label: 'Add URL from Clipboard',
      onClicked: () => _addUrlFromClipboard(),
    ));

    items.add(MenuItem(
      label: 'Import Tabs from Clipboard',
      onClicked: () => _importTabsFromClipboard(),
    ));

    items.add(MenuItem(
      label: 'Validate All URLs',
      onClicked: () => _validateAllUrls(),
    ));

    items.add(MenuItem(label: '--------------'));

    // Add import/export options
    items.add(MenuItem(
      label: 'Export All URLs to Clipboard',
      onClicked: () => _exportAllUrls(),
    ));

    items.add(MenuItem(
      label: 'Export All URLs to File',
      onClicked: () => _exportAllUrlsToFile(),
    ));

    // Add categories if available
    final categories = _ref.read(appNotifier).categories;
    if (categories.isNotEmpty) {
      items.add(MenuItem(label: '--------------'));
      items.add(MenuItem(label: 'Add URL to Category:'));

      // Add menu items for each category (limited to top 5 for usability)
      for (int i = 0; i < categories.length && i < 5; i++) {
        final category = categories[i];
        items.add(MenuItem(
          label: '  ${category.name}',
          onClicked: () => _addUrlToCategory(category.id),
        ));
      }
    }

    // Add remaining items
    items.addAll([
      MenuItem(label: '--------------'),
      MenuItem(
        label: 'Settings',
        onClicked: () => _openSettings(),
      ),
      MenuItem(
        label: 'Exit',
        onClicked: () => _exitApp(),
      ),
    ]);

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

  // Add a URL from clipboard to a specific category
  Future<void> _addUrlToCategory(String categoryId) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!.trim();

        // Check if it's a valid URL
        if (text.startsWith('http://') ||
            text.startsWith('https://') ||
            Uri.tryParse(text)?.hasAuthority == true) {
          // Create a new URL item
          final newUrl = UrlItem(
            url: text,
            title: text, // Will be updated with metadata
            categoryId: categoryId,
          );

          // Add the URL and fetch metadata
          await _ref
              .read(appNotifier.notifier)
              .addUrl(newUrl, fetchMetadata: true);

          // Show notification
          final category = _ref
              .read(appNotifier)
              .categories
              .firstWhere((c) => c.id == categoryId);
          _showNotification(
            'URL Added',
            'Added URL to category: ${category.name}',
          );
        } else {
          _showNotification(
            'Invalid URL',
            'The clipboard content is not a valid URL',
          );
        }
      } else {
        _showNotification(
          'No URL Found',
          'No text found in clipboard',
        );
      }
    } catch (e) {
      debugPrint('Error adding URL to category: $e');
      _showNotification(
        'Error',
        'Failed to add URL to category',
      );
    }
  }

  // Add a URL from clipboard
  Future<void> _addUrlFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!.trim();

        // Check if it's a valid URL
        if (text.startsWith('http://') ||
            text.startsWith('https://') ||
            Uri.tryParse(text)?.hasAuthority == true) {
          // Get default category
          final appState = _ref.read(appNotifier);
          final categoryId = appState.selectedCategoryId ??
              (appState.categories.isNotEmpty
                  ? appState.categories.first.id
                  : '');

          // Create a new URL item
          final newUrl = UrlItem(
            url: text,
            title: text, // Will be updated with metadata
            categoryId: categoryId,
          );

          // Add the URL and fetch metadata
          await _ref
              .read(appNotifier.notifier)
              .addUrl(newUrl, fetchMetadata: true);

          // Show notification
          _showNotification(
            'URL Added',
            'Added URL from clipboard',
          );
        } else {
          _showNotification(
            'Invalid URL',
            'The clipboard content is not a valid URL',
          );
        }
      } else {
        _showNotification(
          'No URL Found',
          'No text found in clipboard',
        );
      }
    } catch (e) {
      debugPrint('Error adding URL from clipboard: $e');
      _showNotification(
        'Error',
        'Failed to add URL from clipboard',
      );
    }
  }

  // Validate all URLs
  Future<void> _validateAllUrls() async {
    try {
      // Show app window
      await _showApp();

      // Start validation
      _ref.read(appNotifier.notifier).validateAllUrls();

      // Show notification
      _showNotification(
        'Validation Started',
        'URL validation has started in the background',
      );
    } catch (e) {
      debugPrint('Error validating URLs: $e');
      _showNotification(
        'Error',
        'Failed to start URL validation',
      );
    }
  }

  // Export all URLs to a file
  Future<void> _exportAllUrlsToFile() async {
    try {
      // Show app window
      await _showApp();

      // Show export dialog
      await windowManager.show();
      await windowManager.focus();

      // Show notification
      _showNotification(
        'Export Started',
        'Please select export options in the app window',
      );
    } catch (e) {
      debugPrint('Error exporting URLs to file: $e');
      _showNotification(
        'Export Failed',
        'Failed to export URLs to file',
      );
    }
  }

  // Open settings
  Future<void> _openSettings() async {
    try {
      // Show app window
      await _showApp();

      // Navigate to settings
      // This will be handled by the app window
    } catch (e) {
      debugPrint('Error opening settings: $e');
    }
  }

  void _showNotification(String title, String body) {
    try {
      DialogService.showNotification(title, body);
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
          if (jsonData.containsKey('urls') &&
              jsonData.containsKey('exportedAt')) {
            final importData = ExportData.fromJson(jsonData);

            // Show application window if minimized
            await windowManager.show();

            // Show app window
            await windowManager.show();
            await windowManager.focus();

            // In a real implementation, you would show an import dialog
            final selectedUrls = importData.urls;

            if (selectedUrls.isNotEmpty) {
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
            final urlsData =
                (jsonData['urls'] as List).cast<Map<String, dynamic>>();

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

            // Show app window
            await windowManager.show();
            await windowManager.focus();

            // In a real implementation, you would show an import dialog
            final selectedUrls = urls;

            if (selectedUrls.isNotEmpty) {
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
                    categoryId: _ref.read(appNotifier).categories.isNotEmpty
                        ? _ref.read(appNotifier).categories.first.id
                        : '',
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
