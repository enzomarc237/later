import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../database_provider.dart';
import '../../providers/providers.dart';
import 'migration_service.dart';
import 'database_migrator.dart';

/// Provider for the migration service.
/// 
/// This provider creates a MigrationService instance using the database,
/// file storage service, and shared preferences.
final migrationServiceProvider = Provider<MigrationService>((ref) {
  final database = ref.watch(databaseProvider);
  final fileStorage = ref.watch(fileStorageServiceProvider);
  final preferences = ref.watch(sharedPreferencesProvider);
  
  return MigrationService(database, fileStorage, preferences);
});

/// State class for the migration notifier.
class MigrationState {
  /// Whether migration is in progress.
  final bool isInProgress;
  
  /// Whether migration is needed.
  final bool isNeeded;
  
  /// Whether migration is completed.
  final bool isCompleted;
  
  /// The current migration progress.
  final MigrationResult? progress;
  
  /// Any error that occurred during migration.
  final String? error;
  
  /// Creates a new migration state.
  MigrationState({
    this.isInProgress = false,
    this.isNeeded = false,
    this.isCompleted = false,
    this.progress,
    this.error,
  });
  
  /// Creates a copy of this state with the given fields replaced.
  MigrationState copyWith({
    bool? isInProgress,
    bool? isNeeded,
    bool? isCompleted,
    MigrationResult? progress,
    String? error,
  }) {
    return MigrationState(
      isInProgress: isInProgress ?? this.isInProgress,
      isNeeded: isNeeded ?? this.isNeeded,
      isCompleted: isCompleted ?? this.isCompleted,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

/// Notifier for managing migration state.
/// 
/// This notifier provides methods for checking if migration is needed,
/// performing migration, and tracking migration progress.
class MigrationNotifier extends StateNotifier<MigrationState> {
  /// The migration service.
  final MigrationService _migrationService;
  
  /// Creates a new migration notifier.
  MigrationNotifier(this._migrationService) : super(MigrationState());
  
  /// Checks if migration is needed.
  Future<void> checkMigrationNeeded() async {
    try {
      final isNeeded = await _migrationService.isMigrationNeeded();
      final isCompleted = _migrationService.isMigrationCompleted();
      
      state = state.copyWith(
        isNeeded: isNeeded,
        isCompleted: isCompleted,
      );
    } catch (e) {
      debugPrint('Error checking if migration is needed: $e');
      state = state.copyWith(
        error: 'Failed to check if migration is needed: $e',
      );
    }
  }
  
  /// Performs the migration from file-based storage to the database.
  Future<void> performMigration() async {
    if (state.isInProgress) {
      return;
    }
    
    try {
      state = state.copyWith(
        isInProgress: true,
        error: null,
      );
      
      final result = await _migrationService.performMigration(
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      
      state = state.copyWith(
        isInProgress: false,
        isCompleted: result.isSuccessful,
        progress: result,
      );
    } catch (e) {
      debugPrint('Error performing migration: $e');
      state = state.copyWith(
        isInProgress: false,
        error: 'Failed to perform migration: $e',
      );
    }
  }
  
  /// Rolls back the migration by clearing the database.
  Future<void> rollbackMigration() async {
    try {
      final result = await _migrationService.rollbackMigration();
      
      state = state.copyWith(
        isCompleted: !result,
        error: result ? null : 'Failed to roll back migration',
      );
    } catch (e) {
      debugPrint('Error rolling back migration: $e');
      state = state.copyWith(
        error: 'Failed to roll back migration: $e',
      );
    }
  }
  
  /// Marks the migration as completed without actually performing it.
  Future<void> skipMigration() async {
    try {
      await _migrationService.markMigrationAsCompleted();
      
      state = state.copyWith(
        isCompleted: true,
        isNeeded: false,
      );
    } catch (e) {
      debugPrint('Error skipping migration: $e');
      state = state.copyWith(
        error: 'Failed to skip migration: $e',
      );
    }
  }
}

/// Provider for the migration notifier.
/// 
/// This provider creates a MigrationNotifier instance using the migration service.
final migrationNotifierProvider = StateNotifierProvider<MigrationNotifier, MigrationState>((ref) {
  final migrationService = ref.watch(migrationServiceProvider);
  return MigrationNotifier(migrationService);
});