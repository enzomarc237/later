import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/keyboard_shortcuts.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appNotifier);
    final settings = ref.watch(settingsNotifier);
    final theme = MacosTheme.of(context);

    return MacosScaffold(
      backgroundColor: theme.canvasColor,
      toolBar: ToolBar(
        leading: MacosIconButton(
          icon: MacosIcon(
            CupertinoIcons.arrow_left,
            size: 20,
            color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Settings'),
        titleWidth: 150,
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildThemeSelector(context, ref, settings),
                  const SizedBox(height: 32),
                  Text(
                    'Data Storage',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildDataFolderSelector(context, ref, settings),
                  const SizedBox(height: 16),
                  _buildClearDataButton(context, ref),
                  const SizedBox(height: 32),
                  Text(
                    'Backups',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildBackupSettings(context, ref, settings),
                  const SizedBox(height: 32),
                  Text(
                    'System Tray',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildSystemTraySettings(context, ref, settings),
                  const SizedBox(height: 32),
                  Text(
                    'Keyboard Shortcuts',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildKeyboardShortcutsInfo(context),
                  const SizedBox(height: 32),
                  Text(
                    'Browser Extensions',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildBrowserExtensionsInfo(context),
                  const SizedBox(height: 32),
                  Text(
                    'About',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  MacosListTile(
                    title: const Text('Version'),
                    subtitle: Text(appState.appVersion),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme Mode',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildThemeRadioButton(context, ref, settings, ThemeMode.system, 'System'),
            const SizedBox(width: 16),
            _buildThemeRadioButton(context, ref, settings, ThemeMode.light, 'Light'),
            const SizedBox(width: 16),
            _buildThemeRadioButton(context, ref, settings, ThemeMode.dark, 'Dark'),
          ],
        ),
        const SizedBox(height: 24),

        // Custom theme selector
        _buildCustomThemeSelector(context, ref, settings),
      ],
    );
  }

  Widget _buildThemeRadioButton(BuildContext context, WidgetRef ref, Settings settings, ThemeMode mode, String label) {
    return Row(
      children: [
        MacosRadioButton<ThemeMode>(
          value: mode,
          groupValue: settings.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsNotifier.notifier).setThemeMode(value);
            }
          },
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: MacosTheme.of(context).typography.body,
        ),
      ],
    );
  }

  Widget _buildDataFolderSelector(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Folder',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MacosTheme.of(context).canvasColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: MacosColors.systemGrayColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  settings.dataFolderPath.isEmpty ? 'Default location' : settings.dataFolderPath,
                  style: MacosTheme.of(context).typography.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              onPressed: () async {
                final selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  // Test if the directory is accessible
                  final testFile = File('$selectedDirectory/.write_test');
                  try {
                    await testFile.writeAsString('test');
                    await testFile.delete();

                    // Directory is accessible, set it
                    ref.read(settingsNotifier.notifier).setDataFolderPath(selectedDirectory);
                  } catch (e) {
                    // Directory is not accessible, show warning
                    if (context.mounted) {
                      showMacosAlertDialog(
                        context: context,
                        builder: (_) => MacosAlertDialog(
                          appIcon: const MacosIcon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 56,
                            color: MacosColors.systemOrangeColor,
                          ),
                          title: const Text('Permission Error'),
                          message: Text(
                            'The app does not have permission to access the selected folder:\n\n$selectedDirectory\n\nThe app will use the default location instead. To use a custom location, please select a folder that the app has permission to access, such as a folder within your Documents directory.',
                          ),
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
                }
              },
              child: const Text('Choose Folder'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Note: The app needs full access to the selected folder. If you experience permission issues, try selecting a folder within your Documents directory.',
          style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
        ),
      ],
    );
  }

  Widget _buildClearDataButton(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clear Data',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          secondary: true,
          onPressed: () {
            _showClearDataConfirmationDialog(context, ref);
          },
          child: const Text('Clear All Data'),
        ),
        const SizedBox(height: 4),
        Text(
          'This will delete all categories and URLs',
          style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
        ),
      ],
    );
  }

  Widget _buildSystemTraySettings(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MacosCheckbox(
              value: settings.showSystemTrayIcon,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setShowSystemTrayIcon(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Show icon in system tray',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MacosCheckbox(
              value: settings.startMinimized,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setStartMinimized(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Start app minimized',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MacosCheckbox(
              value: settings.autoImportFromClipboard,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setAutoImportFromClipboard(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Auto-import URLs from clipboard',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackupSettings(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Automatic backups checkbox
        Row(
          children: [
            MacosCheckbox(
              value: settings.autoBackupEnabled,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setAutoBackupEnabled(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Enable automatic backups',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Maximum backups slider
        Text(
          'Maximum number of backups: ${settings.maxBackups}',
          style: MacosTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 300,
          child: MacosSlider(
            value: settings.maxBackups.toDouble(),
            min: 1,
            max: 50,
            onChanged: (value) {
              ref.read(settingsNotifier.notifier).setMaxBackups(value.round());
            },
          ),
        ),
        const SizedBox(height: 16),

        // Backup actions
        Row(
          children: [
            PushButton(
              controlSize: ControlSize.regular,
              onPressed: () async {
                final backupName = await ref.read(appNotifier.notifier).createBackup();
                if (backupName != null) {
                  showMacosAlertDialog(
                    context: context,
                    builder: (_) => MacosAlertDialog(
                      appIcon: const MacosIcon(
                        CupertinoIcons.check_mark_circled,
                        size: 56,
                        color: MacosColors.systemGreenColor,
                      ),
                      title: const Text('Backup Created'),
                      message: Text('Backup created successfully: $backupName'),
                      primaryButton: PushButton(
                        controlSize: ControlSize.large,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('OK'),
                      ),
                    ),
                  );
                } else {
                  showMacosAlertDialog(
                    context: context,
                    builder: (_) => MacosAlertDialog(
                      appIcon: const MacosIcon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 56,
                        color: MacosColors.systemOrangeColor,
                      ),
                      title: const Text('Backup Failed'),
                      message: const Text('Failed to create backup. Please try again.'),
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
              },
              child: const Text('Create Backup Now'),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              secondary: true,
              onPressed: () {
                _showBackupHistoryDialog(context, ref);
              },
              child: const Text('Manage Backups'),
            ),
          ],
        ),
      ],
    );
  }

  void _showBackupHistoryDialog(BuildContext context, WidgetRef ref) async {
    final backups = await ref.read(appNotifier.notifier).listBackups();
    final theme = MacosTheme.of(context);

    if (context.mounted) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: MacosIcon(
            CupertinoIcons.clock,
            size: 56,
            color: theme.primaryColor,
          ),
          title: const Text('Backup History'),
          message: SizedBox(
            width: 500,
            height: 300,
            child: backups.isEmpty
                ? const Center(child: Text('No backups found'))
                : ListView.builder(
                    itemCount: backups.length,
                    itemBuilder: (context, index) {
                      final backup = backups[index];
                      final date = backup.timestamp.toLocal();
                      final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: MacosTheme.of(context).typography.body.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    '${backup.categoriesCount} categories, ${backup.urlsCount} URLs',
                                    style: MacosTheme.of(context).typography.caption1,
                                  ),
                                ],
                              ),
                            ),
                            // Restore backup button
                            MacosIconButton(
                              icon: const MacosIcon(CupertinoIcons.arrow_counterclockwise),
                              onPressed: () {
                                // Close the backup history dialog first
                                Navigator.of(context).pop();

                                // Show confirmation dialog with a fresh context
                                if (context.mounted) {
                                  showMacosAlertDialog(
                                    context: context,
                                    builder: (dialogContext) => MacosAlertDialog(
                                      appIcon: MacosIcon(
                                        CupertinoIcons.arrow_counterclockwise,
                                        size: 56,
                                        color: theme.primaryColor,
                                      ),
                                      title: const Text('Restore Backup'),
                                      message: const Text(
                                        'Are you sure you want to restore this backup? This will replace all your current data.',
                                      ),
                                      primaryButton: PushButton(
                                        controlSize: ControlSize.large,
                                        onPressed: () async {
                                          // Close the confirmation dialog
                                          Navigator.of(dialogContext).pop();

                                          final success = await ref.read(appNotifier.notifier).restoreBackup(backup.fileName);

                                          // Show result dialog if context is still valid
                                          if (context.mounted) {
                                            showMacosAlertDialog(
                                              context: context,
                                              builder: (resultContext) => MacosAlertDialog(
                                                appIcon: MacosIcon(
                                                  success ? CupertinoIcons.check_mark_circled : CupertinoIcons.exclamationmark_triangle,
                                                  size: 56,
                                                  color: success ? MacosColors.systemGreenColor : MacosColors.systemOrangeColor,
                                                ),
                                                title: Text(success ? 'Restore Successful' : 'Restore Failed'),
                                                message: Text(
                                                  success ? 'Backup was successfully restored.' : 'Failed to restore backup. Please try again.',
                                                ),
                                                primaryButton: PushButton(
                                                  controlSize: ControlSize.large,
                                                  onPressed: () {
                                                    Navigator.of(resultContext).pop();
                                                  },
                                                  child: const Text('OK'),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Restore'),
                                      ),
                                      secondaryButton: PushButton(
                                        controlSize: ControlSize.large,
                                        secondary: true,
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            // Delete backup button
                            MacosIconButton(
                              icon: const MacosIcon(CupertinoIcons.trash),
                              onPressed: () async {
                                // Show confirmation dialog
                                showMacosAlertDialog(
                                  context: context,
                                  builder: (dialogContext) => MacosAlertDialog(
                                    appIcon: const MacosIcon(
                                      CupertinoIcons.trash,
                                      size: 56,
                                      color: MacosColors.systemRedColor,
                                    ),
                                    title: const Text('Delete Backup'),
                                    message: const Text(
                                      'Are you sure you want to delete this backup? This cannot be undone.',
                                    ),
                                    primaryButton: PushButton(
                                      controlSize: ControlSize.large,
                                      onPressed: () async {
                                        // Close the confirmation dialog
                                        Navigator.of(dialogContext).pop();

                                        // Delete the backup
                                        final success = await ref.read(appNotifier.notifier).deleteBackup(backup.fileName);

                                        // Close the backup history dialog
                                        if (context.mounted) {
                                          Navigator.of(context).pop();

                                          // Show a new backup history dialog if the context is still valid
                                          if (context.mounted) {
                                            _showBackupHistoryDialog(context, ref);
                                          }
                                        }
                                      },
                                      child: const Text('Delete'),
                                    ),
                                    secondaryButton: PushButton(
                                      controlSize: ControlSize.large,
                                      secondary: true,
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ),
      );
    }
  }

  Widget _buildBrowserExtensionsInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chrome Extension',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Text(
          'Install the Chrome extension to easily save tabs from your browser.',
          style: MacosTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          onPressed: () {
            // Open Chrome extension page
          },
          child: const Text('Install Chrome Extension'),
        ),
        const SizedBox(height: 16),
        Text(
          'Firefox Extension',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Text(
          'Install the Firefox extension to easily save tabs from your browser.',
          style: MacosTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          onPressed: () {
            // Open Firefox extension page
          },
          child: const Text('Install Firefox Extension'),
        ),
      ],
    );
  }

  Widget _buildKeyboardShortcutsInfo(BuildContext context) {
    // Group shortcuts by category
    final navigationShortcuts = <ShortcutActivator, String>{};
    final urlShortcuts = <ShortcutActivator, String>{};
    final categoryShortcuts = <ShortcutActivator, String>{};
    final otherShortcuts = <ShortcutActivator, String>{};

    KeyboardShortcuts.shortcutDescriptions.forEach((shortcut, description) {
      if (description.contains('Go to')) {
        navigationShortcuts[shortcut] = description;
      } else if (description.contains('URL')) {
        urlShortcuts[shortcut] = description;
      } else if (description.contains('Category')) {
        categoryShortcuts[shortcut] = description;
      } else {
        otherShortcuts[shortcut] = description;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation shortcuts
        if (navigationShortcuts.isNotEmpty) ...[
          Text(
            'Navigation',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          _buildShortcutsList(context, navigationShortcuts),
          const SizedBox(height: 16),
        ],

        // URL management shortcuts
        if (urlShortcuts.isNotEmpty) ...[
          Text(
            'URL Management',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          _buildShortcutsList(context, urlShortcuts),
          const SizedBox(height: 16),
        ],

        // Category management shortcuts
        if (categoryShortcuts.isNotEmpty) ...[
          Text(
            'Category Management',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          _buildShortcutsList(context, categoryShortcuts),
          const SizedBox(height: 16),
        ],

        // Other shortcuts
        if (otherShortcuts.isNotEmpty) ...[
          Text(
            'Other',
            style: MacosTheme.of(context).typography.headline,
          ),
          const SizedBox(height: 8),
          _buildShortcutsList(context, otherShortcuts),
        ],
      ],
    );
  }

  Widget _buildShortcutsList(BuildContext context, Map<ShortcutActivator, String> shortcuts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: shortcuts.entries.map((entry) {
        final shortcut = entry.key;
        final description = entry.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: _buildShortcutDisplay(context, shortcut),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  description,
                  style: MacosTheme.of(context).typography.body,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShortcutDisplay(BuildContext context, ShortcutActivator shortcut) {
    if (shortcut is SingleActivator) {
      final List<String> keys = [];

      // Add modifiers
      if (shortcut.meta) keys.add('⌘');
      if (shortcut.shift) keys.add('⇧');
      if (shortcut.alt) keys.add('⌥');
      if (shortcut.control) keys.add('⌃');

      // Add main key
      keys.add(_getKeyLabel(shortcut.trigger));

      return Row(
        children: keys.map((key) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: MacosTheme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: MacosColors.systemGrayColor.withOpacity(0.5),
                ),
              ),
              child: Text(
                key,
                style: MacosTheme.of(context).typography.body.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return const Text('Unknown shortcut');
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    // Common key mappings
    final keyLabels = {
      LogicalKeyboardKey.keyA: 'A',
      LogicalKeyboardKey.keyB: 'B',
      LogicalKeyboardKey.keyC: 'C',
      LogicalKeyboardKey.keyD: 'D',
      LogicalKeyboardKey.keyE: 'E',
      LogicalKeyboardKey.keyF: 'F',
      LogicalKeyboardKey.keyG: 'G',
      LogicalKeyboardKey.keyH: 'H',
      LogicalKeyboardKey.keyI: 'I',
      LogicalKeyboardKey.keyJ: 'J',
      LogicalKeyboardKey.keyK: 'K',
      LogicalKeyboardKey.keyL: 'L',
      LogicalKeyboardKey.keyM: 'M',
      LogicalKeyboardKey.keyN: 'N',
      LogicalKeyboardKey.keyO: 'O',
      LogicalKeyboardKey.keyP: 'P',
      LogicalKeyboardKey.keyQ: 'Q',
      LogicalKeyboardKey.keyR: 'R',
      LogicalKeyboardKey.keyS: 'S',
      LogicalKeyboardKey.keyT: 'T',
      LogicalKeyboardKey.keyU: 'U',
      LogicalKeyboardKey.keyV: 'V',
      LogicalKeyboardKey.keyW: 'W',
      LogicalKeyboardKey.keyX: 'X',
      LogicalKeyboardKey.keyY: 'Y',
      LogicalKeyboardKey.keyZ: 'Z',
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.enter: 'Return',
      LogicalKeyboardKey.escape: 'Esc',
      LogicalKeyboardKey.backspace: '⌫',
      LogicalKeyboardKey.delete: '⌦',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.arrowLeft: '←',
      LogicalKeyboardKey.arrowRight: '→',
      LogicalKeyboardKey.arrowUp: '↑',
      LogicalKeyboardKey.arrowDown: '↓',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'Page Up',
      LogicalKeyboardKey.pageDown: 'Page Down',
    };

    return keyLabels[key] ?? key.keyLabel;
  }

  Widget _buildCustomThemeSelector(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Themes',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),

        // Toggle for using custom themes
        Row(
          children: [
            MacosCheckbox(
              value: settings.useCustomTheme,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setUseCustomTheme(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Use custom theme',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Theme grid (only shown when custom themes are enabled)
        if (settings.useCustomTheme) ...[
          Text(
            'Select a theme:',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 8),

          // Grid of theme options
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeOption.predefinedThemes.map((theme) {
              final isSelected = theme.id == settings.customThemeId;

              return GestureDetector(
                onTap: () {
                  ref.read(settingsNotifier.notifier).setCustomThemeId(theme.id);
                },
                child: Container(
                  width: 100,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? MacosTheme.of(context).primaryColor : MacosColors.systemGrayColor.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: MacosTheme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Theme preview
                      Container(
                        width: 60,
                        height: 30,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Theme name
                      Text(
                        theme.name,
                        style: MacosTheme.of(context).typography.caption2.copyWith(
                              color: theme.isDark ? Colors.white : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showClearDataConfirmationDialog(BuildContext context, WidgetRef ref) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.trash,
          size: 56,
          color: MacosColors.systemRedColor,
        ),
        title: const Text('Clear All Data'),
        message: const Text(
          'Are you sure you want to clear all data? This will delete all categories and URLs and cannot be undone.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            ref.read(settingsNotifier.notifier).clearAllData();
            Navigator.of(context).pop();
          },
          child: const Text('Clear Data'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
