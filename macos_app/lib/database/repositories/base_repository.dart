import 'package:flutter/foundation.dart';
import '../database.dart';

/// Base repository class that provides common functionality for all repositories.
/// 
/// This abstract class serves as a foundation for all repository implementations,
/// providing access to the database and common error handling.
abstract class BaseRepository {
  /// The database instance used by this repository.
  final LaterDatabase database;

  /// Creates a new repository with the given [database].
  BaseRepository(this.database);

  /// Executes a database operation with proper error handling.
  /// 
  /// This method wraps database operations in try-catch blocks and provides
  /// consistent error handling and logging.
  /// 
  /// Parameters:
  /// - [operation]: The operation to execute.
  /// - [errorMessage]: The message to log if an error occurs.
  /// 
  /// Returns the result of the operation, or null if an error occurred.
  Future<T?> executeDbOperation<T>(
    Future<T> Function() operation,
    String errorMessage,
  ) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      debugPrint('$errorMessage: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Executes a database operation with proper error handling and returns a default value on error.
  /// 
  /// This method is similar to [executeDbOperation], but it returns a default value
  /// instead of null if an error occurs.
  /// 
  /// Parameters:
  /// - [operation]: The operation to execute.
  /// - [errorMessage]: The message to log if an error occurs.
  /// - [defaultValue]: The value to return if an error occurs.
  /// 
  /// Returns the result of the operation, or the default value if an error occurred.
  Future<T> executeDbOperationWithDefault<T>(
    Future<T> Function() operation,
    String errorMessage,
    T defaultValue,
  ) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      debugPrint('$errorMessage: $e');
      debugPrint('Stack trace: $stackTrace');
      return defaultValue;
    }
  }

  /// Executes a database operation that returns a stream with proper error handling.
  /// 
  /// This method wraps database operations that return streams in try-catch blocks
  /// and provides consistent error handling and logging.
  /// 
  /// Parameters:
  /// - [operation]: The operation to execute.
  /// - [errorMessage]: The message to log if an error occurs.
  /// - [defaultValue]: The value to emit if an error occurs.
  /// 
  /// Returns a stream that emits the results of the operation, or a stream that
  /// emits the default value if an error occurred.
  Stream<T> executeDbStreamOperation<T>(
    Stream<T> Function() operation,
    String errorMessage,
    T defaultValue,
  ) {
    try {
      return operation().handleError((e, stackTrace) {
        debugPrint('$errorMessage: $e');
        debugPrint('Stack trace: $stackTrace');
      });
    } catch (e, stackTrace) {
      debugPrint('$errorMessage: $e');
      debugPrint('Stack trace: $stackTrace');
      return Stream.value(defaultValue);
    }
  }
}