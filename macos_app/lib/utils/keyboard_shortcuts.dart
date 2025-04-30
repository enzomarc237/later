import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/url_item.dart';
import '../models/category.dart';
import '../pages/settings_page.dart';
import '../providers/providers.dart';
import '../utils/dialog_service.dart';

/// A class that defines and handles keyboard shortcuts for the app.
class KeyboardShortcuts {
  /// Singleton instance
  static final KeyboardShortcuts _instance = KeyboardShortcuts._internal();
  factory KeyboardShortcuts() => _instance;
  KeyboardShortcuts._internal();

  /// Map of keyboard shortcuts to their descriptions
  static final Map<ShortcutActivator, String> shortcutDescriptions = {
    // Application shortcuts
    const SingleActivator(LogicalKeyboardKey.comma, meta: true): 'Preferences',
    const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): 'Quit Later',

    // Navigation shortcuts
    const SingleActivator(LogicalKeyboardKey.keyH): 'Go to Home',
    const SingleActivator(LogicalKeyboardKey.keyS): 'Go to Settings',
    const SingleActivator(LogicalKeyboardKey.escape): 'Exit Selection Mode',

    // URL management shortcuts
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true): 'New URL',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
        'Edit Selected URL',
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        'Delete Selected URL',
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true):
        'Copy URL to Clipboard',
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
        'Open URL in Browser',
    const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
        'Bulk Open Selected URLs',
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
        'Select All URLs',

    // Category management shortcuts
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
        'New Category',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        'Edit Selected Category',
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
        'Delete Selected Category',
    const SingleActivator(LogicalKeyboardKey.keyM, meta: true):
        'Move Selected URLs to Category',

    // Search shortcut
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        'Focus Search Field',
    const SingleActivator(LogicalKeyboardKey.keyG, meta: true): 'Find Next',
    const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true):
        'Find Previous',

    // Import/Export shortcuts
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true): 'Import URLs',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, alt: true):
        'Export URLs',

    // View shortcuts
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true): 'Refresh',
    const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
        'Toggle Sidebar',
    const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
        'Toggle Selection Mode',
  };

  /// Handle keyboard shortcuts
  static Map<ShortcutActivator, VoidCallback> getApplicationShortcuts(
      BuildContext context, WidgetRef ref) {
    final appNotifierRef = ref.read(appNotifier.notifier);
    final appState = ref.read(appNotifier);

    return {
      // Application shortcuts
      const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
        // Open Preferences
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
      const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): () {
        // Quit application
        SystemNavigator.pop();
      },

      // Navigation shortcuts
      const SingleActivator(LogicalKeyboardKey.keyH): () {
        // Go to Home - already on home, so just clear selected category
        Navigator.of(context)
            .popUntil((route) => route.navigator!.canPop() == false);
        appNotifierRef.selectCategory(null);
      },
      const SingleActivator(LogicalKeyboardKey.keyS): () {
        // Go to Settings
        Navigator.of(context).pushNamed('/settings');
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        // Exit selection mode if active
        if (appState.selectionMode) {
          appNotifierRef.toggleSelectionMode();
        }
      },

      // URL management shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
        // New URL - show add URL dialog
        _showAddUrlDialog(context, ref);
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () {
        // Edit selected URL - show edit URL dialog
        if (appState.selectedUrlIds.isNotEmpty) {
          final selectedUrl = appState.urls.firstWhere(
            (url) => appState.selectedUrlIds.contains(url.id),
            orElse: () => UrlItem(
                id: '',
                url: '',
                title: '',
                categoryId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );
          if (selectedUrl.id.isNotEmpty) {
            _showEditUrlDialog(context, selectedUrl, ref);
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
        // Delete selected URL - show delete URL dialog
        if (appState.selectedUrlIds.isNotEmpty) {
          _showDeleteUrlConfirmation(context, ref);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true):
          () {
        // Copy URL to clipboard
        if (appState.selectedUrlIds.isNotEmpty) {
          final selectedUrl = appState.urls.firstWhere(
            (url) => appState.selectedUrlIds.contains(url.id),
            orElse: () => UrlItem(
                id: '',
                url: '',
                title: '',
                categoryId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );
          if (selectedUrl.id.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: selectedUrl.url));
            LocalNotification(
              title: 'URL Copied',
              body: 'URL copied to clipboard',
            ).show();
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () {
        // Open URL in browser
        if (appState.selectedUrlIds.isNotEmpty) {
          final selectedUrl = appState.urls.firstWhere(
            (url) => appState.selectedUrlIds.contains(url.id),
            orElse: () => UrlItem(
                id: '',
                url: '',
                title: '',
                categoryId: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );
          if (selectedUrl.id.isNotEmpty) {
            _openUrlInBrowser(context, selectedUrl.url);
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
        // Bulk open selected URLs
        if (appState.selectedUrlIds.isNotEmpty) {
          _showOpenSelectedUrlsDialog(context, ref);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () {
        // Select all URLs
        appNotifierRef.selectAllVisibleUrls();
      },

      // Category management shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
          () {
        // New Category - show add category dialog
        _showAddCategoryDialog(context, ref);
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
          () {
        // Edit selected Category - show edit category dialog
        if (appState.selectedCategoryId != null) {
          final selectedCategory = appState.categories.firstWhere(
            (category) => category.id == appState.selectedCategoryId,
            orElse: () => Category(
                id: '',
                name: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );
          if (selectedCategory.id.isNotEmpty) {
            _showEditCategoryDialog(context, selectedCategory, ref);
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
          () {
        // Delete selected Category
        if (appState.selectedCategoryId != null) {
          _showDeleteCategoryConfirmation(context, ref);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyM, meta: true): () {
        // Move selected URLs to category
        if (appState.selectedUrlIds.isNotEmpty) {
          _showMoveSelectedUrlsDialog(context, ref);
        }
      },

      // Search shortcut
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
        // Focus search field
        // This would need to be implemented in AppNotifier
        // For now, just show a notification
        LocalNotification(
          title: 'Search',
          body: 'Search shortcut pressed',
        ).show();
      },

      // Import/Export shortcuts
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
        // Import URLs
        DialogService.handleImport(context, ref);
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true, alt: true):
          () {
        // Export URLs
        DialogService.handleExport(context, ref);
      },

      // View shortcuts
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
        // Refresh
        // This would need to be implemented in AppNotifier
        // For now, just show a notification
        LocalNotification(
          title: 'Refresh',
          body: 'Refresh shortcut pressed',
        ).show();
      },
      const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () {
        // Toggle sidebar
        MacosWindowScope.of(context).toggleSidebar();
      },
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true): () {
        // Toggle selection mode
        appNotifierRef.toggleSelectionMode();
      },
    };
  }

  // Helper methods for keyboard shortcut actions

  /// Show dialog to add a new URL
  static void _showAddUrlDialog(BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show dialog to edit a URL
  static void _showEditUrlDialog(
      BuildContext context, UrlItem url, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show confirmation dialog to delete URLs
  static void _showDeleteUrlConfirmation(BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }

  /// Open URL in browser
  static void _openUrlInBrowser(BuildContext context, String urlString) async {
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          DialogService.showErrorDialog(
              context, 'Open Failed', 'Could not open URL: $urlString');
        }
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
      if (context.mounted) {
        DialogService.showErrorDialog(
            context, 'Open Failed', 'Failed to open URL: $urlString');
      }
    }
  }

  /// Show dialog to open selected URLs
  static void _showOpenSelectedUrlsDialog(BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show dialog to add a new category
  static void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show dialog to edit a category
  static void _showEditCategoryDialog(
      BuildContext context, Category category, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show confirmation dialog to delete a category
  static void _showDeleteCategoryConfirmation(
      BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }

  /// Show dialog to move selected URLs to a category
  static void _showMoveSelectedUrlsDialog(BuildContext context, WidgetRef ref) {
    // Implementation will be added
  }
}

/// Provider for keyboard shortcuts
final keyboardShortcutsProvider = Provider<KeyboardShortcuts>((ref) {
  return KeyboardShortcuts();
});
