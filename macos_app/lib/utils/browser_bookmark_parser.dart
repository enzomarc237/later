import 'dart:convert';
import 'package:flutter/cupertino.dart';

import '../models/category.dart';
import '../models/url_item.dart';
import '../models/export_data.dart';

/// A utility class for parsing browser bookmark files.
class BrowserBookmarkParser {
  /// Parses Chrome bookmarks JSON file.
  /// 
  /// Chrome bookmarks are exported as a JSON file with a specific structure.
  ExportData parseChrome(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final roots = json['roots'] as Map<String, dynamic>?;
      
      if (roots == null) {
        throw FormatException('Invalid Chrome bookmarks format: missing roots');
      }
      
      final categories = <Category>[];
      final urls = <UrlItem>[];
      
      // Process bookmark bar
      _processFolder(roots['bookmark_bar'], '', categories, urls);
      
      // Process other bookmarks
      _processFolder(roots['other'], '', categories, urls);
      
      return ExportData(
        categories: categories,
        urls: urls,
        version: '1.0.0',
      );
    } catch (e) {
      debugPrint('Error parsing Chrome bookmarks: $e');
      throw FormatException('Failed to parse Chrome bookmarks: $e');
    }
  }
  
  /// Processes a Chrome bookmark folder recursively.
  void _processFolder(Map<String, dynamic>? folder, String parentId, 
      List<Category> categories, List<UrlItem> urls) {
    if (folder == null) return;
    
    final name = folder['name'] as String? ?? 'Unnamed Folder';
    final children = folder['children'] as List<dynamic>? ?? [];
    
    // Create category for this folder
    final categoryId = name.toLowerCase().replaceAll(' ', '_') + 
        (parentId.isNotEmpty ? '_$parentId' : '');
    
    // Skip root level
    if (name != 'Bookmarks Bar' && name != 'Other Bookmarks') {
      categories.add(Category(
        id: categoryId,
        name: name,
      ));
    }
    
    // Process children
    for (final child in children) {
      final type = child['type'] as String?;
      
      if (type == 'url') {
        // This is a bookmark
        final url = child['url'] as String?;
        final title = child['name'] as String? ?? 'Untitled';
        final addedTime = child['date_added'] as String?;
        
        if (url != null) {
          urls.add(UrlItem(
            url: url,
            title: title,
            categoryId: categoryId.isEmpty ? 'uncategorized' : categoryId,
            createdAt: addedTime != null 
                ? DateTime.fromMillisecondsSinceEpoch(int.parse(addedTime) ~/ 1000)
                : DateTime.now(),
          ));
        }
      } else if (type == 'folder') {
        // Recursively process subfolders
        _processFolder(child, categoryId, categories, urls);
      }
    }
  }
  
  /// Parses Firefox bookmarks HTML file.
  /// 
  /// Firefox bookmarks are exported as an HTML file with a specific structure.
  ExportData parseFirefox(String content) {
    try {
      final categories = <Category>[];
      final urls = <UrlItem>[];
      
      // Add default category
      categories.add(Category(
        id: 'firefox_bookmarks',
        name: 'Firefox Bookmarks',
      ));
      
      // Extract bookmarks using regex
      final regex = RegExp(r'<A HREF="([^"]+)"[^>]*>([^<]+)</A>', caseSensitive: false);
      final matches = regex.allMatches(content);
      
      for (final match in matches) {
        final url = match.group(1);
        final title = match.group(2);
        
        if (url != null && title != null) {
          urls.add(UrlItem(
            url: url,
            title: title,
            categoryId: 'firefox_bookmarks',
          ));
        }
      }
      
      // Try to extract folders and organize bookmarks
      _extractFirefoxFolders(content, categories, urls);
      
      return ExportData(
        categories: categories,
        urls: urls,
        version: '1.0.0',
      );
    } catch (e) {
      debugPrint('Error parsing Firefox bookmarks: $e');
      throw FormatException('Failed to parse Firefox bookmarks: $e');
    }
  }
  
  /// Extracts folder structure from Firefox bookmarks HTML.
  void _extractFirefoxFolders(String content, List<Category> categories, List<UrlItem> urls) {
    try {
      // Extract folder structure
      final folderRegex = RegExp(r'<DT><H3[^>]*>([^<]+)</H3>', caseSensitive: false);
      final folderMatches = folderRegex.allMatches(content);
      
      // Create categories for each folder
      for (final match in folderMatches) {
        final folderName = match.group(1);
        if (folderName != null && folderName != 'Firefox Bookmarks') {
          final categoryId = folderName.toLowerCase().replaceAll(' ', '_');
          
          // Check if category already exists
          if (!categories.any((c) => c.id == categoryId)) {
            categories.add(Category(
              id: categoryId,
              name: folderName,
            ));
          }
          
          // Find bookmarks in this folder
          final folderStart = match.end;
          final folderEnd = content.indexOf('</DL>', folderStart);
          if (folderEnd > folderStart) {
            final folderContent = content.substring(folderStart, folderEnd);
            final bookmarkRegex = RegExp(r'<A HREF="([^"]+)"[^>]*>([^<]+)</A>', caseSensitive: false);
            final bookmarkMatches = bookmarkRegex.allMatches(folderContent);
            
            for (final bookmarkMatch in bookmarkMatches) {
              final url = bookmarkMatch.group(1);
              final title = bookmarkMatch.group(2);
              
              if (url != null && title != null) {
                // Check if this URL is already in the list
                final existingIndex = urls.indexWhere((u) => u.url == url && u.title == title);
                
                if (existingIndex >= 0) {
                  // Update category of existing URL
                  urls[existingIndex] = urls[existingIndex].copyWith(categoryId: categoryId);
                } else {
                  // Add new URL
                  urls.add(UrlItem(
                    url: url,
                    title: title,
                    categoryId: categoryId,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting Firefox folders: $e');
      // Continue without folder structure
    }
  }
  
  /// Parses Safari bookmarks plist file.
  /// 
  /// Safari bookmarks are exported as a plist file, which we'll parse as XML.
  ExportData parseSafari(String content) {
    try {
      final categories = <Category>[];
      final urls = <UrlItem>[];
      
      // Add default category
      categories.add(Category(
        id: 'safari_bookmarks',
        name: 'Safari Bookmarks',
      ));
      
      // Extract bookmarks using regex for simple XML parsing
      final regex = RegExp(r'<key>URLString</key>\s*<string>([^<]+)</string>.*?<key>URIDictionary</key>.*?<key>title</key>\s*<string>([^<]+)</string>', 
          caseSensitive: false, dotAll: true);
      final matches = regex.allMatches(content);
      
      for (final match in matches) {
        final url = match.group(1);
        final title = match.group(2);
        
        if (url != null && title != null) {
          urls.add(UrlItem(
            url: url,
            title: title,
            categoryId: 'safari_bookmarks',
          ));
        }
      }
      
      return ExportData(
        categories: categories,
        urls: urls,
        version: '1.0.0',
      );
    } catch (e) {
      debugPrint('Error parsing Safari bookmarks: $e');
      throw FormatException('Failed to parse Safari bookmarks: $e');
    }
  }
  
  /// Detects the browser format from the content and parses accordingly.
  ExportData parseAuto(String content) {
    // Try to detect format based on content
    if (content.contains('"roots"') && content.contains('"bookmark_bar"')) {
      return parseChrome(content);
    } else if (content.contains('<!DOCTYPE NETSCAPE-Bookmark-file-1>') || 
               content.contains('<DT><A HREF=')) {
      return parseFirefox(content);
    } else if (content.contains('<!DOCTYPE plist') || 
               (content.contains('<key>WebBookmarkType</key>') && 
                content.contains('<key>URLString</key>'))) {
      return parseSafari(content);
    } else {
      throw FormatException('Unrecognized browser bookmark format');
    }
  }
}