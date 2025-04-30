import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/url_item.dart';
import '../utils/import_export_manager.dart';

enum ImportSource {
  file,
  clipboard,
  browser,
}

extension ImportSourceExtension on ImportSource {
  String get displayName {
    switch (this) {
      case ImportSource.file:
        return 'From File';
      case ImportSource.clipboard:
        return 'From Clipboard';
      case ImportSource.browser:
        return 'From Browser';
    }
  }
  
  String get description {
    switch (this) {
      case ImportSource.file:
        return 'Import bookmarks from a file (JSON, CSV, HTML, XML)';
      case ImportSource.clipboard:
        return 'Import bookmarks from clipboard content';
      case ImportSource.browser:
        return 'Import bookmarks from browser export files';
    }
  }
  
  IconData get icon {
    switch (this) {
      case ImportSource.file:
        return CupertinoIcons.doc;
      case ImportSource.clipboard:
        return CupertinoIcons.doc_on_clipboard;
      case ImportSource.browser:
        return CupertinoIcons.globe;
    }
  }
}

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  ImportSource _selectedSource = ImportSource.file;
  final ImportExportManager _importExportManager = ImportExportManager();
  
  @override
  Widget build(BuildContext context) {
    return MacosAlertDialog(
      appIcon: const MacosIcon(
        CupertinoIcons.arrow_down_doc,
        size: 56,
        color: MacosColors.systemBlueColor,
      ),
      title: const Text('Import Bookmarks'),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Import Source:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...ImportSource.values.map((source) => _buildSourceOption(source)),
          const SizedBox(height: 24),
          Text(
            'This will import bookmarks and add them to your existing collection.',
            style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Imported bookmarks will be added to the selected category.',
            style: MacosTheme.of(context).typography.caption1.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () => _importBookmarks(context),
        child: const Text('Import'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    );
  }
  
  Widget _buildSourceOption(ImportSource source) {
    final isSelected = _selectedSource == source;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSource = source;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? MacosColors.controlAccentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? MacosColors.controlAccentColor : MacosTheme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            MacosIcon(
              source.icon,
              color: isSelected ? MacosColors.controlAccentColor : MacosColors.systemGrayColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.displayName,
                    style: MacosTheme.of(context).typography.body.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? MacosColors.controlAccentColor : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.description,
                    style: MacosTheme.of(context).typography.caption1.copyWith(
                          color: MacosColors.systemGrayColor,
                        ),
                  ),
                ],
              ),
            ),
            MacosRadioButton(
              value: source,
              groupValue: _selectedSource,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSource = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _importBookmarks(BuildContext context) async {
    List<UrlItem>? importedUrls;
    
    switch (_selectedSource) {
      case ImportSource.file:
        importedUrls = await _importExportManager.importBookmarks(context);
        break;
      case ImportSource.clipboard:
        importedUrls = await _importExportManager.importFromClipboard(context);
        break;
      case ImportSource.browser:
        // This uses the same file picker but with better browser detection
        importedUrls = await _importExportManager.importBookmarks(context);
        break;
    }
    
    if (context.mounted) {
      if (importedUrls != null && importedUrls.isNotEmpty) {
        Navigator.of(context).pop(importedUrls);
      } else if (importedUrls != null && importedUrls.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            title: const Text('No Bookmarks Found'),
            message: const Text('No bookmarks were found in the selected source.'),
            primaryButton: PushButton(
              onPressed: () => Navigator.of(context).pop(),
              controlSize: ControlSize.large,
              child: const Text('OK'),
            ), appIcon: MacosIcon(CupertinoIcons.info),
          ),
        );
      } else {
        // User cancelled or error occurred
        Navigator.of(context).pop();
      }
    }
  }
}