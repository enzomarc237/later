// ignore_for_file: public_member_api_docs, sort_constructors_first, avoid_print
import 'package:flutter/foundation.dart' hide Category;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/backup_service.dart';
import '../utils/metadata_service.dart';
import '../utils/url_validator.dart';
import 'providers.dart';

class ValidationProgress {
  final int completed;
  final int total;
  final String currentUrl;

  ValidationProgress({
    required this.completed,
    required this.total,
    required this.currentUrl,
  });

  double get percentage => total > 0 ? (completed / total) * 100 : 0;
  bool get isComplete => completed >= total;
}

class AppState {
  final String message;
  final String appVersion;
  final String currentDirectory;
  final List<Category> categories;
  final String? selectedCategoryId;
  final List<UrlItem> urls;
  final bool isLoading;

  // Selection state for bulk operations
  final bool selectionMode;
  final Set<String> selectedUrlIds;

  // Validation progress
  final ValidationProgress? validationProgress;

  AppState({
    required this.message,
    required this.appVersion,
    required this.currentDirectory,
    this.categories = const [],
    this.selectedCategoryId,
    this.urls = const [],
    this.isLoading = false,
    this.selectionMode = false,
    this.selectedUrlIds = const {},
    this.validationProgress,
  });

  AppState copyWith({
    String? message,
    String? appVersion,
    String? currentDirectory,
    List<Category>? categories,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
    List<UrlItem>? urls,
    bool? isLoading,
    bool? selectionMode,
    Set<String>? selectedUrlIds,
    bool clearSelectedUrls = false,
    ValidationProgress? validationProgress,
    bool clearValidationProgress = false,
  }) {
    return AppState(
      message: message ?? this.message,
      appVersion: appVersion ?? this.appVersion,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      categories: categories ?? this.categories,
      selectedCategoryId: clearSelectedCategory
          ? null
          : selectedCategoryId ?? this.selectedCategoryId,
      urls: urls ?? this.urls,
      isLoading: isLoading ?? this.isLoading,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedUrlIds:
          clearSelectedUrls ? {} : selectedUrlIds ?? this.selectedUrlIds,
      validationProgress: clearValidationProgress
          ? null
          : validationProgress ?? this.validationProgress,
    );
  }

  @override
  String toString() {
    return 'AppState(message: $message, appVersion: $appVersion, currentDirectory: $currentDirectory, categories: $categories, selectedCategoryId: $selectedCategoryId, urls: $urls, isLoading: $isLoading, selectionMode: $selectionMode, selectedUrlIds: $selectedUrlIds, validationProgress: $validationProgress)';
  }

  @override
  bool operator ==(covariant AppState other) {
    if (identical(this, other)) return true;

    return other.message == message &&
        other.appVersion == appVersion &&
        other.currentDirectory == currentDirectory &&
        listEquals(other.categories, categories) &&
        other.selectedCategoryId == selectedCategoryId &&
        listEquals(other.urls, urls) &&
        other.isLoading == isLoading &&
        other.selectionMode == selectionMode &&
        setEquals(other.selectedUrlIds, selectedUrlIds) &&
        other.validationProgress == validationProgress;
  }

  @override
  int get hashCode {
    return message.hashCode ^
        appVersion.hashCode ^
        currentDirectory.hashCode ^
        categories.hashCode ^
        selectedCategoryId.hashCode ^
        urls.hashCode ^
        isLoading.hashCode ^
        selectionMode.hashCode ^
        selectedUrlIds.hashCode ^
        validationProgress.hashCode;
  }
}

class AppNotifier extends Notifier<AppState> {
  late final PreferencesRepository _preferencesRepository;
  late final BackupService _backupService;
  late final MetadataService _metadataService;
  late final UrlValidator _urlValidator;

  bool _autoBackupEnabled = false;

  @override
  AppState build() {
    _preferencesRepository = ref.read(preferencesRepositoryProvider);
    _backupService = ref.read(backupServiceProvider);
    _metadataService = ref.read(metadataServiceProvider);
    _urlValidator = UrlValidator();

    _loadData();

    // Listen for changes in settings to update auto backup status
    ref.listen(settingsNotifier, (previous, next) {
      _autoBackupEnabled = next.autoBackup;
    });

    return AppState(
      message: 'Welcome to Later!',
      appVersion: _preferencesRepository.appVersion,
      currentDirectory: _preferencesRepository.currentDirectory,
    );
  }

  // Categories
  Future<void> addCategory(Category category) async {
    state = state.copyWith(isLoading: true);
    final updatedCategories = List<Category>.from(state.categories)
      ..add(category);
    state = state.copyWith(categories: updatedCategories, isLoading: false);
    await _saveCategories();
  }

  Future<void> updateCategory(Category updatedCategory) async {
    state = state.copyWith(isLoading: true);
    final updatedCategories = state.categories.map((category) {
      return category.id == updatedCategory.id ? updatedCategory : category;
    }).toList();
    state = state.copyWith(categories: updatedCategories, isLoading: false);
    await _saveCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    state = state.copyWith(isLoading: true);
    final updatedCategories = List<Category>.from(state.categories)
      ..removeWhere((category) => category.id == categoryId);
    final updatedUrls = List<UrlItem>.from(state.urls)
      ..map((url) => url.categoryId == categoryId
          ? url.copyWith(categoryId: null)
          : url)
          .toList();
    state = state.copyWith(
      categories: updatedCategories,
      urls: updatedUrls,
      isLoading: false,
    );
    await _preferencesRepository.deleteCategory(categoryId);
    await _saveCategories(); // Re-save categories after deletion to ensure consistency
    await _saveUrls(); // Re-save URLs after category deletion to update categoryId to null
  }

  void selectCategory(String? categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearSelectedUrls: true,
      selectionMode: false,
    );
  }

  // URLs
  Future<void> addUrl(UrlItem url, {bool fetchMetadata = false}) async {
    state = state.copyWith(isLoading: true);
    final updatedUrls = List<UrlItem>.from(state.urls)..add(url);
    state = state.copyWith(urls: updatedUrls, isLoading: false);
    await _saveUrls();

    if (fetchMetadata) {
      await _fetchMetadataForUrl(url);
    }
  }

  Future<void> updateUrl(UrlItem updatedUrl) async {
    state = state.copyWith(isLoading: true);
    final updatedUrls = state.urls.map((url) {
      return url.id == updatedUrl.id ? updatedUrl : url;
    }).toList();
    state = state.copyWith(urls: updatedUrls, isLoading: false);
    await _saveUrls();
  }

  Future<void> deleteUrl(String urlId) async {
    state = state.copyWith(isLoading: true);
    final updatedUrls = List<UrlItem>.from(state.urls)
      ..removeWhere((url) => url.id == urlId);
    state = state.copyWith(urls: updatedUrls, isLoading: false);
    await _preferencesRepository.deleteUrl(urlId);
    await _saveUrls(); // Re-save URLs after deletion to ensure consistency
  }

  void toggleSelectionMode() {
    state = state.copyWith(
      selectionMode: !state.selectionMode,
      clearSelectedUrls: true,
    );
  }

  void selectUrl(String urlId, bool isSelected) {
    final updatedSelectedUrlIds = Set<String>.from(state.selectedUrlIds);
    if (isSelected) {
      updatedSelectedUrlIds.add(urlId);
    } else {
      updatedSelectedUrlIds.remove(urlId);
    }
    state = state.copyWith(selectedUrlIds: updatedSelectedUrlIds);
  }

  void selectAllVisibleUrls() {
    final visibleUrls = state.urls.where((url) {
      return state.selectedCategoryId == null ||
          url.categoryId == state.selectedCategoryId;
    }).toList();

    final allSelected = state.selectedUrlIds.containsAll(
      visibleUrls.map((e) => e.id),
    );

    if (allSelected) {
      state = state.copyWith(clearSelectedUrls: true);
    } else {
      state = state.copyWith(
        selectedUrlIds: visibleUrls.map((e) => e.id).toSet(),
      );
    }
  }

  Future<void> deleteSelectedUrls() async {
    state = state.copyWith(isLoading: true);
    final urlsToDelete = state.urls.where((url) => state.selectedUrlIds.contains(url.id)).toList();
    final updatedUrls = List<UrlItem>.from(state.urls)
      ..removeWhere((url) => state.selectedUrlIds.contains(url.id));
    state = state.copyWith(
      urls: updatedUrls,
      isLoading: false,
      selectionMode: false,
      clearSelectedUrls: true,
    );
    for (final urlItem in urlsToDelete) {
      await _preferencesRepository.deleteUrl(urlItem.id);
    }
    await _saveUrls(); // Re-save URLs after deletion to ensure consistency
  }

  Future<void> openSelectedUrls() async {
    if (state.selectedUrlIds.isEmpty) return;

    int successCount = 0;
    int failureCount = 0;

    for (final urlId in state.selectedUrlIds) {
      final url = state.urls.firstWhere((element) => element.id == urlId);
      try {
        if (await canLaunchUrl(Uri.parse(url.url))) {
          await launchUrl(Uri.parse(url.url));
          successCount++;
          // Add a small delay to prevent overwhelming the system
          if (state.selectedUrlIds.length > 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } else {
          failureCount++;
          debugPrint('Could not launch URL: ${url.url}');
        }
      } catch (e) {
        failureCount++;
        debugPrint('Error opening URL ${url.url}: $e');
      }
    }

    // Show notification with results
    LocalNotification(
      title: 'URLs Opened',
      body:
          'Successfully opened $successCount URLs. Failed to open $failureCount URLs.',
    ).show();

    // Exit selection mode after opening URLs
    state = state.copyWith(
      selectionMode: false,
      clearSelectedUrls: true,
    );
  }

  // Data management
  Future<void> clearData() async {
    state = state.copyWith(isLoading: true);
    await _preferencesRepository.clearAllData();
    state = state.copyWith(
      categories: [],
      urls: [],
      isLoading: false,
      selectedCategoryId: null,
      clearSelectedUrls: true,
      selectionMode: false,
    );
  }

  ExportData exportData() {
    return ExportData(
      urls: state.urls,
      categories: state.categories,
      version: state.appVersion,
      exportedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> importData(ExportData importData) async {
    state = state.copyWith(isLoading: true);

    // Clear existing data before importing
    await clearData();

    // Add imported categories, avoiding duplicates by name
    final newCategories = <Category>[];
    for (var importedCategory in importData.categories) {
      if (!state.categories.any((c) => c.name == importedCategory.name)) {
        newCategories.add(importedCategory);
      }
    }
    state = state.copyWith(categories: [...state.categories, ...newCategories]);
    await _preferencesRepository.saveCategories(newCategories); // Save newly imported categories

    // Add imported URLs, ensuring category IDs are valid
    final newUrls = <UrlItem>[];
    for (var importedUrl in importData.urls) {
      // If the imported URL has a categoryId, ensure it exists in our current categories
      if (importedUrl.categoryId != null &&
          !state.categories.any((c) => c.id == importedUrl.categoryId)) {
        // If category doesn't exist, set categoryId to null
        newUrls.add(importedUrl.copyWith(categoryId: null));
      } else {
        newUrls.add(importedUrl);
      }
    }
    state = state.copyWith(urls: [...state.urls, ...newUrls]);
    await _preferencesRepository.saveUrls(newUrls); // Save newly imported URLs

    state = state.copyWith(isLoading: false);

    LocalNotification(
      title: 'Import Complete',
      body:
          'Successfully imported ${importData.urls.length} URLs and ${importData.categories.length} categories.',
    ).show();
  }

  // URL Validation
  Future<UrlValidationStatus> validateUrl(String urlId) async {
    final urlItem = state.urls.firstWhere((element) => element.id == urlId);
    final status = await _urlValidator.validateUrl(urlItem.url);
    final updatedUrl = urlItem.copyWith(validationStatus: status);
    await updateUrl(updatedUrl);
    return status;
  }

  Future<void> validateAllUrls() async {
    if (state.urls.isEmpty) return;

    state = state.copyWith(
      validationProgress: ValidationProgress(
        completed: 0,
        total: state.urls.length,
        currentUrl: '',
      ),
    );

    int completedCount = 0;
    for (final urlItem in state.urls) {
      state = state.copyWith(
        validationProgress: ValidationProgress(
          completed: completedCount,
          total: state.urls.length,
          currentUrl: urlItem.title,
        ),
      );
      final status = await _urlValidator.validateUrl(urlItem.url);
      final updatedUrl = urlItem.copyWith(validationStatus: status);
      await updateUrl(updatedUrl);
      completedCount++;
    }

    state = state.copyWith(
      validationProgress: ValidationProgress(
        completed: completedCount,
        total: state.urls.length,
        currentUrl: 'Validation Complete',
      ),
    );

    // Clear validation progress after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(clearValidationProgress: true);
    });
  }

  Future<void> validateVisibleUrls() async {
    final visibleUrls = state.urls.where((url) {
      return state.selectedCategoryId == null ||
          url.categoryId == state.selectedCategoryId;
    }).toList();

    if (visibleUrls.isEmpty) return;

    state = state.copyWith(
      validationProgress: ValidationProgress(
        completed: 0,
        total: visibleUrls.length,
        currentUrl: '',
      ),
    );

    int completedCount = 0;
    for (final urlItem in visibleUrls) {
      state = state.copyWith(
        validationProgress: ValidationProgress(
          completed: completedCount,
          total: visibleUrls.length,
          currentUrl: urlItem.title,
        ),
      );
      final status = await _urlValidator.validateUrl(urlItem.url);
      final updatedUrl = urlItem.copyWith(validationStatus: status);
      await updateUrl(updatedUrl);
      completedCount++;
    }

    state = state.copyWith(
      validationProgress: ValidationProgress(
        completed: completedCount,
        total: visibleUrls.length,
        currentUrl: 'Validation Complete',
      ),
    );

    // Clear validation progress after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(clearValidationProgress: true);
    });
  }

  // Settings
  void setAutoBackup(bool enabled) {
    _autoBackupEnabled = enabled;
  }

  // Private methods for persistence
  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);

    try {
      final categories = await _preferencesRepository.getCategories();
      final urls = await _preferencesRepository.getUrls();

      state = state.copyWith(
        categories: categories,
        urls: urls,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveCategories() async {
    try {
      await _preferencesRepository.saveCategories(state.categories);

      // Create automatic backup if enabled
      if (_autoBackupEnabled) {
        _createAutomaticBackup();
      }
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  Future<void> _saveUrls() async {
    try {
      await _preferencesRepository.saveUrls(state.urls);

      // Create automatic backup if enabled
      if (_autoBackupEnabled) {
        _createAutomaticBackup();
      }
    } catch (e) {
      debugPrint('Error saving URLs: $e');
    }
  }

  // Create an automatic backup with a standard naming convention
  Future<void> _createAutomaticBackup() async {
    try {
      final settings = await _preferencesRepository.getSettings();

      // Update the BackupService's maxBackups setting
      _backupService = BackupService(
        fileStorage: null, // FileStorageService is removed
        maxBackups: settings.maxBackups,
      );

      await _backupService.createBackup(
        categories: state.categories,
        urls: state.urls,
        settings: settings,
        backupName: 'auto_backup.json',
      );
    } catch (e) {
      debugPrint('Error creating automatic backup: $e');
    }
  }
}

final appNotifier = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
