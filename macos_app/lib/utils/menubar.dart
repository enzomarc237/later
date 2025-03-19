import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import '../pages/settings_page.dart';

class LaterMenuBar {
  static MacosMenuBar build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final brightness = theme.brightness;
    final primaryColor = theme.primaryColor;

    return MacosMenuBar(
      menus: [
        // App Menu
        MacosMenu(
          title: 'Later',
          items: [
            MacosMenuItem(
              label: 'About Later',
              labelStyle: theme.typography.body,
              onTap: () {
                // TODO: Implement about dialog
              },
            ),
            MacosMenuItem(
              label: 'Preferences',
              labelStyle: theme.typography.body,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.comma,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
            const MacosMenuDivider(),
            MacosMenuItem(
              label: 'Quit Later',
              labelStyle: theme.typography.body,
              onTap: () {
                // TODO: Implement graceful app exit
              },
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.q,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
          ],
        ),

        // File Menu
        MacosMenu(
          title: 'File',
          items: [
            MacosMenuItem(
              label: 'Import Tabs',
              labelStyle: theme.typography.body,
              onTap: () {
                // TODO: Implement tab import
              },
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.i,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
            MacosMenuItem(
              label: 'Export URLs',
              labelStyle: theme.typography.body,
              onTap: () {
                // TODO: Implement URL export
              },
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.e,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
          ],
        ),

        // Edit Menu
        MacosMenu(
          title: 'Edit',
          items: [
            MacosMenuItem(
              label: 'Cut',
              labelStyle: theme.typography.body,
              onTap: () {},
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.x,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
            MacosMenuItem(
              label: 'Copy',
              labelStyle: theme.typography.body,
              onTap: () {},
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.c,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
            MacosMenuItem(
              label: 'Paste',
              labelStyle: theme.typography.body,
              onTap: () {},
              shortcut: MacosKeyboardShortcut(
                key: MacosKeyboardShortcutKey.v,
                modifiers: [MacosKeyboardShortcutModifier.command],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
