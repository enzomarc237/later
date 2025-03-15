import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_tray/system_tray.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class SystemTrayManager {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  final ProviderRef _ref;

  SystemTrayManager(this._ref);

  Future<void> initSystemTray() async {
    final settings = _ref.read(settingsNotifier);
    if (!settings.showSystemTrayIcon) return;

    // We first init the systray menu
    await _systemTray.initSystemTray(
      title: "Later",
      iconPath: Platform.isWindows
          ? 'assets/app_icon.ico'
          : 'assets/app_icon.png',
    );

    // Create context menu
    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Open Later',
        onClicked: (menuItem) => _appWindow.show(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Import Tabs from Clipboard',
        onClicked: (menuItem) => _importTabsFromClipboard(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) => exit(0),
      ),
    ]);

    // Set the context menu
    await _systemTray.setContextMenu(menu);

    // Handle system tray events
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _appWindow.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
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
      print('Error importing tabs from clipboard: $e');
    }
  }
}

final systemTrayManagerProvider = Provider<SystemTrayManager>((ref) {
  return SystemTrayManager(ref);
});