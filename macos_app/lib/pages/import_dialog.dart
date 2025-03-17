import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class ImportUrlsDialog extends ConsumerStatefulWidget {
  final List<UrlItem> urls;
  final String initialCategoryName;

  const ImportUrlsDialog({
    super.key,
    required this.urls,
    this.initialCategoryName = '',
  });

  @override
  ConsumerState<ImportUrlsDialog> createState() => _ImportUrlsDialogState();
}

class _ImportUrlsDialogState extends ConsumerState<ImportUrlsDialog> {
  late final TextEditingController _categoryController;
  late final List<bool> _selectedUrls;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.initialCategoryName);
    // Initialize all URLs as selected
    _selectedUrls = List.generate(widget.urls.length, (_) => true);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectAll = value;
      for (int i = 0; i < _selectedUrls.length; i++) {
        _selectedUrls[i] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);

    return MacosAlertDialog(
      appIcon: const MacosIcon(
        CupertinoIcons.arrow_down_doc,
        size: 56,
        color: MacosColors.systemBlueColor,
      ),
      title: const Text('Import URLs'),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Category:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          MacosTextField(
            placeholder: 'Enter category name (required)',
            controller: _categoryController,
            maxLines: 1,
            style: MacosTheme.of(context).typography.title3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'URLs to Import:',
                style: MacosTheme.of(context).typography.subheadline.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              MacosCheckbox(
                value: _selectAll,
                onChanged: (value) => _toggleSelectAll(value ?? true),
              ),
              const SizedBox(width: 8),
              Text(
                'Select All',
                style: MacosTheme.of(context).typography.body,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 600,
              maxWidth: 1200,
            ),
            child: MacosScrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.urls.length,
                itemBuilder: (context, index) {
                  final url = widget.urls[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        MacosCheckbox(
                          value: _selectedUrls[index],
                          onChanged: (value) {
                            setState(() {
                              _selectedUrls[index] = value ?? false;
                              // Update selectAll checkbox state
                              _selectAll = _selectedUrls.every((selected) => selected);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                url.title,
                                style: MacosTheme.of(context).typography.title3.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                url.url,
                                style: MacosTheme.of(context).typography.body.copyWith(
                                      color: MacosColors.systemBlueColor,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                              if (url.description != null && url.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  url.description!,
                                  style: MacosTheme.of(context).typography.caption1,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          final categoryName = _categoryController.text.trim();
          if (categoryName.isEmpty) {
            // Show error if category name is empty
            showMacosAlertDialog(
              context: context,
              builder: (_) => MacosAlertDialog(
                appIcon: const MacosIcon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 56,
                  color: MacosColors.systemRedColor,
                ),
                title: const Text('Error'),
                message: const Text('Please enter a category name.'),
                primaryButton: PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ),
            );
            return;
          }

          // Get selected URLs
          final selectedUrls = <UrlItem>[];
          for (int i = 0; i < widget.urls.length; i++) {
            if (_selectedUrls[i]) {
              selectedUrls.add(widget.urls[i]);
            }
          }

          if (selectedUrls.isEmpty) {
            // Show error if no URLs are selected
            showMacosAlertDialog(
              context: context,
              builder: (_) => MacosAlertDialog(
                appIcon: const MacosIcon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 56,
                  color: MacosColors.systemRedColor,
                ),
                title: const Text('Error'),
                message: const Text('Please select at least one URL to import.'),
                primaryButton: PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ),
            );
            return;
          }

          // Find or create category
          String categoryId = '';
          final appNotifierRef = ref.read(appNotifier.notifier);

          // Check if category exists
          final existingCategory = appState.categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase()).toList();

          if (existingCategory.isNotEmpty) {
            categoryId = existingCategory.first.id;
          } else {
            // Create new category
            final newCategory = Category(name: categoryName);
            appNotifierRef.addCategory(newCategory);
            categoryId = newCategory.id;
          }

          // Update URLs with the selected category
          final updatedUrls = selectedUrls.map((url) => url.copyWith(categoryId: categoryId)).toList();

          // Return the updated URLs
          Navigator.of(context).pop(updatedUrls);
        },
        child: const Text('Import'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () {
          Navigator.of(context).pop(null);
        },
        child: const Text('Cancel'),
      ),
    );
  }
}

Future<List<UrlItem>?> showImportUrlsDialog(
  BuildContext context,
  List<UrlItem> urls, {
  String initialCategoryName = '',
}) async {
  return await showMacosAlertDialog<List<UrlItem>>(
    context: context,
    builder: (_) => ImportUrlsDialog(
      urls: urls,
      initialCategoryName: initialCategoryName,
    ),
  );
}
