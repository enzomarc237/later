import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/providers.dart';

/// Exception thrown when file operations fail
class FileStorageException implements Exception {
  final String message;
  final String? filename;
  final Object? originalError;

  FileStorageException(this.message, {this.filename, this.originalError});

  @override
  String toString() {
    return 'FileStorageException: $message${filename != null ? ' (file: $filename)' : ''}${originalError != null ? '\nOriginal error: $originalError' : ''}';
  }
}

/// A service for storing and retrieving data from files.
///
/// This service provides methods for reading and writing JSON data to files,
/// with robust error handling, data validation, and performance optimizations.
class FileStorageService {
  /// The path to the directory where files are stored.
  final String dataFolderPath;

  /// In-memory cache for frequently accessed files
  final Map<String, dynamic> _cache = {};

  /// Lock objects to prevent concurrent writes to the same file
  final Map<String, Lock> _locks = {};

  /// Creates a new [FileStorageService] with the specified data folder path.
  FileStorageService(this.dataFolderPath);

  /// Initializes the data directory.
  ///
  /// Creates the directory if it doesn't exist.
  Future<void> initialize() async {
    try {
      if (dataFolderPath.isEmpty) {
        // Use application documents directory if no path is specified
        final appDocDir = await getApplicationDocumentsDirectory();
        final defaultPath = path.join(appDocDir.path, 'Later');
        debugPrint('Data folder path is empty, using default: $defaultPath');

        // Create the directory if it doesn't exist
        final defaultDir = Directory(defaultPath);
        if (!await defaultDir.exists()) {
          await defaultDir.create(recursive: true);
        }

        // We can't modify dataFolderPath directly as it's final, but we can log this
        debugPrint(
            'Note: Using default path, but dataFolderPath remains empty');
        return;
      }

      final dataDir = Directory(dataFolderPath);
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      debugPrint('Data directory initialized at: ${dataDir.path}');
    } catch (e) {
      debugPrint('Error initializing data directory: $e');
      throw FileStorageException('Failed to initialize data directory',
          originalError: e);
    }
  }

  /// Gets a lock for the specified filename.
  ///
  /// This ensures that only one write operation can occur on a file at a time.
  Lock _getLock(String filename) {
    return _locks.putIfAbsent(filename, () => Lock());
  }

  /// Writes a list of JSON objects to a file.
  ///
  /// Uses atomic write operations to prevent data corruption.
  Future<void> writeJsonListFile(
      String filename, List<Map<String, dynamic>> jsonDataList) async {
    final lock = _getLock(filename);
    return lock.synchronized(() async {
      try {
        // Validate inputs
        if (filename.isEmpty) {
          throw FileStorageException('Filename is empty');
        }

        // Get the file path, handling empty dataFolderPath
        String filePath;
        if (dataFolderPath.isEmpty) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final defaultPath = path.join(appDocDir.path, 'Later');

          // Create the directory if it doesn't exist
          final defaultDir = Directory(defaultPath);
          if (!await defaultDir.exists()) {
            await defaultDir.create(recursive: true);
          }

          filePath = path.join(defaultPath, filename);
          debugPrint('Using default path for file: $filePath');
        } else {
          filePath = path.join(dataFolderPath, filename);
        }

        // Create a temporary file
        final file = File(filePath);
        final tempFile = File('${file.path}.tmp');

        // Write to the temporary file first
        final content = jsonEncode(jsonDataList);
        await tempFile.writeAsString(content, flush: true);

        // If the write was successful, rename the temp file to the actual file
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);

        // Update cache
        _cache[filename] = jsonDataList;

        debugPrint(
            'Successfully wrote ${jsonDataList.length} items to $filename');
      } catch (e) {
        debugPrint('Error writing to $filename: $e');
        throw FileStorageException('Failed to write JSON list to file',
            filename: filename, originalError: e);
      }
    });
  }

  /// Writes a JSON object to a file.
  ///
  /// Uses atomic write operations to prevent data corruption.
  Future<void> writeJsonFile(
      String filename, Map<String, dynamic> jsonData) async {
    final lock = _getLock(filename);
    return lock.synchronized(() async {
      try {
        // Validate inputs
        if (filename.isEmpty) {
          throw FileStorageException('Filename is empty');
        }

        // Get the file path, handling empty dataFolderPath
        String filePath;
        if (dataFolderPath.isEmpty) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final defaultPath = path.join(appDocDir.path, 'Later');

          // Create the directory if it doesn't exist
          final defaultDir = Directory(defaultPath);
          if (!await defaultDir.exists()) {
            await defaultDir.create(recursive: true);
          }

          filePath = path.join(defaultPath, filename);
          debugPrint('Using default path for file: $filePath');
        } else {
          filePath = path.join(dataFolderPath, filename);
        }

        // Create a temporary file
        final file = File(filePath);
        final tempFile = File('${file.path}.tmp');

        // Write to the temporary file first
        final content = jsonEncode(jsonData);
        await tempFile.writeAsString(content, flush: true);

        // If the write was successful, rename the temp file to the actual file
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);

        // Update cache
        _cache[filename] = jsonData;

        debugPrint('Successfully wrote data to $filename');
      } catch (e) {
        debugPrint('Error writing to $filename: $e');
        throw FileStorageException('Failed to write JSON to file',
            filename: filename, originalError: e);
      }
    });
  }

  /// Reads a list of JSON objects from a file.
  ///
  /// Returns an empty list if the file doesn't exist or is empty.
  /// Validates the data structure to ensure it's a valid list of maps.
  Future<List<Map<String, dynamic>>> readJsonListFile(String filename) async {
    try {
      // Check cache first
      if (_cache.containsKey(filename)) {
        final cachedData = _cache[filename];
        if (cachedData is List<Map<String, dynamic>>) {
          return cachedData;
        }
      }

      // Validate inputs
      if (filename.isEmpty) {
        throw FileStorageException('Filename is empty');
      }

      // Get the file path, handling empty dataFolderPath
      String filePath;
      if (dataFolderPath.isEmpty) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final defaultPath = path.join(appDocDir.path, 'Later');
        filePath = path.join(defaultPath, filename);
        debugPrint('Using default path for reading file: $filePath');
      } else {
        filePath = path.join(dataFolderPath, filename);
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File $filename does not exist, returning empty list');
        return []; // Return empty list if file doesn't exist
      }

      final content = await file.readAsString();
      if (content.isEmpty) {
        debugPrint('File $filename is empty, returning empty list');
        return []; // Return empty list if file is empty
      }

      // Parse and validate JSON
      try {
        final jsonData = jsonDecode(content);
        if (jsonData is! List) {
          throw FileStorageException('Invalid JSON format: expected a list',
              filename: filename);
        }

        // Validate each item in the list is a map
        final typedList = jsonData.map((item) {
          if (item is! Map<String, dynamic>) {
            throw FileStorageException(
                'Invalid JSON format: list item is not a map',
                filename: filename);
          }
          return item;
        }).toList();

        // Update cache
        _cache[filename] = typedList;

        return typedList;
      } catch (e) {
        if (e is FileStorageException) rethrow;
        throw FileStorageException('Failed to parse JSON list',
            filename: filename, originalError: e);
      }
    } catch (e) {
      if (e is FileStorageException) rethrow;
      debugPrint('Error reading from $filename: $e');
      throw FileStorageException('Failed to read JSON list from file',
          filename: filename, originalError: e);
    }
  }

  /// Reads a JSON object from a file.
  ///
  /// Returns null if the file doesn't exist or is empty.
  /// Validates the data structure to ensure it's a valid map.
  Future<Map<String, dynamic>?> readJsonFile(String filename) async {
    try {
      // Check cache first
      if (_cache.containsKey(filename)) {
        final cachedData = _cache[filename];
        if (cachedData is Map<String, dynamic>) {
          return cachedData;
        }
      }

      // Validate inputs
      if (filename.isEmpty) {
        throw FileStorageException('Filename is empty');
      }

      // Get the file path, handling empty dataFolderPath
      String filePath;
      if (dataFolderPath.isEmpty) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final defaultPath = path.join(appDocDir.path, 'Later');
        filePath = path.join(defaultPath, filename);
        debugPrint('Using default path for reading file: $filePath');
      } else {
        filePath = path.join(dataFolderPath, filename);
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File $filename does not exist, returning null');
        return null; // Return null if file doesn't exist
      }

      final content = await file.readAsString();
      if (content.isEmpty) {
        debugPrint('File $filename is empty, returning null');
        return null; // Return null if file is empty
      }

      // Parse and validate JSON
      try {
        final jsonData = jsonDecode(content);
        if (jsonData is! Map<String, dynamic>) {
          throw FileStorageException('Invalid JSON format: expected a map',
              filename: filename);
        }

        // Update cache
        _cache[filename] = jsonData;

        return jsonData;
      } catch (e) {
        if (e is FileStorageException) rethrow;
        throw FileStorageException('Failed to parse JSON',
            filename: filename, originalError: e);
      }
    } catch (e) {
      if (e is FileStorageException) rethrow;
      debugPrint('Error reading from $filename: $e');
      throw FileStorageException('Failed to read JSON from file',
          filename: filename, originalError: e);
    }
  }

  /// Deletes a file.
  Future<void> deleteFile(String filename) async {
    final lock = _getLock(filename);
    return lock.synchronized(() async {
      try {
        // Validate inputs
        if (dataFolderPath.isEmpty) {
          throw FileStorageException('Data folder path is empty',
              filename: filename);
        }
        if (filename.isEmpty) {
          throw FileStorageException('Filename is empty');
        }

        final file = File(path.join(dataFolderPath, filename));
        if (await file.exists()) {
          await file.delete();
          // Remove from cache
          _cache.remove(filename);
          debugPrint('Successfully deleted $filename');
        } else {
          debugPrint('File $filename does not exist, nothing to delete');
        }
      } catch (e) {
        debugPrint('Error deleting $filename: $e');
        throw FileStorageException('Failed to delete file',
            filename: filename, originalError: e);
      }
    });
  }

  /// Checks if a file exists.
  Future<bool> fileExists(String filename) async {
    try {
      // Validate inputs
      if (dataFolderPath.isEmpty) {
        throw FileStorageException('Data folder path is empty',
            filename: filename);
      }
      if (filename.isEmpty) {
        throw FileStorageException('Filename is empty');
      }

      final file = File(path.join(dataFolderPath, filename));
      return file.exists();
    } catch (e) {
      debugPrint('Error checking if $filename exists: $e');
      throw FileStorageException('Failed to check if file exists',
          filename: filename, originalError: e);
    }
  }

  /// Clears the in-memory cache for a specific file.
  void clearCache(String filename) {
    _cache.remove(filename);
  }

  /// Clears the entire in-memory cache.
  void clearAllCache() {
    _cache.clear();
  }

  /// Creates a backup of a file.
  Future<void> backupFile(String filename) async {
    final lock = _getLock(filename);
    return lock.synchronized(() async {
      try {
        // Validate inputs
        if (dataFolderPath.isEmpty) {
          throw FileStorageException('Data folder path is empty',
              filename: filename);
        }
        if (filename.isEmpty) {
          throw FileStorageException('Filename is empty');
        }

        final file = File(path.join(dataFolderPath, filename));
        if (await file.exists()) {
          final backupFile = File('${file.path}.bak');
          await file.copy(backupFile.path);
          debugPrint('Successfully created backup of $filename');
        } else {
          debugPrint('File $filename does not exist, cannot create backup');
        }
      } catch (e) {
        debugPrint('Error creating backup of $filename: $e');
        throw FileStorageException('Failed to create backup of file',
            filename: filename, originalError: e);
      }
    });
  }

  /// Restores a file from its backup.
  Future<bool> restoreFromBackup(String filename) async {
    final lock = _getLock(filename);
    return lock.synchronized(() async {
      try {
        // Validate inputs
        if (dataFolderPath.isEmpty) {
          throw FileStorageException('Data folder path is empty',
              filename: filename);
        }
        if (filename.isEmpty) {
          throw FileStorageException('Filename is empty');
        }

        final file = File(path.join(dataFolderPath, filename));
        final backupFile = File('${file.path}.bak');

        if (await backupFile.exists()) {
          if (await file.exists()) {
            await file.delete();
          }
          await backupFile.copy(file.path);

          // Clear cache for this file
          _cache.remove(filename);

          debugPrint('Successfully restored $filename from backup');
          return true;
        } else {
          debugPrint('Backup file for $filename does not exist');
          return false;
        }
      } catch (e) {
        debugPrint('Error restoring $filename from backup: $e');
        throw FileStorageException('Failed to restore file from backup',
            filename: filename, originalError: e);
      }
    });
  }
}

/// A simple lock implementation for synchronizing file operations.
class Lock {
  Completer<void>? _completer;

  /// Executes the given function while holding the lock.
  Future<T> synchronized<T>(Future<T> Function() function) async {
    // Wait for any ongoing operation to complete
    if (_completer != null) {
      await _completer!.future;
    }

    // Create a new completer for this operation
    _completer = Completer<void>();

    try {
      // Execute the function
      return await function();
    } finally {
      // Release the lock
      _completer!.complete();
      _completer = null;
    }
  }
}

/// Provider for the FileStorageService.
final fileStorageServiceUtilProvider = Provider<FileStorageService>((ref) {
  final dataFolderPath = ref.read(dataFolderPathProvider);
  return FileStorageService(dataFolderPath);
});
