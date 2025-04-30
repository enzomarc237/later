import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';
import '../models/export_data.dart';
import '../models/category.dart';
import '../models/url_item.dart';
import '../utils/url_validator.dart';

class ExportService {
  // Convert ExportData to CSV format
  String toCSV(ExportData data) {
    final List<List<dynamic>> rows = [];

    // Add header
    rows.add(
        ['URL', 'Title', 'Category', 'Created Date', 'Description', 'Status']);

    // Add data rows
    for (final url in data.urls) {
      final category = data.categories.firstWhere((c) => c.id == url.categoryId,
          orElse: () => Category(id: '', name: 'Uncategorized'));

      rows.add([
        url.url,
        url.title,
        category.name,
        url.createdAt.toIso8601String(),
        url.description ?? '',
        url.status.name,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // Parse CSV back to ExportData
  ExportData fromCSV(String csvContent) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) throw FormatException('CSV file is empty');

    // Skip header row
    final dataRows = rows.skip(1).toList();

    // Extract unique categories
    final categoryNames = dataRows.map((row) => row[2].toString()).toSet();
    final categories = categoryNames
        .map((name) =>
            Category(id: name.toLowerCase().replaceAll(' ', '_'), name: name))
        .toList();

    // Convert rows to URLs
    final urls = dataRows.map((row) {
      final categoryName = row[2].toString();
      final category = categories.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => categories.first,
      );

      return UrlItem(
        url: row[0].toString(),
        title: row[1].toString(),
        categoryId: category.id,
        description: row[4].toString().isEmpty ? null : row[4].toString(),
        createdAt: DateTime.tryParse(row[3].toString()) ?? DateTime.now(),
        status: UrlStatus.values.firstWhere(
          (s) => s.name == row[5].toString(),
          orElse: () => UrlStatus.unknown,
        ),
      );
    }).toList();

    return ExportData(
      categories: categories,
      urls: urls,
      version: '1.0.0',
    );
  }

  // Convert ExportData to HTML format
  String toHTML(ExportData data) {
    final buffer = StringBuffer();
    buffer.writeln('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Later App Bookmarks</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 2em; }
    .category { margin: 1em 0; }
    .category h2 { color: #333; }
    .url-list { list-style: none; padding: 0; }
    .url-item { margin: 0.5em 0; padding: 0.5em; border-bottom: 1px solid #eee; }
    .url-title { font-weight: bold; }
    .url-meta { color: #666; font-size: 0.9em; margin-top: 0.3em; }
    .url-status { display: inline-block; padding: 0.2em 0.5em; border-radius: 3px; font-size: 0.8em; }
    .status-valid { background: #e8f5e9; color: #2e7d32; }
    .status-invalid { background: #ffebee; color: #c62828; }
    .status-unknown { background: #f5f5f5; color: #616161; }
  </style>
</head>
<body>
  <h1>Later App Bookmarks</h1>
  <p>Exported on: ${data.exportedAt.toLocal()}</p>
''');

    // Group URLs by category
    final urlsByCategory = <String, List<UrlItem>>{};
    for (final url in data.urls) {
      final categoryId = url.categoryId;
      urlsByCategory.putIfAbsent(categoryId, () => []).add(url);
    }

    // Generate HTML for each category
    for (final category in data.categories) {
      final categoryUrls = urlsByCategory[category.id] ?? [];
      if (categoryUrls.isEmpty) continue;

      buffer.writeln('''
  <div class="category">
    <h2>${_escapeHtml(category.name)}</h2>
    <ul class="url-list">''');

      for (final url in categoryUrls) {
        String statusClass;
        if (url.status == UrlStatus.valid) {
          statusClass = 'status-valid';
        } else if (url.status == UrlStatus.invalid) {
          statusClass = 'status-invalid';
        } else {
          statusClass = 'status-unknown';
        }

        buffer.writeln('''
      <li class="url-item">
        <div class="url-title">
          <a href="${_escapeHtml(url.url)}" target="_blank">${_escapeHtml(url.title)}</a>
          <span class="url-status ${statusClass}">${url.status.name}</span>
        </div>
        <div class="url-meta">
          Added: ${url.createdAt.toLocal()}
          ${url.description?.isNotEmpty == true ? '<br>Description: ${_escapeHtml(url.description!)}' : ''}
          ${url.metadata?.isNotEmpty == true ? '<br>Metadata: ${_escapeHtml(jsonEncode(url.metadata))}' : ''}
        </div>
      </li>''');
      }

      buffer.writeln('''
    </ul>
  </div>''');
    }

    buffer.writeln('''
</body>
</html>''');

    return buffer.toString();
  }

  // Parse HTML back to ExportData
  ExportData fromHTML(String htmlContent) {
    // This is a basic implementation that could be enhanced with proper HTML parsing
    final categoryRegex = RegExp(r'<h2>(.*?)</h2>');
    final urlRegex = RegExp(r'<a href="(.*?)".*?>(.*?)</a>');
    final descriptionRegex =
        RegExp(r'Description: (.*?)(?:<br>|</div>)', multiLine: true);
    final statusRegex = RegExp(r'class="url-status [^"]*">(.*?)</span>');

    final categories = <Category>[];
    final urls = <UrlItem>[];

    // Extract categories and URLs
    final categoryMatches = categoryRegex.allMatches(htmlContent);
    for (final categoryMatch in categoryMatches) {
      final categoryName = _unescapeHtml(categoryMatch.group(1) ?? '');
      final categoryId = categoryName.toLowerCase().replaceAll(' ', '_');
      categories.add(Category(id: categoryId, name: categoryName));

      // Find URLs for this category
      final categoryStart = categoryMatch.end;
      final categoryEnd = htmlContent.indexOf('</div>', categoryStart);
      final categoryContent = htmlContent.substring(categoryStart, categoryEnd);

      final urlMatches = urlRegex.allMatches(categoryContent);
      for (final urlMatch in urlMatches) {
        final url = _unescapeHtml(urlMatch.group(1) ?? '');
        final title = _unescapeHtml(urlMatch.group(2) ?? '');

        // Try to find description for this URL
        final descriptionMatch = descriptionRegex
            .firstMatch(categoryContent.substring(urlMatch.end));
        final description = descriptionMatch != null
            ? _unescapeHtml(descriptionMatch.group(1) ?? '')
            : null;

        // Try to find status for this URL
        final statusMatch =
            statusRegex.firstMatch(categoryContent.substring(urlMatch.end));
        final statusName = statusMatch?.group(1) ?? 'unknown';
        final status = UrlStatus.values.firstWhere(
          (s) => s.name == statusName,
          orElse: () => UrlStatus.unknown,
        );

        urls.add(UrlItem(
          url: url,
          title: title,
          categoryId: categoryId,
          description: description,
          status: status,
        ));
      }
    }

    return ExportData(
      categories: categories,
      urls: urls,
      version: '1.0.0',
    );
  }

  // Convert ExportData to XML format
  String toXML(ExportData data) {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('bookmarks', nest: () {
      builder.attribute('version', data.version);
      builder.attribute('exportedAt', data.exportedAt.toIso8601String());

      // Add categories
      builder.element('categories', nest: () {
        for (final category in data.categories) {
          builder.element('category', nest: () {
            builder.attribute('id', category.id);
            builder.attribute(
                'createdAt', category.createdAt.toIso8601String());
            builder.attribute(
                'updatedAt', category.updatedAt.toIso8601String());
            builder.element('name', nest: category.name);
            if (category.iconName != null) {
              builder.element('iconName', nest: category.iconName);
            }
          });
        }
      });

      // Add URLs
      builder.element('urls', nest: () {
        for (final url in data.urls) {
          builder.element('url', nest: () {
            builder.attribute('id', url.id);
            builder.attribute('categoryId', url.categoryId);
            builder.attribute('createdAt', url.createdAt.toIso8601String());
            builder.attribute('updatedAt', url.updatedAt.toIso8601String());
            builder.attribute('status', url.status.name);

            builder.element('href', nest: url.url);
            builder.element('title', nest: url.title);

            if (url.description != null) {
              builder.element('description', nest: url.description);
            }

            if (url.metadata != null && url.metadata!.isNotEmpty) {
              builder.element('metadata', nest: () {
                for (final entry in url.metadata!.entries) {
                  builder.element('item', nest: () {
                    builder.attribute('key', entry.key);
                    builder.text(entry.value.toString());
                  });
                }
              });
            }
          });
        }
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  // Parse XML back to ExportData
  ExportData fromXML(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final bookmarksElement = document.rootElement;

      // Get version and exportedAt
      final version = bookmarksElement.getAttribute('version') ?? '1.0.0';
      final exportedAtStr = bookmarksElement.getAttribute('exportedAt');
      final exportedAt = exportedAtStr != null
          ? DateTime.parse(exportedAtStr)
          : DateTime.now();

      // Parse categories
      final categories = <Category>[];
      final categoriesElement = bookmarksElement.getElement('categories');
      if (categoriesElement != null) {
        for (final categoryElement
            in categoriesElement.findElements('category')) {
          final id = categoryElement.getAttribute('id') ?? '';
          final createdAtStr = categoryElement.getAttribute('createdAt');
          final updatedAtStr = categoryElement.getAttribute('updatedAt');
          final nameElement = categoryElement.getElement('name');
          final iconNameElement = categoryElement.getElement('iconName');

          if (nameElement != null) {
            categories.add(Category(
              id: id,
              name: nameElement.innerText,
              iconName: iconNameElement?.innerText,
              createdAt:
                  createdAtStr != null ? DateTime.parse(createdAtStr) : null,
              updatedAt:
                  updatedAtStr != null ? DateTime.parse(updatedAtStr) : null,
            ));
          }
        }
      }

      // Parse URLs
      final urls = <UrlItem>[];
      final urlsElement = bookmarksElement.getElement('urls');
      if (urlsElement != null) {
        for (final urlElement in urlsElement.findElements('url')) {
          final id = urlElement.getAttribute('id') ?? '';
          final categoryId = urlElement.getAttribute('categoryId') ?? '';
          final createdAtStr = urlElement.getAttribute('createdAt');
          final updatedAtStr = urlElement.getAttribute('updatedAt');
          final statusStr = urlElement.getAttribute('status') ?? 'unknown';

          final hrefElement = urlElement.getElement('href');
          final titleElement = urlElement.getElement('title');
          final descriptionElement = urlElement.getElement('description');
          final metadataElement = urlElement.getElement('metadata');

          if (hrefElement != null && titleElement != null) {
            // Parse metadata if available
            Map<String, dynamic>? metadata;
            if (metadataElement != null) {
              metadata = {};
              for (final item in metadataElement.findElements('item')) {
                final key = item.getAttribute('key');
                if (key != null) {
                  metadata[key] = item.innerText;
                }
              }
            }

            // Parse status
            final status = UrlStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => UrlStatus.unknown,
            );

            urls.add(UrlItem(
              id: id,
              url: hrefElement.innerText,
              title: titleElement.innerText,
              description: descriptionElement?.innerText,
              categoryId: categoryId,
              metadata: metadata,
              status: status,
              createdAt:
                  createdAtStr != null ? DateTime.parse(createdAtStr) : null,
              updatedAt:
                  updatedAtStr != null ? DateTime.parse(updatedAtStr) : null,
            ));
          }
        }
      }

      return ExportData(
        categories: categories,
        urls: urls,
        version: version,
        exportedAt: exportedAt,
      );
    } catch (e) {
      throw FormatException('Invalid XML format: $e');
    }
  }

  // Helper methods for HTML escaping
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");
  }
}
