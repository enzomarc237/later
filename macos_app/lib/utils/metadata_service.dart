import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:http/http.dart' as http;

/// A service for fetching metadata and favicons from websites.
class MetadataService {
  /// The default cache manager for storing favicons.
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  /// Fetches metadata from a URL.
  /// 
  /// Returns a [WebsiteMetadata] object containing the extracted metadata.
  Future<WebsiteMetadata> fetchMetadata(String url) async {
    try {
      // Ensure URL has a scheme
      final Uri uri = _ensureScheme(url);
      
      // Fetch HTML content
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return WebsiteMetadata(
          url: url,
          title: null,
          description: null,
          faviconUrl: null,
          error: 'Failed to fetch website: HTTP ${response.statusCode}',
        );
      }

      // Parse HTML
      final document = html_parser.parse(response.body);
      
      // Extract metadata
      final title = _extractTitle(document);
      final description = _extractDescription(document);
      final faviconUrl = _extractFaviconUrl(document, uri);

      // Return metadata
      return WebsiteMetadata(
        url: url,
        title: title,
        description: description,
        faviconUrl: faviconUrl,
      );
    } catch (e) {
      debugPrint('Error fetching metadata for $url: $e');
      return WebsiteMetadata(
        url: url,
        title: null,
        description: null,
        faviconUrl: null,
        error: 'Error fetching metadata: $e',
      );
    }
  }

  /// Fetches a favicon from a URL.
  /// 
  /// Returns the favicon data as a [Uint8List] or null if the favicon couldn't be fetched.
  Future<Uint8List?> fetchFavicon(String? faviconUrl) async {
    if (faviconUrl == null) return null;

    try {
      // Try to get from cache first
      final fileInfo = await _cacheManager.getFileFromCache(faviconUrl);
      if (fileInfo != null) {
        return await fileInfo.file.readAsBytes();
      }

      // Fetch and cache favicon
      final Uri uri = _ensureScheme(faviconUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      // Cache the favicon
      await _cacheManager.putFile(
        faviconUrl,
        response.bodyBytes,
        key: faviconUrl,
        maxAge: const Duration(days: 7), // Cache for 7 days
      );

      return response.bodyBytes;
    } catch (e) {
      debugPrint('Error fetching favicon from $faviconUrl: $e');
      return null;
    }
  }

  /// Ensures that a URL has a scheme (http:// or https://).
  /// 
  /// If the URL doesn't have a scheme, http:// is added.
  Uri _ensureScheme(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return Uri.parse(url);
  }

  /// Extracts the title from an HTML document.
  String? _extractTitle(html_dom.Document document) {
    // Try to get title from Open Graph meta tag
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null && ogTitle.attributes.containsKey('content')) {
      return ogTitle.attributes['content'];
    }

    // Try to get title from Twitter meta tag
    final twitterTitle = document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null && twitterTitle.attributes.containsKey('content')) {
      return twitterTitle.attributes['content'];
    }

    // Fall back to regular title tag
    final titleTag = document.querySelector('title');
    if (titleTag != null) {
      return titleTag.text;
    }

    return null;
  }

  /// Extracts the description from an HTML document.
  String? _extractDescription(html_dom.Document document) {
    // Try to get description from Open Graph meta tag
    final ogDescription = document.querySelector('meta[property="og:description"]');
    if (ogDescription != null && ogDescription.attributes.containsKey('content')) {
      return ogDescription.attributes['content'];
    }

    // Try to get description from Twitter meta tag
    final twitterDescription = document.querySelector('meta[name="twitter:description"]');
    if (twitterDescription != null && twitterDescription.attributes.containsKey('content')) {
      return twitterDescription.attributes['content'];
    }

    // Fall back to regular meta description
    final metaDescription = document.querySelector('meta[name="description"]');
    if (metaDescription != null && metaDescription.attributes.containsKey('content')) {
      return metaDescription.attributes['content'];
    }

    return null;
  }

  /// Extracts the favicon URL from an HTML document.
  String? _extractFaviconUrl(html_dom.Document document, Uri baseUri) {
    // Try to get favicon from link tag with rel="icon" or rel="shortcut icon"
    final iconLinks = document.querySelectorAll('link[rel="icon"], link[rel="shortcut icon"]');
    if (iconLinks.isNotEmpty) {
      // Sort by size (prefer larger icons)
      iconLinks.sort((a, b) {
        final aSizes = a.attributes['sizes']?.split('x') ?? ['0'];
        final bSizes = b.attributes['sizes']?.split('x') ?? ['0'];
        final aSize = int.tryParse(aSizes[0]) ?? 0;
        final bSize = int.tryParse(bSizes[0]) ?? 0;
        return bSize.compareTo(aSize);
      });

      final href = iconLinks.first.attributes['href'];
      if (href != null) {
        // Handle relative URLs
        if (href.startsWith('/')) {
          return '${baseUri.scheme}://${baseUri.host}$href';
        } else if (!href.startsWith('http')) {
          return '${baseUri.scheme}://${baseUri.host}/${href}';
        }
        return href;
      }
    }

    // Fall back to default favicon.ico
    return '${baseUri.scheme}://${baseUri.host}/favicon.ico';
  }
}

/// A class representing metadata extracted from a website.
class WebsiteMetadata {
  /// The URL of the website.
  final String url;
  
  /// The title of the website.
  final String? title;
  
  /// The description of the website.
  final String? description;
  
  /// The URL of the website's favicon.
  final String? faviconUrl;
  
  /// Any error that occurred while fetching the metadata.
  final String? error;

  /// Creates a new [WebsiteMetadata] instance.
  WebsiteMetadata({
    required this.url,
    this.title,
    this.description,
    this.faviconUrl,
    this.error,
  });

  /// Converts the metadata to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'faviconUrl': faviconUrl,
      'error': error,
    };
  }

  /// Creates a new [WebsiteMetadata] instance from a JSON map.
  factory WebsiteMetadata.fromJson(Map<String, dynamic> json) {
    return WebsiteMetadata(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
      error: json['error'] as String?,
    );
  }
}