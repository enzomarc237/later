import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A service for storing and retrieving data from files.
class FileStorageService {
  /// The base directory where files will be stored.
  final String basePath;

  /// Creates a new [FileStorageService] with the specified base path.
  /// If [basePath] is empty, the application documents directory will be used.
  FileStorageService({required this.basePath});

  /// Gets the storage directory.
  /// If [basePath] is empty or inaccessible, returns the application documents directory.
  /// Otherwise, returns the specified [basePath].
  Future<Directory> get _storageDirectory async {
    // Default to app documents directory with 'Later' subfolder
    final appDocDir = await getApplicationDocumentsDirectory();
    final defaultDir = Directory('${appDocDir.path}/Later');

    // If no custom path is specified, use the default
    if (basePath.isEmpty) {
      return defaultDir;
    }

    // Try to use the custom path
    final customDir = Directory(basePath);

    // Check if the custom directory is accessible
    try {
      // Test if we can create a temporary file in the directory
      final testFile = File('${customDir.path}/.write_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return customDir;
    } catch (e) {
      // If there's an error accessing the custom directory, log it and fall back to default
      debugPrint('Error accessing custom directory at $basePath: $e');
      debugPrint('Falling back to default directory: ${defaultDir.path}');
      return defaultDir;
    }
  }

  /// Ensures that the storage directory exists.
  Future<void> ensureDirectoryExists() async {
    try {
      final directory = await _storageDirectory;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error creating directory: $e');
      // Fall back to app documents directory if we can't create the custom directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final defaultDir = Directory('${appDocDir.path}/Later');
      if (!await defaultDir.exists()) {
        await defaultDir.create(recursive: true);
      }
    }
  }

  /// Reads a JSON file from the storage directory.
  /// Returns null if the file doesn't exist or an error occurs.
  Future<Map<String, dynamic>?> readJsonFile(String fileName) async {
    try {
      await ensureDirectoryExists();
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading JSON file $fileName: $e');
      return null;
    }
  }

  /// Reads a JSON list file from the storage directory.
  /// Returns an empty list if the file doesn't exist or an error occurs.
  Future<List<dynamic>> readJsonListFile(String fileName) async {
    try {
      await ensureDirectoryExists();
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');

      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      debugPrint('Error reading JSON list file $fileName: $e');
      return [];
    }
  }

  /// Writes a JSON object to a file in the storage directory.
  Future<void> writeJsonFile(String fileName, Map<String, dynamic> data) async {
    try {
      await ensureDirectoryExists();
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');

      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error writing JSON file $fileName: $e');
    }
  }

  /// Writes a JSON list to a file in the storage directory.
  Future<void> writeJsonListFile(String fileName, List<dynamic> data) async {
    try {
      await ensureDirectoryExists();
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');

      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error writing JSON list file $fileName: $e');
    }
  }

  /// Deletes a file from the storage directory.
  Future<void> deleteFile(String fileName) async {
    try {
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file $fileName: $e');
    }
  }

  /// Checks if a file exists in the storage directory.
  Future<bool> fileExists(String fileName) async {
    try {
      final directory = await _storageDirectory;
      final file = File('${directory.path}/$fileName');
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking if file $fileName exists: $e');
      return false;
    }
  }
}
