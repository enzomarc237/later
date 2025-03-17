import 'package:flutter/material.dart';

import '../models/url_item.dart';
import '../pages/import_dialog.dart';

/// A service for showing dialogs from anywhere in the app.
class DialogService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Shows the import URLs dialog.
  ///
  /// Returns the selected URLs with updated category IDs, or null if the dialog was cancelled.
  static Future<List<UrlItem>?> showImportUrlsDialog(
    List<UrlItem> urls, {
    String initialCategoryName = '',
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('DialogService: No valid context available');
      return null;
    }

    return await showMacosAlertDialog<List<UrlItem>>(
      context: context,
      builder: (_) => ImportUrlsDialog(
        urls: urls,
        initialCategoryName: initialCategoryName,
      ),
    );
  }
}