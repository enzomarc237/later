import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:local_notifier/local_notifier.dart';

import '../models/url_item.dart';
import '../pages/import_dialog.dart';
import '../pages/settings_page.dart';
import '../providers/providers.dart';
// import '../utils/import_export_manager.dart';

/// A service for showing dialogs and notifications
class DialogService {
  /// Global navigator key for accessing the navigator from anywhere
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Shows a success dialog
  static void showSuccessDialog(
      BuildContext context, String title, String message) {
    if (context.mounted) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.check_mark_circled,
            size: 56,
            color: MacosColors.systemGreenColor,
          ),
          title: Text(title),
          message: Text(message),
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

  /// Shows an error dialog
  static void showErrorDialog(
      BuildContext context, String title, String message) {
    if (context.mounted) {
      showMacosAlertDialog(
        context: context,
        builder: (_) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 56,
            color: MacosColors.systemRedColor,
          ),
          title: Text(title),
          message: Text(message),
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

  /// Shows a confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    if (!context.mounted) return false;

    final result = await showMacosAlertDialog<bool>(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.exclamationmark_triangle,
          size: 56,
          color: MacosColors.systemOrangeColor,
        ),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          color: confirmColor,
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(confirmText),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(cancelText),
        ),
      ),
    );

    return result ?? false;
  }

  /// Shows a loading dialog
  static Future<void> showLoadingDialog(
    BuildContext context,
    String title,
    String message, {
    bool barrierDismissible = false,
  }) async {
    if (!context.mounted) return;

    await showMacosAlertDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.hourglass,
          size: 56,
          color: MacosColors.systemBlueColor,
        ),
        title: Text(title),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            const ProgressCircle(),
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Shows a notification
  static void showNotification(String title, String message) {
    LocalNotification(
      title: title,
      body: message,
    ).show();
  }

  /// Shows the URL context menu
  static void showUrlContextMenu(
    BuildContext context,
    UrlItem url,
    Offset position,
    WidgetRef ref,
  ) {
    // This is a placeholder - in a real implementation, you would show a context menu
    // for the URL
  }

  /// Shows the import dialog
  static Future<List<UrlItem>?> showImportDialog(BuildContext context) async {
    if (!context.mounted) return null;

    final importedUrls = await showMacosAlertDialog<List<UrlItem>>(
      context: context,
      builder: (_) => const ImportDialog(),
    );

    if (importedUrls!.isEmpty) return null;

    if (context.mounted) {
      final selectedUrls = await showImportUrlsDialog(
        context,
        importedUrls,
      );
      return selectedUrls;
    }

    return null;
  }

  /// Shows the import URLs dialog
  static Future<List<UrlItem>?> showImportUrlsDialog(
    BuildContext context,
    List<UrlItem> urls, {
    String? initialCategoryName,
  }) async {
    if (!context.mounted) return null;

    // This is a placeholder - in a real implementation, you would show a dialog
    // that allows the user to select which URLs to import
    return urls;
  }

  /// Shows the export dialog
  static Future<Map<String, dynamic>?> showExportDialog(
      BuildContext context) async {
    if (!context.mounted) return null;

    // This is a placeholder - in a real implementation, you would show a dialog
    // that allows the user to select export options
    return {
      'format': 'json',
      'includeMetadata': true,
    };
  }

  /// Shows the settings page
  static Future<void> navigateToSettings(BuildContext context) async {
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  /// Shows the delete confirmation dialog
  static Future<bool> showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showConfirmationDialog(
      context,
      title,
      message,
      confirmText: 'Delete',
      confirmColor: MacosColors.systemRedColor,
    );
  }

  /// Handles import functionality
  static Future<void> handleImport(BuildContext context, WidgetRef ref) async {
    try {
      // Get a valid context from the navigator key if available
      final validContext = navigatorKey.currentContext ?? context;

      // Show the import dialog
      final selectedUrls = await showImportDialog(validContext);

      // If user canceled, do nothing
      if (selectedUrls == null || selectedUrls.isEmpty) return;

      // Import selected URLs
      for (final url in selectedUrls) {
        ref.read(appNotifier.notifier).addUrl(url);
      }

      // Show notification
      showNotification(
        'Import Successful',
        'Imported ${selectedUrls.length} URLs',
      );
    } catch (e) {
      debugPrint('Error importing URLs: $e');
      // Just use notification instead of dialog to avoid context issues
      showNotification('Import Failed', 'Error: $e');
    }
  }

  /// Handles export functionality
  static Future<void> handleExport(BuildContext context, WidgetRef ref) async {
    try {
      // Get a valid context from the navigator key if available
      final validContext = navigatorKey.currentContext ?? context;

      // Get export data from AppNotifier
      final exportData = ref.read(appNotifier.notifier).exportData();

      // Show export format dialog
      final exportConfig = await showExportDialog(validContext);
      if (exportConfig == null) return;

      // In a real implementation, you would use ImportExportManager to handle the export
      // This is a placeholder
      await Future.delayed(const Duration(milliseconds: 500));

      // Show notification
      showNotification(
        'Export Successful',
        'Exported ${exportData.urls.length} URLs',
      );
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
      // Just use notification instead of dialog to avoid context issues
      showNotification('Export Failed', 'Error: $e');
    }
  }
}
