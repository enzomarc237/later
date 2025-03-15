import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_tray/system_tray.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class SystemTrayManager {
  final SystemTray _systemTray = SystemTray();
  final ProviderRef _ref;

  SystemTrayManager(this._ref);

  Future<void> initSystemTray() async {
    final settings = _ref.read(settingsNotifier);
    if (!settings.showSystemTrayIcon) return;

    // We first init the systray menu
    String iconPath = Platform.isWindows
        ? 'assets/app_icon.ico'
        : 'assets/app_icon.png';
    
    await _systemTray.initSystemTray("Later", iconPath: iconPath);

    // Create context menu items
    List<MenuItem> items = [
      MenuItem(
        label: 'Open Later',
        onClicked: () => _showApp(),
      ),
      MenuItem.separator(),
      MenuItem(
        label: 'Import Tabs from Clipboard',
        onClicked: () => _importTabsFromClipboard(),
      ),
      MenuItem.separator(),
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
      if (eventName == "click") {
        _showApp();
      } else if (eventName == "right-click") {
        _systemTray.popUpContextMenu();
      }
    });
  }

  void _showApp() {
    // This would typically use a platform channel to show the app
    // For now, we'll just print a message
    debugPrint("Show app");
  }

  Future<void> _importTabsFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!;
        
        // Try to parse as JSON
        try {
          // This is a placeholder for actual implementation
          // In a real implementation, we would parse the JSON and import the tabs
          _ref.read(appNotifier.notifier).addUrl(
                UrlItem(
                  url: text,
                  title: 'Imported from clipboard',
                  categoryId: _ref.read(appNotifier).categories.isNotEmpty
                      ? _ref.read(appNotifier).categories.first.id
                      : '',
                ),
              );
        } catch (e) {
          // If not valid JSON, just import as a single URL
          if (text.startsWith('http')) {
            _ref.read(appNotifier.notifier).addUrl(
                  UrlItem(
                    url: text,
                    title: 'Imported from clipboard',
                    categoryId: _ref.read(appNotifier).categories.isNotEmpty
                        ? _ref.read(appNotifier).categories.first.id
                        : '',
                  ),
                );
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing tabs from clipboard: $e');
    }
  }
}

final systemTrayManagerProvider = Provider<SystemTrayManager>((ref) {
  return SystemTrayManager(ref);
});