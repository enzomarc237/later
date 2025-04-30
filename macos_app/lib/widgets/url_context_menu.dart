import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_notifier/local_notifier.dart';

import '../models/url_item.dart';
import '../providers/providers.dart';
import '../utils/url_validator.dart';

/// Shows a context menu for a URL item
void showUrlContextMenu(
  BuildContext context,
  UrlItem url,
  Offset position,
  WidgetRef ref,
) {
  final theme = MacosTheme.of(context);
  final appState = ref.read(appNotifier);
  final categories = appState.categories;

  showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: <PopupMenuEntry<void>>[
      // Open URL
      PopupMenuItem(
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.globe,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text('Open in Browser'),
          ],
        ),
        onTap: () {
          if (context.mounted) {
            _openUrlInBrowser(context, url.url);
          }
        },
      ),

      // Copy URL
      PopupMenuItem(
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.doc_on_clipboard,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text('Copy URL'),
          ],
        ),
        onTap: () {
          if (context.mounted) {
            _copyUrlToClipboard(context, url.url);
          }
        },
      ),

      // Validate URL
      PopupMenuItem(
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.checkmark_shield,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text('Validate URL'),
          ],
        ),
        onTap: () {
          if (context.mounted) {
            _validateUrl(context, url, ref);
          }
        },
      ),

      // Edit URL
      PopupMenuItem(
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.pencil,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text('Edit URL'),
          ],
        ),
        onTap: () {
          if (context.mounted) {
            _showEditUrlDialog(context, url, ref);
          }
        },
      ),

      // Move to category submenu
      if (categories.length > 1)
        PopupMenuItem(
          child: Row(
            children: [
              MacosIcon(
                CupertinoIcons.folder,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Move to Category'),
              const Spacer(),
              const MacosIcon(
                CupertinoIcons.chevron_right,
                size: 14,
              ),
            ],
          ),
          onTap: () {
            if (context.mounted) {
              _showMoveToCategoryMenu(context, url, ref);
            }
          },
        ),

      const PopupMenuDivider(),

      // Delete URL
      PopupMenuItem(
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.trash,
              color: MacosColors.systemRedColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete URL',
              style: TextStyle(
                color: MacosColors.systemRedColor,
              ),
            ),
          ],
        ),
        onTap: () {
          if (context.mounted) {
            _showDeleteUrlConfirmation(context, url, ref);
          }
        },
      ),
    ],
  );
}

// Open URL in browser
void _openUrlInBrowser(BuildContext context, String urlString) async {
  try {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        _showErrorDialog(
            context, 'Open Failed', 'Could not open URL: $urlString');
      }
    }
  } catch (e) {
    debugPrint('Error opening URL: $e');
    if (context.mounted) {
      _showErrorDialog(
          context, 'Open Failed', 'Failed to open URL: $urlString');
    }
  }
}

// Copy URL to clipboard
void _copyUrlToClipboard(BuildContext context, String url) async {
  try {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _showSuccessDialog(context, 'URL Copied', 'URL copied to clipboard.');
    }
  } catch (e) {
    debugPrint('Error copying URL to clipboard: $e');
    if (context.mounted) {
      _showErrorDialog(
          context, 'Copy Failed', 'Failed to copy URL to clipboard.');
    }
  }
}

// Validate URL
void _validateUrl(BuildContext context, UrlItem url, WidgetRef ref) async {
  // Show loading dialog
  showMacosAlertDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => MacosAlertDialog(
      appIcon: const MacosIcon(
        CupertinoIcons.hourglass,
        size: 56,
        color: MacosColors.systemBlueColor,
      ),
      title: const Text('Validating URL'),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Please wait while we validate the URL...'),
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

  // Validate the URL
  final status = await ref.read(appNotifier.notifier).validateUrl(url.id);

  // Close the loading dialog
  if (context.mounted) {
    Navigator.of(context).pop();
  }

  // Show the result
  if (context.mounted) {
    String title;
    String message;
    MacosIcon icon;

    if (status.isValid) {
      title = 'URL is Valid';
      message = 'The URL is accessible and working properly.';
      icon = const MacosIcon(
        CupertinoIcons.checkmark_circle,
        size: 56,
        color: MacosColors.systemGreenColor,
      );
    } else {
      title = 'URL is Invalid';
      message = 'The URL could not be accessed. Error: ${status.message}';
      icon = const MacosIcon(
        CupertinoIcons.exclamationmark_circle,
        size: 56,
        color: MacosColors.systemRedColor,
      );
    }

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: icon,
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

// Show edit URL dialog
void _showEditUrlDialog(BuildContext context, UrlItem url, WidgetRef ref) {
  final titleController = TextEditingController(text: url.title);
  final urlController = TextEditingController(text: url.url);
  final descriptionController =
      TextEditingController(text: url.description ?? '');
  final appState = ref.read(appNotifier);
  final categories = appState.categories;
  String? selectedCategoryId = url.categoryId;

  showMacosAlertDialog(
    context: context,
    builder: (_) => MacosAlertDialog(
      appIcon: const MacosIcon(
        CupertinoIcons.pencil,
        size: 56,
        color: MacosColors.systemBlueColor,
      ),
      title: const Text('Edit URL'),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          MacosTextField(
            placeholder: 'Title',
            controller: titleController,
          ),
          const SizedBox(height: 8),
          MacosTextField(
            placeholder: 'URL',
            controller: urlController,
          ),
          const SizedBox(height: 8),
          MacosTextField(
            placeholder: 'Description (optional)',
            controller: descriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Category:',
            style: MacosTheme.of(context).typography.body,
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setState) {
              return MacosPopupButton<String>(
                value: selectedCategoryId,
                items: categories.map((category) {
                  return MacosPopupMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCategoryId = value;
                    });
                  }
                },
              );
            },
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          if (titleController.text.trim().isNotEmpty &&
              urlController.text.trim().isNotEmpty) {
            final updatedUrl = url.copyWith(
              url: urlController.text.trim(),
              title: titleController.text.trim(),
              description: descriptionController.text.trim().isNotEmpty
                  ? descriptionController.text.trim()
                  : null,
              categoryId: selectedCategoryId,
            );
            ref.read(appNotifier.notifier).updateUrl(updatedUrl);

            // Show notification
            LocalNotification(
              title: 'URL Updated',
              body:
                  'Updated URL: ${updatedUrl.title.length > 30 ? "${updatedUrl.title.substring(0, 27)}..." : updatedUrl.title}',
            ).show();

            Navigator.of(context).pop();
          }
        },
        child: const Text('Save'),
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

// Show move to category menu
void _showMoveToCategoryMenu(BuildContext context, UrlItem url, WidgetRef ref) {
  final theme = MacosTheme.of(context);
  final appState = ref.read(appNotifier);
  final categories = appState.categories;

  showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
      MediaQuery.of(context).size.width / 2 + 1,
      MediaQuery.of(context).size.height / 2 + 1,
    ),
    items: categories.map<PopupMenuEntry<void>>((category) {
      final isCurrentCategory = category.id == url.categoryId;
      return PopupMenuItem<void>(
        enabled: !isCurrentCategory,
        onTap: isCurrentCategory
            ? null
            : () {
                final updatedUrl = url.copyWith(categoryId: category.id);
                ref.read(appNotifier.notifier).updateUrl(updatedUrl);

                // Show notification
                LocalNotification(
                  title: 'URL Moved',
                  body: 'Moved URL to category: ${category.name}',
                ).show();
              },
        child: Row(
          children: [
            MacosIcon(
              category.icon,
              color: isCurrentCategory
                  ? MacosColors.systemGrayColor
                  : (theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: TextStyle(
                color: isCurrentCategory ? MacosColors.systemGrayColor : null,
              ),
            ),
            if (isCurrentCategory) ...[
              const Spacer(),
              const MacosIcon(
                CupertinoIcons.checkmark,
                size: 14,
                color: MacosColors.systemGrayColor,
              ),
            ],
          ],
        ),
      );
    }).toList(),
  );
}

// Show delete URL confirmation
void _showDeleteUrlConfirmation(
    BuildContext context, UrlItem url, WidgetRef ref) {
  showMacosAlertDialog(
    context: context,
    builder: (_) => MacosAlertDialog(
      appIcon: const MacosIcon(
        CupertinoIcons.exclamationmark_triangle,
        size: 56,
        color: MacosColors.systemRedColor,
      ),
      title: const Text('Delete URL'),
      message: Text(
          'Are you sure you want to delete "${url.title}"? This action cannot be undone.'),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        color: MacosColors.systemRedColor,
        onPressed: () {
          ref.read(appNotifier.notifier).deleteUrl(url.id);

          // Show notification
          LocalNotification(
            title: 'URL Deleted',
            body:
                'Deleted URL: ${url.title.length > 30 ? "${url.title.substring(0, 27)}..." : url.title}',
          ).show();

          Navigator.of(context).pop();
        },
        child: const Text('Delete'),
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

// Show success dialog
void _showSuccessDialog(BuildContext context, String title, String message) {
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

// Show error dialog
void _showErrorDialog(BuildContext context, String title, String message) {
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
