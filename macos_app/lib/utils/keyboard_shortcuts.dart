import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/providers.dart';

/// A class that defines and handles keyboard shortcuts for the app.
class KeyboardShortcuts {
  /// Singleton instance
  static final KeyboardShortcuts _instance = KeyboardShortcuts._internal();
  factory KeyboardShortcuts() => _instance;
  KeyboardShortcuts._internal();

  /// Map of keyboard shortcuts to their descriptions
  static final Map<ShortcutActivator, String> shortcutDescriptions = {
    // Navigation shortcuts
    const SingleActivator(LogicalKeyboardKey.keyH): 'Go to Home',
    const SingleActivator(LogicalKeyboardKey.keyS): 'Go to Settings',

    // URL management shortcuts
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true): 'New URL',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true): 'Edit selected URL',
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true): 'Delete selected URL',
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true): 'Copy URL to clipboard',
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true): 'Open URL in browser',

    // Category management shortcuts
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): 'New Category',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true): 'Edit selected Category',

    // Search shortcut
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true): 'Focus search field',

    // Import/Export shortcuts
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true): 'Import URLs',
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, alt: true): 'Export URLs',
  };

  /// Handle keyboard shortcuts
  static Map<ShortcutActivator, VoidCallback> getApplicationShortcuts(BuildContext context, WidgetRef ref) {
    final appNotifierRef = ref.read(appNotifier.notifier);
    final appStateRef = ref.read(appNotifier);

    return {
      // Navigation shortcuts
      const SingleActivator(LogicalKeyboardKey.keyH): () {
        // Go to Home - already on home, so just clear selected category
        appNotifierRef.selectCategory(null);
      },
      const SingleActivator(LogicalKeyboardKey.keyS): () {
        // Go to Settings
        Navigator.of(context).pushNamed('/settings');
      },

      // URL management shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
        // New URL - show add URL dialog
        // This will be implemented in the HomePage
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () {
        // Edit selected URL - show edit URL dialog
        // This will be implemented in the HomePage
      },
      const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
        // Delete selected URL - show delete URL dialog
        // This will be implemented in the HomePage
      },
      const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true): () {
        // Copy URL to clipboard
        // This will be implemented in the HomePage
      },
      const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () {
        // Open URL in browser
        // This will be implemented in the HomePage
      },

      // Category management shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): () {
        // New Category - show add category dialog
        // This will be implemented in the MainView
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true): () {
        // Edit selected Category - show edit category dialog
        // This will be implemented in the MainView
      },

      // Search shortcut
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
        // Focus search field
        // This will be implemented in the MainView and HomePage
      },

      // Import/Export shortcuts
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
        // Import URLs
        // This will be implemented in the HomePage
      },
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true, alt: true): () {
        // Export URLs
        // This will be implemented in the HomePage
      },
    };
  }
}

/// Provider for keyboard shortcuts
final keyboardShortcutsProvider = Provider<KeyboardShortcuts>((ref) {
  return KeyboardShortcuts();
});
