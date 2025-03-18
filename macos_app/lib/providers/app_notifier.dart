// ignore_for_file: public_member_api_docs, sort_constructors_first, avoid_print
import 'package:flutter/foundation.dart' hide Category;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../utils/backup_service.dart';
import 'providers.dart';

class AppState {
  final String message;
  final String appVersion;
  final String currentDirectory;
  final List<Category> categories;
  final String? selectedCategoryId;
  final List<UrlItem> urls;
  final bool isLoading;

  AppState({
    required this.message,
    required this.appVersion,
    required this.currentDirectory,
    this.categories = const [],
    this.selectedCategoryId,
    this.urls = const [],
    this.isLoading = false,
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
  }) {
    return AppState(
      message: message ?? this.message,
      appVersion: appVersion ?? this.appVersion,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      categories: categories ?? this.categories,
      selectedCategoryId: clearSelectedCategory ? null : selectedCategoryId ?? this.selectedCategoryId,
      urls: urls ?? this.urls,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(covariant AppState other) {
    if (identical(this, other)) return true;

    return other.message == message && other.appVersion == appVersion && other.currentDirectory == currentDirectory && listEquals(other.categories, categories) && other.selectedCategoryId == selectedCategoryId && listEquals(other.urls, urls) && other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return message.hashCode ^ appVersion.hashCode ^ currentDirectory.hashCode ^ categories.hashCode ^ selectedCategoryId.hashCode ^ urls.hashCode ^ isLoading.hashCode;
  }

  @override
  String toString() {
    return 'AppState(message: $message, categories: ${categories.length}, urls: ${urls.length}, selectedCategoryId: $selectedCategoryId)';
  }

  // Get URLs for the selected category or all URLs if no category is selected
  List<UrlItem> get selectedCategoryUrls {
    if (selectedCategoryId == null) return urls; // Return all URLs when no category is selected
    return urls.where((url) => url.categoryId == selectedCategoryId).toList();
  }
}

class AppNotifier extends Notifier<AppState> {
  late PreferencesRepository _preferencesRepository;

  @override
  AppState build() {
    _preferencesRepository = ref.read(preferencesRepositoryProvider);

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
    final updatedCategories = state.categories.where((c) => c.id != categoryId).toList();

    // Also delete all URLs in this category
    final updatedUrls = state.urls.where((url) => url.categoryId != categoryId).toList();

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
  void addUrl(UrlItem url) {
    final updatedUrls = [...state.urls, url];
    state = state.copyWith(urls: updatedUrls);
    _saveUrls();
  }

  void updateUrl(UrlItem url) {
    final index = state.urls.indexWhere((u) => u.id == url.id);
    if (index >= 0) {
      final updatedUrls = [...state.urls];
      updatedUrls[index] = url;
      state = state.copyWith(urls: updatedUrls);
      _saveUrls();
    }
  }

  void deleteUrl(String urlId) {
    final updatedUrls = state.urls.where((u) => u.id != urlId).toList();
    state = state.copyWith(urls: updatedUrls);
    _saveUrls();
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
    final categories = data.categories.isEmpty ? state.categories : data.categories;

    state = state.copyWith(
      categories: categories,
      urls: data.urls,
      isLoading: false,
    );

    _saveCategories();
    _saveUrls();
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
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }

  Future<void> _saveUrls() async {
    try {
      await _preferencesRepository.saveUrls(state.urls);
    } catch (e) {
      debugPrint('Error saving URLs: $e');
    }
  }
}

final appNotifier = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
