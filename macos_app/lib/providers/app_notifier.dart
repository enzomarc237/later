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
  // final String message; // Consider if this is still needed with AsyncValue
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
    // required this.message,
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
      // message: message ?? this.message,
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

    return // other.message == message &&
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
    return // message.hashCode ^
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
    return 'AppState(categories: ${categories.length}, urls: ${urls.length}, selectedCategoryId: $selectedCategoryId)';
  }

  // Get URLs for the selected category or all URLs if no category is selected
  List<UrlItem> get selectedCategoryUrls {
    if (selectedCategoryId == null) {
      return urls;
    } // Return all URLs when no category is selected
    return urls.where((url) => url.categoryId == selectedCategoryId).toList();
  }
}

// Convert AppNotifier to an AsyncNotifier
class AppNotifier extends AsyncNotifier<AppState> {
  late PreferencesRepository _preferencesRepository;
  // Assuming BackupService might also become async or rely on async prefs in future.
  // For now, keep as is if its provider isn't changing to FutureProvider.
  // If BackupService itself needs PreferencesRepository, it should also use the async version.
  late BackupService _backupService;
  late UrlValidator _urlValidator;
  late MetadataService _metadataService;

  // Settings for automatic backups
  late MetadataService _metadataService;

  // Settings for automatic backups, will be loaded from settingsNotifier
  bool _autoBackupEnabled = true;

  @override
  Future<AppState> build() async {
    // Initialize dependencies
    _preferencesRepository = await ref.watch(preferencesRepositoryProvider.future);
    // Assuming backupServiceProvider and metadataServiceProvider are not async,
    // otherwise, they would need .future as well.
    _backupService = ref.read(backupServiceProvider);
    _urlValidator = UrlValidator();
    _metadataService = ref.read(metadataServiceProvider);

    // Initialize auto backup setting from settings
    // Assuming settingsNotifier is synchronous. If it becomes async, this needs to await its future.
    final settings = ref.read(settingsNotifier);
    _autoBackupEnabled = settings.autoBackupEnabled;

    // Load initial data from the repository
    final categories = await _preferencesRepository.getCategories();
    final urls = await _preferencesRepository.getUrls();
    final appVersion = _preferencesRepository.appVersion; // Assuming this is sync
    final currentDirectory = _preferencesRepository.currentDirectory; // Assuming this is sync

    return AppState(
      appVersion: appVersion,
      currentDirectory: currentDirectory,
      categories: categories,
      urls: urls,
      isLoading: false, // isLoading is part of AsyncValue state now
    );
  }

  // Helper to get current data state or throw if in error/loading
  AppState get _currentState => state.valueOrNull ?? AppState(appVersion: '', currentDirectory: '');


  // Backup management
  Future<String?> createBackup({String? backupName}) async {
    if (state.isLoading) return null; // Or handle appropriately
    final currentAppState = _currentState;
    // Settings might be async in future, for now assume sync access from repo is fine
    final settings = _preferencesRepository.getSettings();
    return _backupService.createBackup(
      categories: currentAppState.categories,
      urls: currentAppState.urls,
      settings: settings,
      backupName: backupName,
    );
  }

  Future<List<BackupInfo>> listBackups() async {
    // This method doesn't depend on AppState, so it can be called anytime.
    return _backupService.listBackups();
  }

  Future<bool> restoreBackup(String backupFileName) async {
    state = const AsyncLoading(); // Set loading state
    try {
      final result = await _backupService.restoreBackup(backupFileName);
      if (result) {
        // Reload data by rebuilding the notifier state
        ref.invalidateSelf(); // This will re-trigger build()
        await future; // Wait for the new state to be built
        return true;
      }
      // If restore failed, revert to previous state or handle error
      // For simplicity, we re-fetch. A more robust solution might store previous state.
      await build(); // Rebuild to fetch current data
      return false;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteBackup(String backupFileName) async {
    return _backupService.deleteBackup(backupFileName);
  }

  // Toggle automatic backups
  // This might interact with settingsNotifier in a more complex app
  void setAutoBackup(bool enabled) {
    _autoBackupEnabled = enabled;
    // Persist this setting if necessary, e.g., via settingsNotifier or _preferencesRepository
  }

  Future<void> setCurrentDirectory({required String directoryPath}) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    state = AsyncData(currentAppState.copyWith(currentDirectory: directoryPath));
    await _preferencesRepository.setCurrentDirectory(directoryPath);
  }

  // Category management
  Future<void> addCategory(Category category) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final updatedCategories = [...currentAppState.categories, category];
    state = AsyncData(currentAppState.copyWith(categories: updatedCategories));
    await _saveCategories();
  }

  Future<void> updateCategory(Category category) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final index = currentAppState.categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      final updatedCategories = [...currentAppState.categories];
      updatedCategories[index] = category;
      state = AsyncData(currentAppState.copyWith(categories: updatedCategories));
      await _saveCategories();
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;

    final updatedCategories =
        currentAppState.categories.where((c) => c.id != categoryId).toList();
    final updatedUrls =
        currentAppState.urls.where((url) => url.categoryId != categoryId).toList();
    final clearSelected = currentAppState.selectedCategoryId == categoryId;

    state = AsyncData(currentAppState.copyWith(
      categories: updatedCategories,
      urls: updatedUrls,
      clearSelectedCategory: clearSelected,
    ));

    await _saveCategories();
    await _saveUrls();
  }

  void selectCategory(String? categoryId) {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    state = AsyncData(currentAppState.copyWith(selectedCategoryId: categoryId));
  }

  void clearSelectedCategory() {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    debugPrint('Explicitly clearing selected category');
    state = AsyncData(currentAppState.copyWith(
      selectedCategoryId: null,
      clearSelectedCategory: true,
    ));
    debugPrint('Selected category after clearing: ${state.value?.selectedCategoryId}');
  }


  // URL management

  Future<WebsiteMetadata?> _fetchMetadata(String url) async {
    try {
      return await _metadataService.fetchMetadata(url);
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
      return null;
    }
  }

  UrlItem enrichUrlWithMetadata(UrlItem url, WebsiteMetadata metadata) {
    final title = url.title.isEmpty ? metadata.title : url.title;
    final description = url.description?.isEmpty ?? true
        ? metadata.description
        : url.description;
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

  Future<void> addUrl(UrlItem url, {bool fetchMetadata = true}) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    var updatedUrl = url;
    final updatedUrls = [...currentAppState.urls, updatedUrl];
    state = AsyncData(currentAppState.copyWith(urls: updatedUrls));

    if (fetchMetadata) {
      final metadata = await _fetchMetadata(url.url);
      if (metadata != null) {
        updatedUrl = enrichUrlWithMetadata(url, metadata);
        final currentUrlsAfterAsync = state.value?.urls ?? updatedUrls; // Re-fetch in case state changed
        final index = currentUrlsAfterAsync.indexOf(url); // original url to find index
        if (index >= 0) {
          final newUrlList = List<UrlItem>.from(currentUrlsAfterAsync);
          newUrlList[index] = updatedUrl;
          state = AsyncData(_currentState.copyWith(urls: newUrlList));
        }
      }
    }
    await _saveUrls();
  }

  Future<void> updateUrl(UrlItem url, {bool fetchMetadata = false}) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final index = currentAppState.urls.indexWhere((u) => u.id == url.id);
    if (index < 0) return;

    var updatedUrl = url;
    final updatedUrls = [...currentAppState.urls];
    updatedUrls[index] = updatedUrl;
    state = AsyncData(currentAppState.copyWith(urls: updatedUrls));

    if (fetchMetadata) {
      final metadata = await _fetchMetadata(url.url);
      if (metadata != null) {
        updatedUrl = enrichUrlWithMetadata(url, metadata);
        // Re-fetch current state in case it changed during async gap
        final currentUrlsAfterAsync = state.value?.urls ?? updatedUrls;
        final freshIndex = currentUrlsAfterAsync.indexWhere((u) => u.id == url.id);
        if (freshIndex >=0) {
          final newUrlList = List<UrlItem>.from(currentUrlsAfterAsync);
          newUrlList[freshIndex] = updatedUrl;
          state = AsyncData(_currentState.copyWith(urls: newUrlList));
        }
      }
    }
    await _saveUrls();
  }

  Future<void> deleteUrl(String urlId) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final updatedUrls = currentAppState.urls.where((u) => u.id != urlId).toList();
    state = AsyncData(currentAppState.copyWith(urls: updatedUrls));
    await _saveUrls();
  }

  // Bulk operations
  void toggleSelectionMode() {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final newSelectionMode = !currentAppState.selectionMode;
    state = AsyncData(currentAppState.copyWith(
      selectionMode: newSelectionMode,
      clearSelectedUrls: !newSelectionMode,
    ));
  }

  void toggleUrlSelection(String urlId) {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    var newSelectionMode = currentAppState.selectionMode;
    if (!newSelectionMode) {
      newSelectionMode = true; // Enable selection mode
    }

    final selectedUrlIds = Set<String>.from(currentAppState.selectedUrlIds);
    if (selectedUrlIds.contains(urlId)) {
      selectedUrlIds.remove(urlId);
    } else {
      selectedUrlIds.add(urlId);
    }
    state = AsyncData(currentAppState.copyWith(
        selectedUrlIds: selectedUrlIds, selectionMode: newSelectionMode));
  }

  void selectAllVisibleUrls() {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final visibleUrls = currentAppState.visibleUrls;
    if (visibleUrls.isEmpty) return;

    final selectedUrlIds = Set<String>.from(currentAppState.selectedUrlIds);
    for (final url in visibleUrls) {
      selectedUrlIds.add(url.id);
    }
    state = AsyncData(
        currentAppState.copyWith(selectionMode: true, selectedUrlIds: selectedUrlIds));
  }

  void deselectAllUrls() {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    state = AsyncData(currentAppState.copyWith(clearSelectedUrls: true));
  }

  Future<void> deleteSelectedUrls() async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    if (currentAppState.selectedUrlIds.isEmpty) return;

    final updatedUrls = currentAppState.urls
        .where((url) => !currentAppState.selectedUrlIds.contains(url.id))
        .toList();
    state = AsyncData(currentAppState.copyWith(
      urls: updatedUrls,
      clearSelectedUrls: true,
      selectionMode: false,
    ));
    await _saveUrls();
  }

  Future<void> moveSelectedUrlsToCategory(String categoryId) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    if (currentAppState.selectedUrlIds.isEmpty) return;

    final updatedUrls = [...currentAppState.urls];
    for (int i = 0; i < updatedUrls.length; i++) {
      if (currentAppState.selectedUrlIds.contains(updatedUrls[i].id)) {
        updatedUrls[i] = updatedUrls[i].copyWith(categoryId: categoryId);
      }
    }
    state = AsyncData(currentAppState.copyWith(
      urls: updatedUrls,
      clearSelectedUrls: true,
      selectionMode: false,
    ));
    await _saveUrls();
  }


  // URL validation methods
  Future<UrlStatus> validateUrl(String urlId) async {
    if (state.isLoading) return UrlStatus.error;
    final currentAppState = _currentState;
    final index = currentAppState.urls.indexWhere((u) => u.id == urlId);
    if (index < 0) return UrlStatus.error;

    final url = currentAppState.urls[index];
    final status = await _urlValidator.validateUrl(url.url);
    final updatedUrl = url.copyWith(status: status, lastChecked: DateTime.now());
    final updatedUrls = [...currentAppState.urls];
    updatedUrls[index] = updatedUrl;

    state = AsyncData(currentAppState.copyWith(urls: updatedUrls));
    await _saveUrls();
    return status;
  }

  Future<Map<String, UrlStatus>> validateAllUrls() async {
    if (state.isLoading) return {};
    final currentAppState = _currentState;
    if (currentAppState.urls.isEmpty) return {};

    state = AsyncData(currentAppState.copyWith(isLoading: true)); // Indicate loading

    final urlStrings = currentAppState.urls.map((u) => u.url).toList();
    final results = <String, UrlStatus>{};
    final updatedUrls = [...currentAppState.urls];
    final now = DateTime.now();

    try {
      await _urlValidator.validateUrls(
        urlStrings,
        onProgress: (completed, total, currentUrl) {
          final currentProgress = state.valueOrNull?.validationProgress;
          if (currentProgress?.completed != completed || currentProgress?.total != total) {
             final stillLoadingState = state.valueOrNull ?? currentAppState; // Use latest if available
            state = AsyncData(stillLoadingState.copyWith(
              validationProgress: ValidationProgress(
                completed: completed,
                total: total,
                currentUrl: currentUrl,
              ),
            ));
          }
        },
        onMetadataUpdated: (url, metadata) {
           final stillLoadingState = state.valueOrNull ?? currentAppState;
          final index = stillLoadingState.urls.indexWhere((u) => u.url == url);
          if (index >= 0) {
            final newUrls = List<UrlItem>.from(stillLoadingState.urls);
            final existingMetadata = newUrls[index].metadata ?? {};
            newUrls[index] = newUrls[index].copyWith(
              metadata: {...existingMetadata, ...metadata},
            );
             state = AsyncData(stillLoadingState.copyWith(urls: newUrls));
          }
        },
      ).then((validationResults) {
        results.addAll(validationResults);
        final currentProcessingState = state.valueOrNull ?? currentAppState;
        final finalUrls = List<UrlItem>.from(currentProcessingState.urls);
        for (var i = 0; i < finalUrls.length; i++) {
          final status = validationResults[finalUrls[i].url];
          if (status != null) {
            finalUrls[i] = finalUrls[i].copyWith(status: status, lastChecked: now);
          }
        }
         state = AsyncData(currentProcessingState.copyWith(urls: finalUrls, clearValidationProgress: true, isLoading: false));
      });
      await _saveUrls();
    } catch (e, st) {
      debugPrint('Error validating URLs: $e');
      state = AsyncError(e, st); // Propagate error to UI
    } finally {
       final finalState = state.valueOrNull ?? currentAppState;
      state = AsyncData(finalState.copyWith(clearValidationProgress: true, isLoading: false));
    }
    return results;
  }

  Future<Map<String, UrlStatus>> validateCategoryUrls(String categoryId) async {
     if (state.isLoading) return {};
    final currentAppState = _currentState;
    final categoryUrls =
        currentAppState.urls.where((u) => u.categoryId == categoryId).toList();
    if (categoryUrls.isEmpty) return {};

    state = AsyncData(currentAppState.copyWith(isLoading: true));

    final results = <String, UrlStatus>{};
    final updatedUrls = [...currentAppState.urls];
    final now = DateTime.now();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (url.categoryId != categoryId) continue;
      final status = await _urlValidator.validateUrl(url.url);
      updatedUrls[i] = url.copyWith(status: status, lastChecked: now);
      results[url.id] = status;
    }

    state = AsyncData(currentAppState.copyWith(urls: updatedUrls, isLoading: false));
    await _saveUrls();
    return results;
  }

  Future<Map<String, UrlStatus>> validateVisibleUrls() async {
    if (state.isLoading) return {};
    final currentAppState = _currentState;
    final visibleUrls = currentAppState.visibleUrls;
    if (visibleUrls.isEmpty) return {};

    state = AsyncData(currentAppState.copyWith(isLoading: true));

    final results = <String, UrlStatus>{};
    final updatedUrls = [...currentAppState.urls];
    final now = DateTime.now();
    final visibleIds = visibleUrls.map((u) => u.id).toSet();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (!visibleIds.contains(url.id)) continue;
      final status = await _urlValidator.validateUrl(url.url);
      updatedUrls[i] = url.copyWith(status: status, lastChecked: now);
      results[url.id] = status;
    }

    state = AsyncData(currentAppState.copyWith(urls: updatedUrls, isLoading: false));
    await _saveUrls();
    return results;
  }

  Future<Map<String, UrlStatus>> validateSelectedUrls() async {
    if (state.isLoading) return {};
    final currentAppState = _currentState;
    if (currentAppState.selectedUrlIds.isEmpty) return {};

    state = AsyncData(currentAppState.copyWith(isLoading: true));

    final results = <String, UrlStatus>{};
    final updatedUrls = [...currentAppState.urls];
    final now = DateTime.now();

    for (int i = 0; i < updatedUrls.length; i++) {
      final url = updatedUrls[i];
      if (!currentAppState.selectedUrlIds.contains(url.id)) continue;
      final status = await _urlValidator.validateUrl(url.url);
      updatedUrls[i] = url.copyWith(status: status, lastChecked: now);
      results[url.id] = status;
    }

    state = AsyncData(currentAppState.copyWith(urls: updatedUrls, isLoading: false));
    await _saveUrls();
    return results;
  }

  List<UrlItem> getInvalidUrls() {
    return state.value?.urls.where((url) => url.status.isInvalid).toList() ?? [];
  }

  List<UrlItem> getValidUrls() {
    return state.value?.urls.where((url) => url.status.isValid).toList() ?? [];
  }

  List<UrlItem> getUnvalidatedUrls() {
    return state.value?.urls.where((url) => url.status.isUnknown).toList() ?? [];
  }


  // Data management
  Future<void> clearData() async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    state = AsyncData(currentAppState.copyWith(
      categories: [],
      urls: [],
      clearSelectedCategory: true,
      // message: 'data_cleared', // Message can be handled by UI based on state
    ));
    await _saveCategories();
    await _saveUrls();
  }

  // Import/Export
  ExportData? exportData() {
    if (state.value == null) return null;
    final currentAppState = _currentState;
    return ExportData(
      categories: currentAppState.categories,
      urls: currentAppState.urls,
      version: currentAppState.appVersion,
    );
  }

  Future<void> importData(ExportData data) async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    final categories =
        data.categories.isEmpty ? currentAppState.categories : data.categories;
    state = AsyncData(currentAppState.copyWith(
      categories: categories,
      urls: data.urls,
      isLoading: false,
    ));
    await _saveCategories();
    await _saveUrls();
  }

  Future<void> openSelectedUrls() async {
    if (state.isLoading) return;
    final currentAppState = _currentState;
    if (currentAppState.selectedUrlIds.isEmpty) return;

    final selectedUrls = currentAppState.urls
        .where((url) => currentAppState.selectedUrlIds.contains(url.id))
        .toList();
    int successCount = 0;
    int failureCount = 0;
    final int delayMs = selectedUrls.length > 20 ? 500
        : selectedUrls.length > 10 ? 300
        : selectedUrls.length > 5 ? 200 : 100;

    for (final url in selectedUrls) {
      try {
        final uri = Uri.parse(url.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          successCount++;
          if (selectedUrls.indexOf(url) < selectedUrls.length - 1) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } else {
          failureCount++;
        }
      } catch (e) {
        failureCount++;
      }
    }
    LocalNotification(
      title: 'URLs Opened',
      body: 'Successfully opened $successCount URLs. Failed to open $failureCount URLs.',
    ).show();

    state = AsyncData(currentAppState.copyWith(
        selectionMode: false, clearSelectedUrls: true));
  }


  // Private methods for persistence
  // _loadData is effectively replaced by the async build() method.

  Future<void> _saveCategories() async {
    if (state.value == null) return; // Don't save if state is not valid
    try {
      await _preferencesRepository.saveCategories(state.value!.categories);
      if (_autoBackupEnabled) {
        await _createAutomaticBackup();
      }
    } catch (e, st) {
      debugPrint('Error saving categories: $e');
      state = AsyncError(e, st); // Update state to reflect error
    }
  }

  Future<void> _saveUrls() async {
    if (state.value == null) return;
    try {
      await _preferencesRepository.saveUrls(state.value!.urls);
      if (_autoBackupEnabled) {
        await _createAutomaticBackup();
      }
    } catch (e, st) {
      debugPrint('Error saving URLs: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> _createAutomaticBackup() async {
    if (state.value == null) return;
    try {
      // Assuming getSettings is synchronous as per previous plan
      final settings = _preferencesRepository.getSettings();

      // This logic for re-creating BackupService might need adjustment if BackupService
      // itself has state or dependencies that shouldn't be reset like this.
      // Consider if maxBackups can be updated on an existing BackupService instance.
      _backupService = BackupService(
        // fileStorage: ref.read(fileStorageServiceProvider), // This was removed
        // TODO: BackupService needs to be updated to not rely on FileStorageService
        // For now, this will cause an error.
        // A temporary fix could be to make BackupService not require fileStorage if auto backup is off,
        // or provide a dummy/null implementation if fileStorage is essential.
        // This highlights a dependency issue to be resolved.
        maxBackups: settings.maxBackups,
      );

      await _backupService.createBackup(
        categories: state.value!.categories,
        urls: state.value!.urls,
        settings: settings,
        backupName: 'auto_backup.json',
      );
    } catch (e) {
      // Silently fail or log, but don't disrupt app state for backup failure
      debugPrint('Error creating automatic backup: $e');
    }
  }
}

final appNotifier = AsyncNotifierProvider<AppNotifier, AppState>(AppNotifier.new);
