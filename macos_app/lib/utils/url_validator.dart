import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Callback for validation progress updates
typedef ValidationProgressCallback = void Function(int completed, int total, String currentUrl);

/// Callback for metadata updates
typedef MetadataUpdateCallback = void Function(String url, Map<String, dynamic> metadata);

/// Enum representing the status of a URL validation check
enum UrlStatus {
  /// The URL hasn't been validated yet
  unknown,

  /// The URL is accessible (returns a success status code)
  valid,

  /// The URL is not accessible (returns an error status code)
  invalid,

  /// The URL request timed out
  timeout,

  /// There was an error validating the URL (e.g., malformed URL)
  error
}

/// Extension on UrlStatus to provide helper methods
extension UrlStatusExtension on UrlStatus {
  /// Returns a human-readable status message
  String get message {
    switch (this) {
      case UrlStatus.unknown:
        return 'Not validated';
      case UrlStatus.valid:
        return 'Valid';
      case UrlStatus.invalid:
        return 'Invalid';
      case UrlStatus.timeout:
        return 'Timeout';
      case UrlStatus.error:
        return 'Error';
    }
  }

  /// Returns true if the URL is valid
  bool get isValid => this == UrlStatus.valid;

  /// Returns true if the URL is invalid, timed out, or had an error
  bool get isInvalid => this == UrlStatus.invalid || this == UrlStatus.timeout || this == UrlStatus.error;

  /// Returns true if the URL status is unknown
  bool get isUnknown => this == UrlStatus.unknown;

  /// Returns the appropriate color for this status based on the theme
  Color getColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (this) {
      case UrlStatus.unknown:
        return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      case UrlStatus.valid:
        return isDark ? Colors.green.shade400 : Colors.green.shade700;
      case UrlStatus.invalid:
        return isDark ? Colors.red.shade400 : Colors.red.shade700;
      case UrlStatus.timeout:
        return isDark ? Colors.orange.shade400 : Colors.orange.shade700;
      case UrlStatus.error:
        return isDark ? Colors.red.shade400 : Colors.red.shade700;
    }
  }

  /// Legacy color getter for backward compatibility
  Color get color {
    switch (this) {
      case UrlStatus.unknown:
        return Colors.grey;
      case UrlStatus.valid:
        return Colors.green;
      case UrlStatus.invalid:
        return Colors.red;
      case UrlStatus.timeout:
        return Colors.orange;
      case UrlStatus.error:
        return Colors.red;
    }
  }
}

/// Service for validating URLs
class UrlValidator {
  /// Timeout duration for URL validation requests
  final Duration timeout;

  /// Maximum number of redirects to follow
  final int maxRedirects;

  /// HTTP client for making requests
  final http.Client _client;

  /// Creates a new URL validator with the specified timeout and max redirects
  UrlValidator({
    this.timeout = const Duration(seconds: 10),
    this.maxRedirects = 5,
  }) : _client = http.Client();

  /// Validates a single URL and returns its status
  Future<UrlStatus> validateUrl(String url) async {
    if (url.isEmpty) {
      return UrlStatus.error;
    }

    try {
      // Ensure the URL has a scheme
      Uri uri;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      try {
        uri = Uri.parse(url);
      } catch (e) {
        debugPrint('Error parsing URL: $e');
        return UrlStatus.error;
      }

      try {
        // Make a HEAD request first (faster, doesn't download the body)
        final response = await _client.head(uri).timeout(timeout);

        // Check if the response is successful (status code 200-299)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return UrlStatus.valid;
        } else if (response.statusCode >= 300 && response.statusCode < 400) {
          // Handle redirects manually if needed
          if (maxRedirects > 0) {
            final location = response.headers['location'];
            if (location != null) {
              return validateUrl(location);
            }
          }
          // If we can't follow the redirect, consider it valid
          return UrlStatus.valid;
        } else {
          return UrlStatus.invalid;
        }
      } catch (e) {
        // Some servers don't support HEAD requests, try GET as fallback
        try {
          final response = await _client.get(uri).timeout(timeout);

          // Check if the response is successful (status code 200-299)
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return UrlStatus.valid;
          } else {
            return UrlStatus.invalid;
          }
        } catch (e) {
          if (e is TimeoutException) {
            return UrlStatus.timeout;
          } else {
            debugPrint('Error validating URL: $e');
            return UrlStatus.error;
          }
        }
      }
    } catch (e) {
      if (e is TimeoutException) {
        return UrlStatus.timeout;
      } else {
        debugPrint('Error validating URL: $e');
        return UrlStatus.error;
      }
    }
  }

  /// Validates multiple URLs in parallel with progress updates
  Future<Map<String, UrlStatus>> validateUrls(
    List<String> urls, {
    ValidationProgressCallback? onProgress,
    MetadataUpdateCallback? onMetadataUpdated,
    int batchSize = 5, // Number of concurrent validations
  }) async {
    final results = <String, UrlStatus>{};
    int completed = 0;

    // Process URLs in batches
    for (var i = 0; i < urls.length; i += batchSize) {
      final batch = urls.skip(i).take(batchSize);
      final futures = batch.map((url) async {
        final status = await validateUrl(url);
        
        // Try to fetch favicon for all URLs, not just valid ones
        try {
          final uri = Uri.parse(url);
          
          // First try to fetch favicon from standard location
          final faviconUrl = '${uri.scheme}://${uri.host}/favicon.ico';
          try {
            final response = await _client.head(Uri.parse(faviconUrl)).timeout(
                  const Duration(seconds: 5),
                );
            
            if (response.statusCode == 200) {
              onMetadataUpdated?.call(url, {'faviconUrl': faviconUrl});
            }
          } catch (e) {
            debugPrint('Error fetching standard favicon for $url: $e');
            
            // If standard favicon fails, try to fetch HTML and extract favicon URL
            try {
              final htmlResponse = await _client.get(uri).timeout(
                    const Duration(seconds: 10),
                  );
              
              if (htmlResponse.statusCode == 200) {
                // Use a simple regex to find favicon links
                final html = htmlResponse.body;
                final regExp = RegExp(r'<link[^>]*rel=["\'](icon|shortcut icon)["\'][^>]*href=["\'](.*?)["\'][^>]*>', caseSensitive: false);
                final match = regExp.firstMatch(html);
                
                if (match != null && match.groupCount >= 2) {
                  var iconHref = match.group(2)!;
                  
                  // Handle relative URLs
                  if (iconHref.startsWith('/')) {
                    iconHref = '${uri.scheme}://${uri.host}$iconHref';
                  } else if (!iconHref.startsWith('http')) {
                    iconHref = '${uri.scheme}://${uri.host}/$iconHref';
                  }
                  
                  onMetadataUpdated?.call(url, {'faviconUrl': iconHref});
                }
              }
            } catch (e) {
              debugPrint('Error extracting favicon from HTML for $url: $e');
            }
          }
        } catch (e) {
          debugPrint('Error processing favicon for $url: $e');
        }

        completed++;
        onProgress?.call(completed, urls.length, url);
        return MapEntry(url, status);
      });

      final batchResults = await Future.wait(futures);
      results.addEntries(batchResults);
    }

    return results;
  }

  /// Disposes the HTTP client
  void dispose() {
    _client.close();
  }
}
