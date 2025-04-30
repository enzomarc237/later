// import 'dart:io' show Process;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/url_item.dart';
import '../pages/settings_page.dart';
import '../providers/providers.dart';
import '../utils/dialog_service.dart';
import '../utils/keyboard_shortcuts.dart';

/// A utility class for building the platform menu bar.
class LaterPlatformMenu {
  /// Builds a platform menu bar for macOS.
  static PlatformMenuBar build(BuildContext context, WidgetRef ref) {
    final appNotifierRef = ref.read(appNotifier.notifier);
    final appState = ref.read(appNotifier);

    return PlatformMenuBar(
      menus: [
        // App menu
        PlatformMenu(
          label: 'Later',
          menus: [
            PlatformMenuItem(
              label: 'About Later',
              onSelected: () {
                _showAboutDialog(context);
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Preferences...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Quit Later',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () {
                SystemNavigator.pop();
              },
            ),
          ],
        ),

        // File menu
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New URL...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
              onSelected: () {
                // Show add URL dialog
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'New Category...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN,
                  meta: true, shift: true),
              onSelected: () {
                // Show add category dialog
                // Implementation will be added
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Import Bookmarks...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyI, meta: true),
              onSelected: () {
                DialogService.handleImport(context, ref);
              },
            ),
            PlatformMenuItem(
              label: 'Export Bookmarks...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyE,
                  meta: true, alt: true),
              onSelected: () {
                DialogService.handleExport(context, ref);
              },
            ),
          ],
        ),

        // Edit menu
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelected: () {
                // Standard cut action
                // This is handled by the system
              },
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelected: () {
                // Standard copy action
                // This is handled by the system
              },
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelected: () {
                // Standard paste action
                // This is handled by the system
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Select All',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              onSelected: () {
                appNotifierRef.selectAllVisibleUrls();
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Find...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
              onSelected: () {
                // Focus search field
                // Implementation will be added
              },
            ),
          ],
        ),

        // View menu
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Toggle Sidebar',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
              onSelected: () {
                MacosWindowScope.of(context).toggleSidebar();
              },
            ),
            PlatformMenuItem(
              label: 'Toggle Selection Mode',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyT, meta: true),
              onSelected: () {
                appNotifierRef.toggleSelectionMode();
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Refresh',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () {
                // Refresh data
                // Implementation will be added
              },
            ),
          ],
        ),

        // URL menu
        PlatformMenu(
          label: 'URL',
          menus: [
            PlatformMenuItem(
              label: 'Open in Browser',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onSelected: () {
                // Open selected URL in browser
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'Bulk Open Selected URLs',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyB, meta: true),
              onSelected: () {
                // Bulk open selected URLs
                final selectedUrls = appState.urls
                    .where(
                      (url) => appState.selectedUrlIds.contains(url.id),
                    )
                    .toList();

                if (selectedUrls.isNotEmpty) {
                  _bulkOpenUrls(selectedUrls);
                }
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Copy URL to Clipboard',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyC,
                  meta: true, shift: true),
              onSelected: () {
                // Copy URL to clipboard
                // Implementation will be added
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Edit URL...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
              onSelected: () {
                // Edit selected URL
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'Move to Category...',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
              onSelected: () {
                // Move selected URLs to category
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'Delete URL',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
              onSelected: () {
                // Delete selected URL
                // Implementation will be added
              },
            ),
          ],
        ),

        // Category menu
        PlatformMenu(
          label: 'Category',
          menus: [
            PlatformMenuItem(
              label: 'Edit Category...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyE,
                  meta: true, shift: true),
              onSelected: () {
                // Edit selected category
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'Delete Category',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyD,
                  meta: true, shift: true),
              onSelected: () {
                // Delete selected category
                // Implementation will be added
              },
            ),
          ],
        ),

        // Window menu
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItem(
              label: 'Minimize',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
              onSelected: () {
                // Minimize window
                // This is handled by the system
              },
            ),
            PlatformMenuItem(
              label: 'Zoom',
              onSelected: () {
                // Zoom window
                // This is handled by the system
              },
            ),
            PlatformMenuItem(label: '-'),
            PlatformMenuItem(
              label: 'Bring All to Front',
              onSelected: () {
                // Bring all windows to front
                // This is handled by the system
              },
            ),
          ],
        ),

        // Help menu
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: 'Later Help',
              shortcut: const SingleActivator(LogicalKeyboardKey.slash,
                  meta: true, shift: true),
              onSelected: () {
                // Show help
                // Implementation will be added
              },
            ),
            PlatformMenuItem(
              label: 'Keyboard Shortcuts',
              onSelected: () {
                _showKeyboardShortcutsDialog(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Shows the about dialog.
  static void _showAboutDialog(BuildContext context) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
        title: const Text('About Later'),
        message: const Text(
          'Later is a bookmark manager for macOS.\n\n'
          'Version: 1.0.0\n'
          '© 2023 Later App',
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

  /// Shows the keyboard shortcuts dialog.
  static void _showKeyboardShortcutsDialog(BuildContext context) {
    final shortcuts = KeyboardShortcuts.shortcutDescriptions;

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          Icons.keyboard,
          size: 56,
          color: MacosColors.systemBlueColor,
        ),
        title: const Text('Keyboard Shortcuts'),
        message: SizedBox(
          width: 500,
          height: 400,
          child: ListView(
            children: [
              _buildShortcutCategory(
                  'Application',
                  [
                    const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'Navigation',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyH),
                    const SingleActivator(LogicalKeyboardKey.keyS),
                    const SingleActivator(LogicalKeyboardKey.escape),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'URL Management',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyC,
                        meta: true, shift: true),
                    const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyB, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'Category Management',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyN,
                        meta: true, shift: true),
                    const SingleActivator(LogicalKeyboardKey.keyE,
                        meta: true, shift: true),
                    const SingleActivator(LogicalKeyboardKey.keyD,
                        meta: true, shift: true),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'Search',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyG, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyG,
                        meta: true, shift: true),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'Import/Export',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyI, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyE,
                        meta: true, alt: true),
                  ],
                  shortcuts),
              _buildShortcutCategory(
                  'View',
                  [
                    const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
                    const SingleActivator(LogicalKeyboardKey.keyT, meta: true),
                  ],
                  shortcuts),
            ],
          ),
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

  /// Builds a category of shortcuts for the keyboard shortcuts dialog.
  static Widget _buildShortcutCategory(
    String categoryName,
    List<ShortcutActivator> shortcutKeys,
    Map<ShortcutActivator, String> shortcuts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            categoryName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        ...shortcutKeys.map((key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(shortcuts[key] ?? ''),
                  _buildShortcutText(key),
                ],
              ),
            )),
        const Divider(),
      ],
    );
  }

  /// Opens multiple URLs in the default browser
  static Future<void> _bulkOpenUrls(List<UrlItem> urls) async {
    if (urls.isEmpty) return;

    // Show confirmation dialog if there are many URLs
    if (urls.length > 5) {
      final context = DialogService.navigatorKey.currentContext;
      if (context != null) {
        final confirmed = await DialogService.showConfirmationDialog(
          context,
          'Open Multiple URLs',
          'Are you sure you want to open ${urls.length} URLs in your browser?',
          confirmText: 'Open All',
        );

        if (!confirmed) return;
      }
    }

    // Open each URL
    for (final url in urls) {
      try {
        final uri = Uri.parse(url.url);
        await launchUrl(uri);
        // Add a small delay to prevent overwhelming the browser
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Error opening URL ${url.url}: $e');
      }
    }

    // Show notification
    DialogService.showNotification(
      'URLs Opened',
      'Opened ${urls.length} URLs in your browser',
    );
  }

  /// Builds a text representation of a keyboard shortcut.
  static Widget _buildShortcutText(ShortcutActivator shortcut) {
    if (shortcut is SingleActivator) {
      final buffer = StringBuffer();

      if (shortcut.meta) {
        buffer.write('⌘');
      }

      if (shortcut.shift) {
        buffer.write('⇧');
      }

      if (shortcut.alt) {
        buffer.write('⌥');
      }

      if (shortcut.control) {
        buffer.write('⌃');
      }

      // Add the key
      if (shortcut.trigger == LogicalKeyboardKey.keyA) {
        buffer.write('A');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyB) {
        buffer.write('B');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyC) {
        buffer.write('C');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyD) {
        buffer.write('D');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyE) {
        buffer.write('E');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyF) {
        buffer.write('F');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyG) {
        buffer.write('G');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyH) {
        buffer.write('H');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyI) {
        buffer.write('I');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyJ) {
        buffer.write('J');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyK) {
        buffer.write('K');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyL) {
        buffer.write('L');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyM) {
        buffer.write('M');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyN) {
        buffer.write('N');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyO) {
        buffer.write('O');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyP) {
        buffer.write('P');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyQ) {
        buffer.write('Q');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyR) {
        buffer.write('R');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyS) {
        buffer.write('S');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyT) {
        buffer.write('T');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyU) {
        buffer.write('U');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyV) {
        buffer.write('V');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyW) {
        buffer.write('W');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyX) {
        buffer.write('X');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyY) {
        buffer.write('Y');
      } else if (shortcut.trigger == LogicalKeyboardKey.keyZ) {
        buffer.write('Z');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit1) {
        buffer.write('1');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit2) {
        buffer.write('2');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit3) {
        buffer.write('3');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit4) {
        buffer.write('4');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit5) {
        buffer.write('5');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit6) {
        buffer.write('6');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit7) {
        buffer.write('7');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit8) {
        buffer.write('8');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit9) {
        buffer.write('9');
      } else if (shortcut.trigger == LogicalKeyboardKey.digit0) {
        buffer.write('0');
      } else if (shortcut.trigger == LogicalKeyboardKey.comma) {
        buffer.write(',');
      } else if (shortcut.trigger == LogicalKeyboardKey.period) {
        buffer.write('.');
      } else if (shortcut.trigger == LogicalKeyboardKey.slash) {
        buffer.write('/');
      } else if (shortcut.trigger == LogicalKeyboardKey.escape) {
        buffer.write('⎋');
      } else {
        buffer.write(shortcut.trigger.keyLabel);
      }

      return Text(
        buffer.toString(),
        style: const TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return const Text('');
  }
}
