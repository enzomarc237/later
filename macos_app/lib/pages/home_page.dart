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
import 'package:url_launcher/url_launcher.dart';
import '../utils/url_validator.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'import_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsPressed;

  const HomePage({super.key, this.onSettingsPressed});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);
    final selectedCategoryId = appState.selectedCategoryId;
    final selectionMode = appState.selectionMode;

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
      toolBar: ToolBar(
        leading: MacosIconButton(
          icon: const MacosIcon(
            CupertinoIcons.sidebar_left,
            size: 20,
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
                              const MacosIcon(
                                CupertinoIcons.link,
                                size: 48,
                                color: MacosColors.systemGrayColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedCategoryId == null ? 'No URLs added yet' : 'No URLs in this category',
                                style: MacosTheme.of(context).typography.headline,
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

    return [
      ToolBarIconButton(
        label: 'Add URL',
        icon: const MacosIcon(CupertinoIcons.add_circled),
        onPressed: () {
          _showAddUrlDialog(context, selectedCategoryId);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Validate URLs',
        icon: const MacosIcon(CupertinoIcons.checkmark_shield),
        onPressed: hasUrls
            ? () {
                _validateVisibleUrls(context);
              }
            : null,
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Export List',
        icon: const MacosIcon(CupertinoIcons.arrow_up_doc),
        onPressed: () {
          _exportUrls(context);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Import List',
        icon: const MacosIcon(CupertinoIcons.arrow_down_doc),
        onPressed: () {
          _importUrls(context);
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Settings',
        icon: const MacosIcon(CupertinoIcons.gear),
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

    return [
      ToolBarIconButton(
        label: 'Select All',
        icon: const MacosIcon(CupertinoIcons.checkmark_circle),
        onPressed: () {
          appNotifierRef.selectAllVisibleUrls();
        },
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Delete',
        icon: const MacosIcon(CupertinoIcons.trash),
        onPressed: hasSelections
            ? () {
                _showDeleteSelectedUrlsDialog(context);
              }
            : null,
        showLabel: true,
      ),
      ToolBarIconButton(
        label: 'Move',
        icon: const MacosIcon(CupertinoIcons.folder),
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
                Expanded(
                  child: Text(
                    url.title,
                    style: MacosTheme.of(context).typography.title3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!appState.selectionMode)
                  Row(
                    children: [
                      MacosIconButton(
                        icon: const MacosIcon(CupertinoIcons.pencil),
                        onPressed: () {
                          _showEditUrlDialog(context, url);
                        },
                      ),
                      const SizedBox(width: 8),
                      MacosIconButton(
                        icon: const MacosIcon(CupertinoIcons.trash),
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
                    color: url.status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url.url,
                    style: MacosTheme.of(context).typography.body.copyWith(
                          color: MacosColors.systemBlueColor,
                        ),
                  ),
                ),
                if (url.lastChecked != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Checked: ${_formatDate(url.lastChecked!)}',
                    style: MacosTheme.of(context).typography.caption2.copyWith(
                          color: MacosColors.systemGrayColor,
                        ),
                  ),
                ],
              ],
            ),
            if (url.description != null && url.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                url.description!,
                style: MacosTheme.of(context).typography.body,
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
                  style: MacosTheme.of(context).typography.caption1.copyWith(
                        color: MacosColors.systemGrayColor,
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

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
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

    // Default to first category or empty string if no categories
    String selectedCategoryId = categories.isNotEmpty ? categories.first.id : '';

    showMacosAlertDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.folder,
            size: 56,
            color: MacosColors.systemBlueColor,
          ),
          title: const Text('Move Selected URLs'),
          message: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a category to move $count URLs to:'),
              const SizedBox(height: 16),
              if (categories.isEmpty)
                const Text('No categories available. Please create a category first.')
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
    showMacosAlertDialog(
      barrierDismissible: true,
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.link,
          size: 56,
          color: MacosColors.systemBlueColor,
        ),
        title: Text(url.title),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'URL:',
              style: MacosTheme.of(context).typography.subheadline.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              url.url,
              style: MacosTheme.of(context).typography.body.copyWith(
                    color: MacosColors.systemBlueColor,
                  ),
            ),
            if (url.description != null && url.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description:',
                style: MacosTheme.of(context).typography.subheadline.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url.description!,
                style: MacosTheme.of(context).typography.body,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Added on:',
              style: MacosTheme.of(context).typography.subheadline.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${url.createdAt.day}/${url.createdAt.month}/${url.createdAt.year} at ${url.createdAt.hour}:${url.createdAt.minute.toString().padLeft(2, '0')}',
              style: MacosTheme.of(context).typography.body,
            ),
            if (url.metadata != null && url.metadata!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Metadata:',
                style: MacosTheme.of(context).typography.subheadline.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url.metadata.toString(),
                style: MacosTheme.of(context).typography.body,
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

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.add_circled,
          size: 56,
          color: MacosColors.systemBlueColor,
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

    // Get all categories from app state
    final appState = ref.read(appNotifier);
    final categories = appState.categories;

    // Set initial selected category
    String selectedCategoryId = url.categoryId;

    showMacosAlertDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.link,
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
                style: MacosTheme.of(context).typography.subheadline.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Text('No categories available')
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
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
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

      // Convert to JSON
      final jsonString = jsonEncode(exportData.toJson());

      // Get save location
      final saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: 'Save URLs',
        fileName: 'later_export_${DateTime.now().millisecondsSinceEpoch}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (saveLocation != null) {
        // Write to file
        final file = File(saveLocation);
        await file.writeAsString(jsonString);

        // Show success message
        _showSuccessDialog(context, 'Export Successful', 'URLs exported successfully.');

        // Show notification
        LocalNotification(
          title: 'Export Successful',
          body: 'Exported ${exportData.urls.length} URLs to file',
        ).show();
      }
    } catch (e) {
      debugPrint('Error exporting URLs: $e');
      _showErrorDialog(context, 'Export Failed', 'Failed to export URLs: $e');
    }
  }

  void _importUrls(BuildContext context) async {
    try {
      // Get file to import
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import URLs',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (result != null && result.files.single.path != null) {
        // Read file
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        // Parse JSON
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final importData = ExportData.fromJson(jsonData);

        // Get default category name if available
        String initialCategoryName = '';
        if (importData.categories.isNotEmpty) {
          initialCategoryName = importData.categories.first.name;
        }

        // Show import dialog to let user select URLs and category
        final selectedUrls = await showImportUrlsDialog(
          context,
          importData.urls,
          initialCategoryName: initialCategoryName,
        );

        // If user canceled, do nothing
        if (selectedUrls == null || selectedUrls.isEmpty) {
          return;
        }

        // Import selected URLs
        final appNotifierRef = ref.read(appNotifier.notifier);

        // Add each URL
        for (final url in selectedUrls) {
          appNotifierRef.addUrl(url);
        }

        // Show success message
        _showSuccessDialog(context, 'Import Successful', 'Imported ${selectedUrls.length} URLs.');

        // Show notification
        LocalNotification(
          title: 'Import Successful',
          body: 'Imported ${selectedUrls.length} URLs',
        ).show();
      }
    } catch (e) {
      debugPrint('Error importing URLs: $e');
      _showErrorDialog(context, 'Import Failed', 'Failed to import URLs: $e');
    }
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
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

  void _showErrorDialog(BuildContext context, String title, String message) {
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

  // Format a DateTime to a user-friendly string
  String _formatDate(DateTime dateTime) {
    // Format as "MMM d, yyyy" (e.g., "Jan 1, 2023")
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateTime);
  }

  // Validate all visible URLs
  Future<void> _validateVisibleUrls(BuildContext context) async {
    final appState = ref.read(appNotifier);
    final visibleUrls = appState.visibleUrls;

    if (visibleUrls.isEmpty) return;

    // Show loading dialog
    bool isCancelled = false;
    showMacosAlertDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.checkmark_shield,
          size: 56,
          color: MacosColors.systemBlueColor,
        ),
        title: const Text('Validating URLs'),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const ProgressCircle(),
            const SizedBox(height: 16),
            Text('Checking ${visibleUrls.length} URLs...'),
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

    // Validate all visible URLs
    if (!isCancelled) {
      final results = await ref.read(appNotifier.notifier).validateVisibleUrls();

      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show results
      if (context.mounted && !isCancelled) {
        int validCount = 0;
        int invalidCount = 0;
        int errorCount = 0;

        results.forEach((_, status) {
          if (status.isValid) {
            validCount++;
          } else if (status.isInvalid) {
            invalidCount++;
          } else {
            errorCount++;
          }
        });

        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const MacosIcon(
              CupertinoIcons.checkmark_shield,
              size: 56,
              color: MacosColors.systemBlueColor,
            ),
            title: const Text('Validation Results'),
            message: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Validated ${results.length} URLs:'),
                const SizedBox(height: 8),
                Text('• $validCount valid URLs', style: TextStyle(color: MacosColors.systemGreenColor)),
                Text('• $invalidCount invalid URLs', style: TextStyle(color: MacosColors.systemRedColor)),
                if (errorCount > 0) Text('• $errorCount URLs with errors', style: TextStyle(color: MacosColors.systemOrangeColor)),
              ],
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

  // Validate a URL and show the result
  Future<void> _validateUrl(BuildContext context, UrlItem url) async {
    // Show loading dialog
    bool isCancelled = false;
    showMacosAlertDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.link,
          size: 56,
          color: MacosColors.systemBlueColor,
        ),
        title: const Text('Validating URL'),
        message: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const ProgressCircle(),
            const SizedBox(height: 16),
            Text('Checking if "${url.title}" is accessible...'),
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
          icon = const MacosIcon(
            CupertinoIcons.check_mark_circled,
            size: 56,
            color: MacosColors.systemGreenColor,
          );
          break;
        case UrlStatus.invalid:
          title = 'URL is Invalid';
          message = 'The URL "${url.title}" returned an error status code.';
          icon = const MacosIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 56,
            color: MacosColors.systemRedColor,
          );
          break;
        case UrlStatus.timeout:
          title = 'URL Timed Out';
          message = 'The request to "${url.title}" timed out.';
          icon = const MacosIcon(
            CupertinoIcons.clock,
            size: 56,
            color: MacosColors.systemOrangeColor,
          );
          break;
        case UrlStatus.error:
          title = 'Error Validating URL';
          message = 'There was an error validating "${url.title}".';
          icon = const MacosIcon(
            CupertinoIcons.exclamationmark_circle,
            size: 56,
            color: MacosColors.systemRedColor,
          );
          break;
        default:
          title = 'Validation Complete';
          message = 'The URL "${url.title}" has been checked.';
          icon = const MacosIcon(
            CupertinoIcons.info_circle,
            size: 56,
            color: MacosColors.systemBlueColor,
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
    return Container(
      decoration: BoxDecoration(
        color: MacosTheme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: MacosTheme.brightnessOf(context) == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}
