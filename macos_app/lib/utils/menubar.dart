import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/settings_page.dart';

/// A utility class for building the application's menu bar.
class LaterMenuBar {
  /// Builds and sets up the application's menu bar.
  static void setup(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final primaryColor = theme.primaryColor;
    final textStyle = theme.textTheme.bodyMedium;

    // Define menu items with theme-aware styling
    final aboutItem = PlatformMenuItem(
      label: 'About Later',
      onSelected: () {
        // TODO: Implement about dialog
      },
    );

    final preferencesItem = PlatformMenuItem(
      label: 'Preferences',
      shortcut: const CharacterActivator(',', meta: true),
      onSelected: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );

    final quitItem = PlatformMenuItem(
      label: 'Quit Later',
      shortcut: const CharacterActivator('q', meta: true),
      onSelected: () {
        // TODO: Implement graceful app exit
      },
    );

    final importTabsItem = PlatformMenuItem(
      label: 'Import Tabs',
      shortcut: const CharacterActivator('i', meta: true),
      onSelected: () {
        // TODO: Implement tab import
      },
    );

    final exportUrlsItem = PlatformMenuItem(
      label: 'Export URLs',
      shortcut: const CharacterActivator('e', meta: true),
      onSelected: () {
        // TODO: Implement URL export
      },
    );

    final cutItem = PlatformMenuItem(
      label: 'Cut',
      shortcut: const CharacterActivator('x', meta: true),
      onSelected: () {},
    );

    final copyItem = PlatformMenuItem(
      label: 'Copy',
      shortcut: const CharacterActivator('c', meta: true),
      onSelected: () {},
    );

    final pasteItem = PlatformMenuItem(
      label: 'Paste',
      shortcut: const CharacterActivator('v', meta: true),
      onSelected: () {},
    );

    // Define menus
    final appMenu = PlatformMenu(
      label: 'Later',
      menus: [
        aboutItem,
        preferencesItem,
        const PlatformMenuItemGroup(
          members: [],
          dividerBefore: true,
        ),
        quitItem,
      ],
    );

    final fileMenu = PlatformMenu(
      label: 'File',
      menus: [
        importTabsItem,
        exportUrlsItem,
      ],
    );

    final editMenu = PlatformMenu(
      label: 'Edit',
      menus: [
        cutItem,
        copyItem,
        pasteItem,
      ],
    );

    // Set the menu bar
    PlatformMenuBar.setMenus([
      appMenu,
      fileMenu,
      editMenu,
    ]);
  }
}