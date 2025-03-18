import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  
  /// Returns the appropriate color for this status
  /// This can be used to visually indicate the status in the UI
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
  
  /// Validates multiple URLs and returns a map of URL to status
  Future<Map<String, UrlStatus>> validateUrls(List<String> urls) async {
    final results = <String, UrlStatus>{};
    
    for (final url in urls) {
      results[url] = await validateUrl(url);
    }
    
    return results;
  }
  
  /// Disposes the HTTP client
  void dispose() {
    _client.close();
  }
}