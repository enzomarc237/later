import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

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

    // Get the selected category name
    final selectedCategory = selectedCategoryId != null
        ? appState.categories.firstWhere(
            (category) => category.id == selectedCategoryId,
            orElse: () => Category(name: 'All URLs'),
          )
        : Category(name: 'All URLs');

    // Get URLs for the selected category
    final urls = selectedCategoryId != null ? appState.urls.where((url) => url.categoryId == selectedCategoryId).toList() : appState.urls;

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
        title: Text(selectedCategory.name),
        titleWidth: 250,
        actions: [
          ToolBarIconButton(
            label: 'Add URL',
            icon: const MacosIcon(CupertinoIcons.add_circled),
            onPressed: () {
              _showAddUrlDialog(context, selectedCategoryId);
            },
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
            },
            showLabel: true,
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                              child: _buildUrlCard(context, url),
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

  Widget _buildUrlCard(BuildContext context, UrlItem url) {
    return MacosCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    url.title,
                    style: MacosTheme.of(context).typography.title3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            Text(
              url.url,
              style: MacosTheme.of(context).typography.body.copyWith(
                    color: MacosColors.systemBlueColor,
                  ),
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
                  onPressed: () {
                    _openUrlInBrowser(context, url.url);
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlPreview(BuildContext context, UrlItem url) {
    showMacosAlertDialog(
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
        appIcon: const FlutterLogo(size: 56),
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

    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
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
              );
              ref.read(appNotifier.notifier).updateUrl(updatedUrl);
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

  void _showDeleteUrlDialog(BuildContext context, UrlItem url) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
        title: const Text('Delete URL'),
        message: Text('Are you sure you want to delete "${url.title}"?'),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            ref.read(appNotifier.notifier).deleteUrl(url.id);
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

        // Import data
        ref.read(appNotifier.notifier).importData(importData);

        // Show success message
        _showSuccessDialog(context, 'Import Successful', 'Imported ${importData.urls.length} URLs and ${importData.categories.length} categories.');
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
