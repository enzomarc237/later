import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

enum ExportFormat {
  json,
  csv,
  html,
}

extension ExportFormatExtension on ExportFormat {
  String get displayName {
    switch (this) {
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.html:
        return 'HTML';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.json:
        return '.json';
      case ExportFormat.csv:
        return '.csv';
      case ExportFormat.html:
        return '.html';
    }
  }
}

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.json;
  final TextEditingController _filenameController = TextEditingController(
    text: 'later_bookmarks',
  );

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosAlertDialog(
      appIcon: MacosIcon(
        CupertinoIcons.arrow_up_doc,
        size: 56,
        color: MacosTheme.of(context).primaryColor,
      ),
      title: const Text('Export Bookmarks'),
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Export Format:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          MacosPopupButton<ExportFormat>(
            value: _selectedFormat,
            onChanged: (format) {
              if (format != null) {
                setState(() {
                  _selectedFormat = format;
                });
              }
            },
            items: ExportFormat.values.map((format) {
              return MacosPopupMenuItem(
                value: format,
                child: Text(format.displayName),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Filename:',
            style: MacosTheme.of(context).typography.subheadline.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          MacosTextField(
            placeholder: 'Enter filename',
            controller: _filenameController,
            maxLines: 1,
            style: MacosTheme.of(context).typography.body,
            suffix: Text(_selectedFormat.fileExtension),
          ),
          const SizedBox(height: 24),
          Text(
            'This will export all your bookmarks and categories to a single file.',
            style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemGrayColor,
                ),
          ),
        ],
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          final filename = _filenameController.text.trim();
          if (filename.isEmpty) {
            showMacosAlertDialog(
              context: context,
              builder: (_) => MacosAlertDialog(
                appIcon: MacosIcon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 56,
                  color: MacosTheme.of(context).brightness == Brightness.dark
                      ? Colors.red
                      : MacosColors.systemRedColor,
                ),
                title: const Text('Error'),
                message: const Text('Please enter a filename.'),
                primaryButton: PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ),
            );
            return;
          }

          // Return the export configuration
          Navigator.of(context).pop(
            ExportConfiguration(
              format: _selectedFormat,
              filename: '$filename${_selectedFormat.fileExtension}',
            ),
          );
        },
        child: const Text('Export'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    );
  }
}

class ExportConfiguration {
  final ExportFormat format;
  final String filename;

  const ExportConfiguration({
    required this.format,
    required this.filename,
  });
}

Future<ExportConfiguration?> showExportDialog(BuildContext context) async {
  return await showMacosAlertDialog<ExportConfiguration>(
    context: context,
    builder: (_) => const ExportDialog(),
  );
}