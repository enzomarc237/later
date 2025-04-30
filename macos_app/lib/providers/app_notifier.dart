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
        setEquals(other.selectedUrlIds, selectedUrlIds);
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
        selectedUrlIds.hashCode;
  }

  // Get the currently visible URLs (filtered by category)
  List<UrlItem> get visibleUrls {
    return selectedCategoryUrls;
  }

  // Get the number of selected URLs
  int get selectedUrlCount {
    return selectedUrlIds.length;
  }

  // Check if a URL is selected
  bool isUrlSelected(String urlId) {
    return selectedUrlIds.contains(urlId);
  }

  // Check if all visible URLs are selected
  bool get areAllVisibleUrlsSelected {
    if (visibleUrls.isEmpty) return false;
    return visibleUrls.every((url) => selectedUrlIds.contains(url.id));
  }

  @override
  String toString() {
    return 'AppState(message: $message, categories: ${categories.length}, urls: ${urls.length}, selectedCategoryId: $selectedCategoryId)';
  }

  // Get URLs for the selected category or all URLs if no category is selected
  List<UrlItem> get selectedCategoryUrls {
    if (selectedCategoryId == null)
      return urls; // Return all URLs when no category is selected
    return urls.where((url) => url.categoryId == selectedCategoryId).toList();
  }
}

class AppNotifier extends Notifier<AppState> {
  late PreferencesRepository _preferencesRepository;
  late BackupService _backupService;
  late UrlValidator _urlValidator;
  late MetadataService _metadataService;

  // Settings for automatic backups
  bool _autoBackupEnabled = true;

  @override
  AppState build() {
    _preferencesRepository = ref.read(preferencesRepositoryProvider);
    _backupService = ref.read(backupServiceProvider);
    _urlValidator = UrlValidator();
    _metadataService = ref.read(metadataServiceProvider);

    // Initialize auto backup setting from settings
    final settings = ref.read(settingsNotifier);
    _autoBackupEnabled = settings.autoBackupEnabled;

    // Load initial state
    final initialState = AppState(
      message: 'initialized',
      appVersion: _preferencesRepository.appVersion,
      currentDirectory: _preferencesRepository.currentDirectory,
    );

    state = initialState;

    // Load categories and URLs from preferences
    _loadData();

    return initialState;
  }

  // Backup management
  Future<String?> createBackup({String? backupName}) async {
    final settings = await _preferencesRepository.getSettings();
    return _backupService.createBackup(
      categories: state.categories,
      urls: state.urls,
      settings: settings,
      backupName: backupName,
    );
  }

  Future<List<BackupInfo>> listBackups() async {
    return _backupService.listBackups();
  }

  Future<bool> restoreBackup(String backupFileName) async {
    final result = await _backupService.restoreBackup(backupFileName);
    if (result) {
      // Reload data from storage after restore
      await _loadData();
      return true;
    }
    return false;
  }

  Future<bool> deleteBackup(String backupFileName) async {
    return _backupService.deleteBackup(backupFileName);
  }

  // Toggle automatic backups
  void setAutoBackup(bool enabled) {
    _autoBackupEnabled = enabled;
  }

  void setCurrentDirectory({required String directoryPath}) {
    state = state.copyWith(currentDirectory: directoryPath);
    debugPrint('setDefaultDirectory: $directoryPath');
    _preferencesRepository.setCurrentDirectory(directoryPath);
  }

  // Category management
  void addCategory(Category category) {
    final updatedCategories = [...state.categories, category];
    state = state.copyWith(categories: updatedCategories);
    _saveCategories();
  }

  void updateCategory(Category category) {
    final index = state.categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      final updatedCategories = [...state.categories];
      updatedCategories[index] = category;
      state = state.copyWith(categories: updatedCategories);
      _saveCategories();
    }
  }

  void deleteCategory(String categoryId) {
    final updatedCategories =
        state.categories.where((c) => c.id != categoryId).toList();

    // Also delete all URLs in this category
    final updatedUrls =
        state.urls.where((url) => url.categoryId != categoryId).toList();

    // Clear selected category if it's the one being deleted
    final clearSelected = state.selectedCategoryId == categoryId;

    state = state.copyWith(
      categories: updatedCategories,
      urls: updatedUrls,
      clearSelectedCategory: clearSelected,
    );

    _saveCategories();
    _saveUrls();
  }

  void selectCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  // Explicitly clear the selected category
  void clearSelectedCategory() {
    debugPrint('Explicitly clearing selected category');
    state = state.copyWith(
      selectedCategoryId: null,
      clearSelectedCategory: true,
    );
    debugPrint('Selected category after clearing: ${state.selectedCategoryId}');
  }

  // URL management

  /// Fetches metadata for a URL
  Future<WebsiteMetadata?> _fetchMetadata(String url) async {
    try {
      return await _metadataService.fetchMetadata(url);
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
      return null;
    }
  }

  /// Enriches a URL with metadata
  UrlItem enrichUrlWithMetadata(UrlItem url, WebsiteMetadata metadata) {
    // Only update title and description if they're empty
    final title = url.title.isEmpty ? metadata.title : url.title;
    final description = url.description?.isEmpty ?? true
        ? metadata.description
        : url.description;

    // Create or update metadata map
    final existingMetadata = url.metadata ?? {};
    final updatedMetadata = {
      ...existingMetadata,
      'faviconUrl': metadata.faviconUrl,
      'title': metadata.title,
      'description': metadata.description,
      'lastFetched': DateTime.now().toIso8601String(),
    };

    return url.copyWith(
      title: title,
      description: description,
      metadata: updatedMetadata,
    );
  }

  /// Adds a URL to the app, optionally fetching metadata
  Future<void> addUrl(UrlItem url, {bool fetchMetadata = true}) async {
    // Add the URL immediately for better UX
    var updatedUrl = url;
    final updatedUrls = [...state.urls, updatedUrl];
    state = state.copyWith(urls: updatedUrls);

    // Fetch metadata if requested
    if (fetchMetadata) {
      final metadata = await _fetchMetadata(url.url);
      if (metadata != null) {
        // Update the URL with metadata
        updatedUrl = enrichUrlWithMetadata(url, metadata);

        // Update the state with the enriched URL
        final index = updatedUrls.indexOf(url);
        if (index >= 0) {
          updatedUrls[index] = updatedUrl;
          state = state.copyWith(urls: updatedUrls);
        }
      }
    }

    _saveUrls();
  }

  /// Updates a URL, optionally fetching new metadata
  Future<void> updateUrl(UrlItem url, {bool fetchMetadata = false}) async {
    final index = state.urls.indexWhere((u) => u.id == url.id);
    if (index < 0) return;

    // Update the URL immediately for better UX
    var updatedUrl = url;
    final updatedUrls = [...state.urls];
    updatedUrls[index] = updatedUrl;
    state = state.copyWith(urls: updatedUrls);

    // Fetch metadata if requested
    if (fetchMetadata) {
      final metadata = await _fetchMetadata(url.url);
      if (metadata != null) {
        // Update the URL with metadata
        updatedUrl = enrichUrlWithMetadata(url, metadata);
        updatedUrls[index] = updatedUrl;
        state = state.copyWith(urls: updatedUrls);
      }
    }

    _saveUrls();
  }

  void deleteUrl(String urlId) {
    final updatedUrls = state.urls.where((u) => u.id != urlId).toList();
    state = state.copyWith(urls: updatedUrls);
    _saveUrls();
  }

  // Bulk operations

  // Toggle selection mode
  void toggleSelectionMode() {
    final newSelectionMode = !state.selectionMode;
    state = state.copyWith(
      selectionMode: newSelectionMode,
      // Clear selections when exiting selection mode
      clearSelectedUrls: !newSelectionMode,
    );
  }

  // Toggle selection for a URL
  void toggleUrlSelection(String urlId) {
    if (!state.selectionMode) {
      // Enable selection mode when selecting the first URL
      state = state.copyWith(selectionMode: true);
    }

    final selectedUrlIds = Set<String>.from(state.selectedUrlIds);
    if (selectedUrlIds.contains(urlId)) {
      selectedUrlIds.remove(urlId);
    } else {
      selectedUrlIds.add(urlId);
    }

    state = state.copyWith(selectedUrlIds: selectedUrlIds);
  }

  // Select all visible URLs
  void selectAllVisibleUrls() {
    final visibleUrls = state.visibleUrls;
    if (visibleUrls.isEmpty) return;

    final selectedUrlIds = Set<String>.from(state.selectedUrlIds);
    for (final url in visibleUrls) {
      selectedUrlIds.add(url.id);
    }

    state = state.copyWith(
      selectionMode: true,
      selectedUrlIds: selectedUrlIds,
    );
  }

  // Deselect all URLs
  void deselectAllUrls() {
    state = state.copyWith(clearSelectedUrls: true);
  }

  // Delete selected URLs
  void deleteSelectedUrls() {
    if (state.selectedUrlIds.isEmpty) return;

    final updatedUrls = state.urls
        .where((url) => !state.selectedUrlIds.contains(url.id))
        .toList();

    state = state.copyWith(
      urls: updatedUrls,
      clearSelectedUrls: true,
      selectionMode: false,
    );

    _saveUrls();
  }

  // Move selected URLs to a category
  void moveSelectedUrlsToCategory(String categoryId) {
    if (state.selectedUrlIds.isEmpty) return;

    final updatedUrls = [...state.urls];

    for (int i = 0; i < updatedUrls.length; i++) {
      if (state.selectedUrlIds.contains(updatedUrls[i].id)) {
        updatedUrls[i] = updatedUrls[i].copyWith(categoryId: categoryId);
      }
    }

    state = state.copyWith(
      urls: updatedUrls,
      clearSelectedUrls: true,
      selectionMode: false,
    );

    _saveUrls();
  }

  // URL validation methods

  /// Validates a single URL and updates its status
  Future<UrlStatus> validateUrl(String urlId) async {
    final index = state.urls.indexWhere((u) => u.id == urlId);
    if (index < 0) return UrlStatus.error;

    final url = state.urls[index];
    final status = await _urlValidator.validateUrl(url.url);

    // Update the URL with the new status
    final updatedUrl = url.copyWith(
      status: status,
      lastChecked: DateTime.now(),
    );

    final updatedUrls = [...state.urls];
    updatedUrls[index] = updatedUrl;

    state = state.copyWith(urls: updatedUrls);
    _saveUrls();

    return status;
  }

  /// Validates all URLs in the app with progress updates
  Future<Map<String, UrlStatus>> validateAllUrls() async {
    if (state.urls.isEmpty) return {};

    final urlStrings = state.urls.map((u) => u.url).toList();
    final results = <String, UrlStatus>{};
    final updatedUrls = [...state.urls];
    final now = DateTime.now();

    try {
      await _urlValidator.validateUrls(
        urlStrings,
        onProgress: (completed, total, currentUrl) {
          state = state.copyWith(
            validationProgress: ValidationProgress(
              completed: completed,
              total: total,
              currentUrl: currentUrl,
            ),
          );
        },
        onMetadataUpdated: (url, metadata) {
          final index = updatedUrls.indexWhere((u) => u.url == url);
          if (index >= 0) {
            final existingMetadata = updatedUrls[index].metadata ?? {};
            updatedUrls[index] = updatedUrls[index].copyWith(
              metadata: {...existingMetadata, ...metadata},
            );
          }
        },
      ).then((validationResults) {
        results.addAll(validationResults);

        // Update URL statuses
        for (var i = 0; i < updatedUrls.length; i++) {
          final status = validationResults[updatedUrls[i].url];
          if (status != null) {
            updatedUrls[i] = updatedUrls[i].copyWith(
              status: status,
              lastChecked: now,
            );
          }
        }
      });

      state = state.copyWith(
        urls: updatedUrls,
        clearValidationProgress: true,
      );

      _saveUrls();
    } catch (e) {
      debugPrint('Error validating URLs: $e');
      state = state.copyWith(clearValidationProgress: true);
    }

    return results;
  }

  /// Validates all URLs in a specific category
  Future<Map<String, UrlStatus>> validateCategoryUrls(String categoryId) async {
    final categoryUrls =
        state.urls.where((u) => u.categoryId == categoryId).toList();
    if (categoryUrls.isEmpty) return {};

    state = state.copyWith(isLoading: true);

    final results = <String, UrlStatus>{};
    final updatedUrls = [...state.urls];
    final now = DateTime.now();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (url.categoryId != categoryId) continue;

      final status = await _urlValidator.validateUrl(url.url);

      updatedUrls[i] = url.copyWith(
        status: status,
        lastChecked: now,
      );

      results[url.id] = status;
    }

    state = state.copyWith(
      urls: updatedUrls,
      isLoading: false,
    );

    _saveUrls();

    return results;
  }

  /// Validates all currently visible URLs (based on selected category)
  Future<Map<String, UrlStatus>> validateVisibleUrls() async {
    final visibleUrls = state.visibleUrls;
    if (visibleUrls.isEmpty) return {};

    state = state.copyWith(isLoading: true);

    final results = <String, UrlStatus>{};
    final updatedUrls = [...state.urls];
    final now = DateTime.now();
    final visibleIds = visibleUrls.map((u) => u.id).toSet();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (!visibleIds.contains(url.id)) continue;

      final status = await _urlValidator.validateUrl(url.url);

      updatedUrls[i] = url.copyWith(
        status: status,
        lastChecked: now,
      );

      results[url.id] = status;
    }

    state = state.copyWith(
      urls: updatedUrls,
      isLoading: false,
    );

    _saveUrls();

    return results;
  }

  /// Validates selected URLs
  Future<Map<String, UrlStatus>> validateSelectedUrls() async {
    if (state.selectedUrlIds.isEmpty) return {};

    state = state.copyWith(isLoading: true);

    final results = <String, UrlStatus>{};
    final updatedUrls = [...state.urls];
    final now = DateTime.now();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (!state.selectedUrlIds.contains(url.id)) continue;

      final status = await _urlValidator.validateUrl(url.url);

      updatedUrls[i] = url.copyWith(
        status: status,
        lastChecked: now,
      );

      results[url.id] = status;
    }

    state = state.copyWith(
      urls: updatedUrls,
      isLoading: false,
    );

    _saveUrls();

    return results;
  }

  /// Returns a list of invalid URLs (dead links)
  List<UrlItem> getInvalidUrls() {
    return state.urls.where((url) => url.status.isInvalid).toList();
  }

  /// Returns a list of valid URLs
  List<UrlItem> getValidUrls() {
    return state.urls.where((url) => url.status.isValid).toList();
  }

  /// Returns a list of URLs that haven't been validated yet
  List<UrlItem> getUnvalidatedUrls() {
    return state.urls.where((url) => url.status.isUnknown).toList();
  }

  // Data management
  Future<void> clearData() async {
    state = state.copyWith(
      categories: [],
      urls: [],
      clearSelectedCategory: true,
      message: 'data_cleared',
    );

    // Persist the empty lists to storage
    await _saveCategories();
    await _saveUrls();
  }

  // Import/Export
  ExportData exportData() {
    return ExportData(
      categories: state.categories,
      urls: state.urls,
      version: state.appVersion,
    );
  }

  void importData(ExportData data) {
    // Preserve existing categories if the imported data has an empty categories array
    final categories =
        data.categories.isEmpty ? state.categories : data.categories;

    state = state.copyWith(
      categories: categories,
      urls: data.urls,
      isLoading: false,
    );

    _saveCategories();
    _saveUrls();
  }

  /// Open all selected URLs in browser with rate limiting to prevent browser crashes
  Future<void> openSelectedUrls() async {
    if (state.selectedUrlIds.isEmpty) return;

    // Get selected URLs
    final selectedUrls = state.urls
        .where((url) => state.selectedUrlIds.contains(url.id))
        .toList();
    int successCount = 0;
    int failureCount = 0;

    // Set delay between opening URLs based on count to prevent browser crashes
    // More URLs = longer delay between each
    final int delayMs = selectedUrls.length > 20
        ? 500
        : selectedUrls.length > 10
            ? 300
            : selectedUrls.length > 5
                ? 200
                : 100;

    for (final url in selectedUrls) {
      try {
        final uri = Uri.parse(url.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          successCount++;

          // Add delay between opening URLs to prevent browser from being overwhelmed
          if (selectedUrls.indexOf(url) < selectedUrls.length - 1) {
            await Future.delayed(Duration(milliseconds: delayMs));
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
        fileStorage: ref.read(fileStorageServiceProvider),
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
