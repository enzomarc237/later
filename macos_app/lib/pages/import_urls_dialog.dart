import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/url_item.dart';
import '../providers/providers.dart';

/// Shows a dialog to select which URLs to import and to which category.
Future<List<UrlItem>?> showImportUrlsDialog(
  BuildContext context,
  List<UrlItem> urls,
) async {
  return await showMacosAlertDialog<List<UrlItem>>(
    context: context,
    builder: (_) => ImportUrlsDialog(
      urls: urls,
      initialCategoryName: 'Bookmarks',
    ),
  );
}

class ImportUrlsDialog extends ConsumerStatefulWidget {
  final List<UrlItem> urls;

  const ImportUrlsDialog({
    super.key,
    required this.urls,
    required String initialCategoryName,
  });

  @override
  ConsumerState<ImportUrlsDialog> createState() => _ImportUrlsDialogState();
}

class _ImportUrlsDialogState extends ConsumerState<ImportUrlsDialog> {
  late List<UrlItem> _urls;
  late List<bool> _selectedUrls;
  String? _selectedCategoryId;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _urls = widget.urls;
    _selectedUrls = List.filled(_urls.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appNotifier);
    final categories = appState.categories;

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
            'Select URLs to Import:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              MacosCheckbox(
                value: _selectAll,
                onChanged: (value) {
                  setState(() {
                    _selectAll = value;
                    _selectedUrls = List.filled(_urls.length, value);
                  });
                                },
              ),
              const SizedBox(width: 8),
              Text(
                'Select All',
                style: MacosTheme.of(context).typography.body,
              ),
              const Spacer(),
              Text(
                '${_selectedUrls.where((selected) => selected).length} of ${_urls.length} selected',
                style: MacosTheme.of(context).typography.caption1.copyWith(
                      color: MacosColors.systemGrayColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: MacosScrollbar(
              child: ListView.builder(
                itemCount: _urls.length,
                itemBuilder: (context, index) {
                  final url = _urls[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        MacosCheckbox(
                          value: _selectedUrls[index],
                          onChanged: (value) {
                            setState(() {
                              _selectedUrls[index] = value;
                              _updateSelectAllState();
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
                                style: MacosTheme.of(context)
                                    .typography
                                    .body
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                url.url,
                                style: MacosTheme.of(context)
                                    .typography
                                    .caption1
                                    .copyWith(
                                      color: MacosColors.systemGrayColor,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
          const SizedBox(height: 16),
          Text(
            'Import to Category:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          MacosPopupButton<String>(
            value: _selectedCategoryId,
            onChanged: (categoryId) {
              setState(() {
                _selectedCategoryId = categoryId;
              });
            },
            items: [
              const MacosPopupMenuItem(
                value: null,
                child: Text('Keep Original Categories'),
              ),
              ...categories.map((category) {
                return MacosPopupMenuItem(
                  value: category.id,
                  child: Text(category.name),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Selected URLs will be added to your bookmarks.',
            style: MacosTheme.of(context).typography.caption1.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          final selectedUrls = <UrlItem>[];
          for (int i = 0; i < _urls.length; i++) {
            if (_selectedUrls[i]) {
              final url = _urls[i];
              if (_selectedCategoryId != null) {
                // Update category if a specific one was selected
                selectedUrls
                    .add(url.copyWith(categoryId: _selectedCategoryId!));
              } else {
                selectedUrls.add(url);
              }
            }
          }
          Navigator.of(context).pop(selectedUrls);
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
    );
  }

  void _updateSelectAllState() {
    final allSelected = _selectedUrls.every((selected) => selected);
    final noneSelected = _selectedUrls.every((selected) => !selected);

    setState(() {
      if (allSelected) {
        _selectAll = true;
      } else if (noneSelected) {
        _selectAll = false;
      }
    });
  }
}
