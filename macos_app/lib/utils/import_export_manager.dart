import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/export_data.dart';
import '../models/url_item.dart';
import '../pages/export_dialog.dart';
import 'export_service.dart';
import 'browser_bookmark_parser.dart';

class ImportExportManager {
  final ExportService _exportService = ExportService();
  final BrowserBookmarkParser _browserParser = BrowserBookmarkParser();

  // Export bookmarks to a file
  Future<void> exportBookmarks(
    BuildContext context,
    ExportData data,
    ExportConfiguration config,
  ) async {
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save bookmarks',
      fileName: config.filename,
    );

    if (outputPath == null) return; // User cancelled

    String content;
    switch (config.format) {
      case ExportFormat.json:
        content = jsonEncode(data.toJson());
        break;
      case ExportFormat.csv:
        content = _exportService.toCSV(data);
        break;
      case ExportFormat.html:
        content = _exportService.toHTML(data);
        break;
      case ExportFormat.xml:
        content = _exportService.toXML(data);
        break;
    }

    final file = File(outputPath);
    await file.writeAsString(content);
  }

  // Import bookmarks from a file
  Future<List<UrlItem>?> importBookmarks(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'html', 'xml', 'plist'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.first.path!);
    final content = await file.readAsString();
    final extension = path.extension(file.path).toLowerCase();
    final fileName = path.basename(file.path).toLowerCase();

    try {
      // Check if this is a browser bookmark file
      if (fileName.contains('bookmark') ||
          content.contains('NETSCAPE-Bookmark-file') ||
          content.contains('"roots"') ||
          content.contains('WebBookmarkType')) {
        try {
          return _browserParser.parseAuto(content).urls;
        } catch (e) {
          debugPrint('Failed to parse as browser bookmark: $e');
          // Fall back to standard formats
        }
      }

      // Try standard formats
      switch (extension) {
        case '.json':
          final json = jsonDecode(content) as Map<String, dynamic>;
          return ExportData.fromJson(json).urls;
        case '.csv':
          return _exportService.fromCSV(content).urls;
        case '.html':
          return _exportService.fromHTML(content).urls;
        case '.xml':
          return _exportService.fromXML(content).urls;
        default:
          throw FormatException('Unsupported file format: $extension');
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Error'),
            content: Text('Failed to import bookmarks: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return null;
    }
  }

  // Export bookmarks to clipboard in JSON format
  Future<void> exportToClipboard(BuildContext context, ExportData data) async {
    try {
      final content = jsonEncode(data.toJson());
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e) {
      debugPrint('Error exporting to clipboard: $e');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Error'),
            content: Text('Failed to export to clipboard: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Import bookmarks from clipboard
  Future<List<UrlItem>?> importFromClipboard(BuildContext context) async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text == null) return null;

      final content = clipboardData!.text!;

      // Try to parse as JSON first
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        return ExportData.fromJson(json).urls;
      } catch (_) {
        // If JSON parsing fails, try CSV
        if (content.contains(',')) {
          try {
            return _exportService.fromCSV(content).urls;
          } catch (_) {
            // If CSV parsing fails, try HTML
            if (content.toLowerCase().contains('<html')) {
              try {
                return _exportService.fromHTML(content).urls;
              } catch (_) {
                // If HTML parsing fails, try XML
                if (content.toLowerCase().contains('<?xml') ||
                    content.toLowerCase().contains('<bookmarks')) {
                  try {
                    return _exportService.fromXML(content).urls;
                  } catch (_) {
                    // If all parsing attempts fail, throw error
                    throw FormatException(
                        'Clipboard content is not in a recognized format');
                  }
                } else {
                  // If all parsing attempts fail, throw error
                  throw FormatException(
                      'Clipboard content is not in a recognized format');
                }
              }
            } else if (content.toLowerCase().contains('<?xml') ||
                content.toLowerCase().contains('<bookmarks')) {
              // Try XML directly if it looks like XML
              try {
                return _exportService.fromXML(content).urls;
              } catch (_) {
                // If XML parsing fails, throw error
                throw FormatException(
                    'Clipboard content is not in a recognized format');
              }
            }
          }
        }
      }

      throw FormatException('Clipboard content is not in a recognized format');
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Error'),
            content: Text('Failed to import from clipboard: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return null;
    }
  }

  // Get the default export directory
  Future<String> getDefaultExportDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportDir =
        Directory(path.join(documentsDir.path, 'Later', 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  // Generate a default filename based on the current date
  String generateDefaultFilename(ExportFormat format) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'later_bookmarks_$timestamp${format.fileExtension}';
  }
}
