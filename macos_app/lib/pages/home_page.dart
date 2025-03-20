import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:meta/meta.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/url_validator.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/import_export_manager.dart';
import 'import_dialog.dart';
import 'export_dialog.dart';

// App lifecycle observer to monitor app state changes
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;

  _AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsPressed;

  const HomePage({super.key, this.onSettingsPressed});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late _AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    // Check clipboard for URLs when the app starts
    _checkClipboardForUrls();

    // Create and add observer to check clipboard when app is resumed
    _lifecycleObserver = _AppLifecycleObserver(
      onResumed: _checkClipboardForUrls,
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    // Remove the observer when the widget is disposed
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _searchController.dispose();
    super.dispose();
  }

  // Check clipboard for URLs and import if auto-import is enabled
  Future<void> _checkClipboardForUrls() async {
    // Check if auto-import is enabled in settings
    final settings = ref.read(settingsNotifier);
    if (!settings.autoImportFromClipboard) return;

    try {
      // Get clipboard data
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null) return;

      final text = clipboardData.text!.trim();
      if (text.isEmpty) return;

      // Check if the text is a valid URL
      if (!text.startsWith('http://') && !text.startsWith('https://')) {
        // Try to prepend https:// and check if it's valid
        if (!Uri.tryParse('https://$text')!.hasAuthority) return;
      } else if (!Uri.tryParse(text)!.hasAuthority) {
        return;
      }

      // Check if URL already exists
      final appState = ref.read(appNotifier);
      if (appState.urls.any((url) => url.url == text)) return;

      // Show confirmation dialog
      if (mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: MacosIcon(
              CupertinoIcons.link,
              size: 56,
              color: MacosTheme.of(context).primaryColor,
            ),
            title: const Text('Import URL from Clipboard'),
            message: Text('Would you like to import the URL: $text?'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              onPressed: () {
                Navigator.of(context).pop();
                _importUrlFromClipboard(text);
              },
              child: const Text('Import'),
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
    } catch (e) {
      debugPrint('Error checking clipboard: $e');
    }
  }

  // Import URL from clipboard
  Future<void> _importUrlFromClipboard(String urlString) async {
    try {
      // Create a new URL item
      final appState = ref.read(appNotifier);
      final categoryId = appState.selectedCategoryId ?? (appState.categories.isNotEmpty ? appState.categories.first.id : '');

      // Create a basic URL item
      final newUrl = UrlItem(
        url: urlString,
        title: urlString, // Will be updated with metadata
        categoryId: categoryId,
      );

      // Add the URL and fetch metadata
      await ref.read(appNotifier.notifier).addUrl(newUrl, fetchMetadata: true);

      // Show notification
      LocalNotification(
        title: 'URL Imported',
        body: 'Imported URL from clipboard',
      ).show();
    } catch (e) {
      debugPrint('Error importing URL from clipboard: $e');
      if (mounted) {
        _showErrorDialog(context, 'Import Failed', 'Failed to import URL from clipboard: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);
    final selectedCategoryId = appState.selectedCategoryId;
    final selectionMode = appState.selectionMode;
    final theme = MacosTheme.of(context);

    // Get the selected category name
    final selectedCategory = selectedCategoryId != null
        ? appState.categories.firstWhere(
            (category) => category.id == selectedCategoryId,
            orElse: () => Category(name: 'All URLs'),
          )
        : Category(name: 'All URLs');

    // Get URLs for the selected category using the getter from AppState
    // This ensures we're using the same logic as in the AppState class
    final urls = selectedCategoryId == null ? appState.urls : appState.selectedCategoryUrls;

    // Debug print to verify we're getting the correct URLs
    debugPrint('Selected category: ${selectedCategoryId == null ? "All URLs" : selectedCategory.name}');
    debugPrint('Total URLs: ${appState.urls.length}, Filtered URLs: ${urls.length}');

    // Filter URLs by search query
    final filteredUrls = urls.where((url) => _searchQuery.isEmpty || url.title.toLowerCase().contains(_searchQuery.toLowerCase()) || url.url.toLowerCase().contains(_searchQuery.toLowerCase()) || (url.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();

    return MacosScaffold(
      backgroundColor: theme.canvasColor,
      toolBar: ToolBar(
        leading: MacosIconButton(
          icon: MacosIcon(
            CupertinoIcons.sidebar_left,
            size: 20,
            color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            MacosWindowScope.of(context).toggleSidebar();
          },
        ),
        title: selectionMode ? Text('${appState.selectedUrlCount} selected') : Text(selectedCategory.name),
        titleWidth: 250,
        actions: selectionMode ? _buildSelectionModeActions(context, appState) : _buildNormalModeActions(context, selectedCategoryId),
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: MacosSearchField(
                          placeholder: 'Search URLs',
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      if (filteredUrls.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        PushButton(
                          controlSize: ControlSize.regular,
                          secondary: true,
                          onPressed: () {
                            final appNotifierRef = ref.read(appNotifier.notifier);
                            if (appState.selectionMode) {
                              appNotifierRef.toggleSelectionMode();
                            } else {
                              appNotifierRef.toggleSelectionMode();
                            }
                          },
                          child: Text(appState.selectionMode ? 'Cancel' : 'Select'),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: filteredUrls.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MacosIcon(
                                CupertinoIcons.link,
                                size: 48,
                                color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedCategoryId == null ? 'No URLs added yet' : 'No URLs in this category',
                                style: theme.typography.headline,
                              ),
                              const SizedBox(height: 8),
                              PushButton(
                                controlSize: ControlSize.regular,
                                onPressed: () {
                                  _showAddUrlDialog(context, selectedCategoryId);
                                },
                                child: const Text('Add URL'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredUrls.length,
                          itemBuilder: (context, index) {
                            final url = filteredUrls[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: _buildUrlCard(context, url, appState),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Build actions for normal mode (no selection)
  List<ToolbarItem> _buildNormalModeActions(BuildContext context, String? selectedCategoryId) {
    final appState = ref.read(appNotifier);
    final hasUrls = appState.visibleUrls.isNotEmpty;
    final theme = MacosTheme.of(context);

    return [
      ToolBarIconButton(
        label: 'Add URL',
        icon: MacosIcon(
          CupertinoIcons.add_circled,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: () {
          _showAddUrlDialog(context, selectedCategoryId);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Validate URLs',
        icon: MacosIcon(
          CupertinoIcons.checkmark_shield,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: hasUrls
            ? () {
                _validateVisibleUrls(context);
              }
            : null,
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Export List',
        icon: MacosIcon(
          CupertinoIcons.arrow_up_doc,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: () {
          _exportUrls(context);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Import List',
        icon: MacosIcon(
          CupertinoIcons.arrow_down_doc,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: () {
          _importUrls(context);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Settings',
        icon: MacosIcon(
          CupertinoIcons.gear,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: () {
          // Navigate to settings page
          if (widget.onSettingsPressed != null) {
            widget.onSettingsPressed!();
          }
        },
        showLabel: true,
      ),
    ];
  }

  // Build actions for selection mode
  List<ToolbarItem> _buildSelectionModeActions(BuildContext context, AppState appState) {
    final appNotifierRef = ref.read(appNotifier.notifier);
    final hasSelections = appState.selectedUrlCount > 0;
    final theme = MacosTheme.of(context);

    return [
      ToolBarIconButton(
        label: 'Select All',
        icon: MacosIcon(
          CupertinoIcons.checkmark_circle,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: () {
          appNotifierRef.selectAllVisibleUrls();
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Delete',
        icon: MacosIcon(
          CupertinoIcons.trash,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: hasSelections
            ? () {
                _showDeleteSelectedUrlsDialog(context);
              }
            : null,
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Move',
        icon: MacosIcon(
          CupertinoIcons.folder,
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        onPressed: hasSelections
            ? () {
                _showMoveSelectedUrlsDialog(context);
              }
            : null,
        showLabel: true,
      ),
    ];
  }

  Widget _buildUrlCard(BuildContext context, UrlItem url, AppState appState) {
    // Use the passed appState parameter instead of reading it again
    // This avoids potential confusion with two variables with the same name
    final theme = MacosTheme.of(context);

    return MacosCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (appState.selectionMode) ...[
                  MacosCheckbox(
                    value: appState.isUrlSelected(url.id),
                    onChanged: (value) {
                      ref.read(appNotifier.notifier).toggleUrlSelection(url.id);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                // Display favicon if available
                if (url.metadata != null && url.metadata!['faviconUrl'] != null) ...[
                  _buildFaviconImage(url.metadata!['faviconUrl'] as String?),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    url.title,
                    style: theme.typography.title3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!appState.selectionMode)
                  Row(
                    children: [
                      MacosIconButton(
                        icon: MacosIcon(
                          CupertinoIcons.pencil,
                          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                        onPressed: () {
                          _showEditUrlDialog(context, url);
                        },
                      ),
                      const SizedBox(width: 8),
                      MacosIconButton(
                        icon: MacosIcon(
                          CupertinoIcons.trash,
                          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                        onPressed: () {
                          _showDeleteUrlDialog(context, url);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: url.status.getColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url.url,
                    style: theme.typography.body.copyWith(
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                if (url.lastChecked != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Checked: ${_formatDate(url.lastChecked!)}',
                    style: theme.typography.caption2.copyWith(
                      color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
                    ),
                  ),
                ],
              ],
            ),
            if (url.description != null && url.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                url.description!,
                style: theme.typography.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Category: ${appState.categories.firstWhere(
                        (cat) => cat.id == url.categoryId,
                        orElse: () => Category(id: 'unknown', name: 'Unknown'),
                      ).name}",
                  style: theme.typography.caption1.copyWith(
                    color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
                  ),
                ),
                if (!appState.selectionMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PushButton(
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () {
                          _copyUrlToClipboard(context, url.url);
                        },
                        child: const Text('Copy'),
                      ),
                      const SizedBox(width: 8),
                      PushButton(
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () {
                          _showUrlPreview(context, url);
                        },
                        child: const Text('Preview'),
                      ),
                      const SizedBox(width: 8),
                      PushButton(
                        controlSize: ControlSize.small,
                        secondary: true,
                        onPressed: () {
                          _validateUrl(context, url);
                        },
                        child: const Text('Validate'),
                      ),
                      const SizedBox(width: 8),
                      PushButton(
                        controlSize: ControlSize.small,
                        onPressed: () {
                          _openUrlInBrowser(context, url.url);
                        },
                        child: const Text('Open'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog to confirm deletion of selected URLs
  void _showDeleteSelectedUrlsDialog(BuildContext context) {
    final appState = ref.read(appNotifier);
    final count = appState.selectedUrlCount;
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.trash,
          size: 56,
          color: MacosColors.systemRedColor,
        ),
        title: const Text('Delete Selected URLs'),
        message: Text('Are you sure you want to delete $count selected URLs? This action cannot be undone.'),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            ref.read(appNotifier.notifier).deleteSelectedUrls();

            // Show notification
            LocalNotification(
              title: 'URLs Deleted',
              body: 'Deleted $count URLs',
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

  // Show dialog to move selected URLs to a category
  void _showMoveSelectedUrlsDialog(BuildContext context) {
    final appState = ref.read(appNotifier);
    final count = appState.selectedUrlCount;
    final categories = appState.categories;
    final theme = MacosTheme.of(context);

    // Default to first category or empty string if no categories
    String selectedCategoryId = categories.isNotEmpty ? categories.first.id : '';

    showMacosAlertDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => MacosAlertDialog(
          appIcon: MacosIcon(
            CupertinoIcons.folder,
            size: 56,
            color: theme.primaryColor,
          ),
          title: const Text('Move Selected URLs'),
          message: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a category to move $count URLs to:',
                style: theme.typography.body,
              ),
              const SizedBox(height: 16),
              if (categories.isEmpty)
                Text(
                  'No categories available. Please create a category first.',
                  style: theme.typography.body,
                )
              else
                MacosPopupButton<String>(
                  value: selectedCategoryId,
                  items: categories.map((category) {
                    return MacosPopupMenuItem<String>(
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
                ),
            ],
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: categories.isEmpty
                ? null
                : () {
                    ref.read(appNotifier.notifier).moveSelectedUrlsToCategory(selectedCategoryId);

                    // Show notification
                    final categoryName = categories
                        .firstWhere(
                          (cat) => cat.id == selectedCategoryId,
                          orElse: () => Category(id: 'unknown', name: 'Unknown'),
                        )
                        .name;

                    LocalNotification(
                      title: 'URLs Moved',
                      body: 'Moved $count URLs to "$categoryName"',
                    ).show();

                    Navigator.of(context).pop();
                  },
            child: const Text('Move'),
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
      ),
    );
  }

  void _showUrlPreview(BuildContext context, UrlItem url) {
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      barrierDismissible: true,
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.link,
          size: 56,
          color: theme.primaryColor,
        ),
        title: Text(url.title),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'URL:',
              style: theme.typography.subheadline.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              url.url,
              style: theme.typography.body.copyWith(
                color: theme.primaryColor,
              ),
            ),
            if (url.description != null && url.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description:',
                style: theme.typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url.description!,
                style: theme.typography.body,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Added on:',
              style: theme.typography.subheadline.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${url.createdAt.day}/${url.createdAt.month}/${url.createdAt.year} at ${url.createdAt.hour}:${url.createdAt.minute.toString().padLeft(2, '0')}',
              style: theme.typography.body,
            ),
            if (url.metadata != null && url.metadata!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Metadata:',
                style: theme.typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url.metadata.toString(),
                style: theme.typography.body,
              ),
            ],
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            _openUrlInBrowser(context, url.url);
            Navigator.of(context).pop();
          },
          child: const Text('Open in Browser'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            _copyUrlToClipboard(context, url.url);
            Navigator.of(context).pop();
          },
          child: const Text('Copy URL'),
        ),
      ),
    );
  }

  void _copyUrlToClipboard(BuildContext context, String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      _showSuccessDialog(context, 'URL Copied', 'URL copied to clipboard.');
    } catch (e) {
      debugPrint('Error copying URL to clipboard: $e');
      _showErrorDialog(context, 'Copy Failed', 'Failed to copy URL to clipboard.');
    }
  }

  void _openUrlInBrowser(BuildContext context, String urlString) async {
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showErrorDialog(context, 'Open Failed', 'Could not open URL: $urlString');
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
      _showErrorDialog(context, 'Open Failed', 'Failed to open URL: $urlString');
    }
  }

  void _showAddUrlDialog(BuildContext context, String? categoryId) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final descriptionController = TextEditingController();
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.add_circled,
          size: 56,
          color: theme.primaryColor,
        ),
        title: const Text('Add URL'),
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
            Row(
              children: [
                Expanded(
                  child: MacosTextField(
                    placeholder: 'URL',
                    controller: urlController,
                  ),
                ),
                const SizedBox(width: 8),
                PushButton(
                  controlSize: ControlSize.small,
                  secondary: true,
                  onPressed: () {
                    _fetchMetadataForDialog(context, urlController, titleController, descriptionController);
                  },
                  child: const Text('Fetch Metadata'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MacosTextField(
              placeholder: 'Description (optional)',
              controller: descriptionController,
              maxLines: 3,
            ),
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            if (titleController.text.trim().isNotEmpty && urlController.text.trim().isNotEmpty) {
              final appState = ref.read(appNotifier);
              final newUrl = UrlItem(
                url: urlController.text.trim(),
                title: titleController.text.trim(),
                description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                categoryId: categoryId ?? (appState.categories.isNotEmpty ? appState.categories.first.id : ''),
              );
              ref.read(appNotifier.notifier).addUrl(newUrl);

              // Show notification
              LocalNotification(
                title: 'URL Added',
                body: 'Added URL: ${newUrl.title.length > 30 ? newUrl.title.substring(0, 27) + '...' : newUrl.title}',
              ).show();

              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
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

  void _showEditUrlDialog(BuildContext context, UrlItem url) {
    final titleController = TextEditingController(text: url.title);
    final urlController = TextEditingController(text: url.url);
    final descriptionController = TextEditingController(text: url.description ?? '');
    final theme = MacosTheme.of(context);

    // Get all categories from app state
    final appState = ref.read(appNotifier);
    final categories = appState.categories;

    // Set initial selected category
    String selectedCategoryId = url.categoryId;

    showMacosAlertDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => MacosAlertDialog(
          appIcon: MacosIcon(
            CupertinoIcons.link,
            size: 56,
            color: theme.primaryColor,
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
              Row(
                children: [
                  Expanded(
                    child: MacosTextField(
                      placeholder: 'URL',
                      controller: urlController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.small,
                    secondary: true,
                    onPressed: () {
                      _fetchMetadataForDialog(context, urlController, titleController, descriptionController);
                    },
                    child: const Text('Fetch Metadata'),
                  ),
                ],
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
                style: theme.typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                Text(
                  'No categories available',
                  style: theme.typography.body,
                )
              else
                MacosPopupButton<String>(
                  value: selectedCategoryId,
                  items: categories.map((category) {
                    return MacosPopupMenuItem<String>(
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
                ),
            ],
          ),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () {
              if (titleController.text.trim().isNotEmpty && urlController.text.trim().isNotEmpty) {
                final updatedUrl = url.copyWith(
                  url: urlController.text.trim(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                  categoryId: selectedCategoryId,
                );
                ref.read(appNotifier.notifier).updateUrl(updatedUrl);

                // Show notification
                LocalNotification(
                  title: 'URL Updated',
                  body: 'Updated URL: ${updatedUrl.title.length > 30 ? updatedUrl.title.substring(0, 27) + '...' : updatedUrl.title}',
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
      ),
    );
  }

  void _showDeleteUrlDialog(BuildContext context, UrlItem url) {
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.trash,
          size: 56,
          color: MacosColors.systemRedColor,
        ),
        title: const Text('Delete URL'),
        message: Text('Are you sure you want to delete "${url.title}"?'),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            ref.read(appNotifier.notifier).deleteUrl(url.id);

            // Show notification
            LocalNotification(
              title: 'URL Deleted',
              body: 'Deleted URL: ${url.title.length > 30 ? url.title.substring(0, 27) + '...' : url.title}',
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

  void _exportUrls(BuildContext context) async {
    try {
      // Get export data from AppNotifier
      final exportData = ref.read(appNotifier.notifier).exportData();

      // Show export format dialog
      final exportConfig = await showExportDialog(context);
      if (exportConfig == null) return;

      // Use ImportExportManager to handle the export
      final importExportManager = ImportExportManager();
      await importExportManager.exportBookmarks(context, exportData, exportConfig);

      // Show notification
      LocalNotification(
        title: 'Export Successful',
        body: 'Exported ${exportData.urls.length} URLs to ${exportConfig.format.displayName} file',
      ).show();
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
      _showErrorDialog(context, 'Export Failed', 'Failed to export URLs: $e');
    }
  }

  void _importUrls(BuildContext context) async {
    try {
      // Use ImportExportManager to handle the import
      final importExportManager = ImportExportManager();
      final importedUrls = await importExportManager.importBookmarks(context);

      if (importedUrls == null || importedUrls.isEmpty) return;

      // Show import dialog to let user select URLs and category
      final selectedUrls = await showImportUrlsDialog(
        context,
        importedUrls,
      );

      // If user canceled, do nothing
      if (selectedUrls == null || selectedUrls.isEmpty) return;

      // Import selected URLs
      final appNotifierRef = ref.read(appNotifier.notifier);

      // Add each URL
      for (final url in selectedUrls) {
        appNotifierRef.addUrl(url);
      }

      // Show notification
      LocalNotification(
        title: 'Import Successful',
        body: 'Imported ${selectedUrls.length} URLs',
      ).show();
    } catch (e) {
      debugPrint('Error importing URLs: $e');
      _showErrorDialog(context, 'Import Failed', 'Failed to import URLs: $e');
    }
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
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

  void _showErrorDialog(BuildContext context, String title, String message) {
    final theme = MacosTheme.of(context);

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
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

  // Format a DateTime to a user-friendly string
  String _formatDate(DateTime dateTime) {
    // Format as "MMM d, yyyy" (e.g., "Jan 1, 2023")
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateTime);
  }

  // Build the validation progress UI
  Widget _buildValidationProgress(ValidationProgress progress) {
    final theme = MacosTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const MacosIcon(
                CupertinoIcons.arrow_clockwise,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validating URLs...',
                  style: theme.typography.caption1,
                ),
              ),
              Text(
                '${progress.completed}/${progress.total}',
                style: theme.typography.caption1,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor.withOpacity(0.3) : MacosColors.systemGrayColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress.currentUrl,
            style: theme.typography.caption2.copyWith(
              color: theme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Build a favicon image widget
  Widget _buildFaviconImage(String? faviconUrl) {
    final theme = MacosTheme.of(context);

    if (faviconUrl == null) {
      return MacosIcon(
        CupertinoIcons.globe,
        size: 16,
        color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
      );
    }

    return SizedBox(
      width: 16,
      height: 16,
      child: Image.network(
        faviconUrl,
        width: 16,
        height: 16,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading favicon: $error');
          return MacosIcon(
            CupertinoIcons.globe,
            size: 16,
            color: theme.brightness == Brightness.dark ? MacosColors.systemGrayColor : MacosColors.systemGrayColor,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 16,
            height: 16,
            child: ProgressCircle(
              value: 0.1,
            ),
          );
        },
      ),
    );
  }

  // Validate all visible URLs
  void _validateVisibleUrls(BuildContext context) {
    final appState = ref.read(appNotifier);
    final visibleUrls = appState.visibleUrls;

    if (visibleUrls.isEmpty) return;

    // Start validation in background
    ref.read(appNotifier.notifier).validateVisibleUrls();

    // Show a notification that validation has started
    LocalNotification(
      title: 'URL Validation Started',
      body: 'Validating ${visibleUrls.length} URLs in the background',
    ).show();
  }

  // Fetch metadata for a URL and update dialog fields
  Future<void> _fetchMetadataForDialog(
    BuildContext context,
    TextEditingController urlController,
    TextEditingController titleController,
    TextEditingController descriptionController,
  ) async {
    final urlString = urlController.text.trim();
    final theme = MacosTheme.of(context);

    if (urlString.isEmpty) {
      _showErrorDialog(context, 'URL Required', 'Please enter a URL to fetch metadata.');
      return;
    }

    // Show loading dialog
    bool isCancelled = false;
    showMacosAlertDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.globe,
          size: 56,
          color: theme.primaryColor,
        ),
        title: const Text('Fetching Metadata'),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const ProgressCircle(),
            const SizedBox(height: 16),
            Text(
              'Fetching metadata for $urlString...',
              style: theme.typography.body,
            ),
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );

    if (isCancelled) return;

    try {
      // Fetch metadata
      final metadata = await ref.read(metadataServiceProvider).fetchMetadata(urlString);

      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (isCancelled || !context.mounted) return;

      // Update the text fields if metadata was found
      if (metadata.error == null) {
        if (metadata.title != null && metadata.title!.isNotEmpty) {
          titleController.text = metadata.title!;
        }

        if (metadata.description != null && metadata.description!.isNotEmpty) {
          descriptionController.text = metadata.description!;
        }

        // Show success message
        _showSuccessDialog(context, 'Metadata Fetched', 'Successfully fetched metadata for the URL.');
      } else {
        // Show error message
        _showErrorDialog(context, 'Metadata Error', 'Error fetching metadata: ${metadata.error}');
      }
    } catch (e) {
      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        // Show error message
        _showErrorDialog(context, 'Metadata Error', 'Error fetching metadata: $e');
      }
    }
  }

  // Validate a URL and show the result
  Future<void> _validateUrl(BuildContext context, UrlItem url) async {
    final theme = MacosTheme.of(context);

    // Show loading dialog
    bool isCancelled = false;
    showMacosAlertDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MacosAlertDialog(
        appIcon: MacosIcon(
          CupertinoIcons.link,
          size: 56,
          color: theme.primaryColor,
        ),
        title: const Text('Validating URL'),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const ProgressCircle(),
            const SizedBox(height: 16),
            Text(
              'Checking if "${url.title}" is accessible...',
              style: theme.typography.body,
            ),
          ],
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            isCancelled = true;
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

      switch (status) {
        case UrlStatus.valid:
          title = 'URL is Valid';
          message = 'The URL "${url.title}" is accessible.';
          icon = MacosIcon(
            CupertinoIcons.check_mark_circled,
            size: 56,
            color: MacosColors.systemGreenColor,
          );
          break;
        case UrlStatus.invalid:
          title = 'URL is Invalid';
          message = 'The URL "${url.title}" returned an error status code.';
          icon = MacosIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 56,
            color: MacosColors.systemRedColor,
          );
          break;
        case UrlStatus.timeout:
          title = 'URL Timed Out';
          message = 'The request to "${url.title}" timed out.';
          icon = MacosIcon(
            CupertinoIcons.clock,
            size: 56,
            color: MacosColors.systemOrangeColor,
          );
          break;
        case UrlStatus.error:
          title = 'Error Validating URL';
          message = 'There was an error validating "${url.title}".';
          icon = MacosIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 56,
            color: MacosColors.systemRedColor,
          );
          break;
        default:
          title = 'Validation Complete';
          message = 'The URL "${url.title}" has been checked.';
          icon = MacosIcon(
            CupertinoIcons.info_circle,
            size: 56,
            color: theme.primaryColor,
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
}

class MacosCard extends StatelessWidget {
  final Widget child;

  const MacosCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}
