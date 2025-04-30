import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../database.dart';
import '../../models/url_item.dart' as model;
import 'base_repository.dart';

/// Repository for managing URL items in the database.
/// 
/// This repository provides methods for creating, reading, updating, and deleting
/// URL items, as well as converting between database and model entities.
class UrlRepository extends BaseRepository {
  /// Creates a new repository with the given [database].
  UrlRepository(super.database);

  /// Gets all URLs that are not marked as deleted.
  Future<List<model.UrlItem>> getAllUrls() async {
    return executeDbOperationWithDefault(
      () async {
        final urls = await database.getAllUrls();
        return urls.map(_mapDbUrlToModel).toList();
      },
      'Failed to get all URLs',
      <model.UrlItem>[],
    );
  }

  /// Watches all URLs that are not marked as deleted.
  Stream<List<model.UrlItem>> watchAllUrls() {
    return executeDbStreamOperation(
      () {
        return database.watchAllUrls().map(
          (urls) => urls.map(_mapDbUrlToModel).toList(),
        );
      },
      'Failed to watch all URLs',
      <model.UrlItem>[],
    );
  }

  /// Gets URLs for a specific category.
  Future<List<model.UrlItem>> getUrlsForCategory(String categoryId) async {
    return executeDbOperationWithDefault(
      () async {
        final urls = await database.getUrlsForCategory(categoryId);
        return urls.map(_mapDbUrlToModel).toList();
      },
      'Failed to get URLs for category: $categoryId',
      <model.UrlItem>[],
    );
  }

  /// Watches URLs for a specific category.
  Stream<List<model.UrlItem>> watchUrlsForCategory(String categoryId) {
    return executeDbStreamOperation(
      () {
        return database.watchUrlsForCategory(categoryId).map(
          (urls) => urls.map(_mapDbUrlToModel).toList(),
        );
      },
      'Failed to watch URLs for category: $categoryId',
      <model.UrlItem>[],
    );
  }

  /// Gets a URL by its UUID.
  Future<model.UrlItem?> getUrlByUuid(String uuid) async {
    return executeDbOperation(
      () async {
        final url = await database.getUrlByUuid(uuid);
        return url != null ? _mapDbUrlToModel(url) : null;
      },
      'Failed to get URL by UUID: $uuid',
    );
  }

  /// Creates a new URL.
  Future<model.UrlItem?> createUrl(model.UrlItem url) async {
    return executeDbOperation(
      () async {
        final companion = _mapModelUrlToCompanion(url);
        await database.insertUrl(companion);
        return url;
      },
      'Failed to create URL: ${url.url}',
    );
  }

  /// Updates an existing URL.
  Future<model.UrlItem?> updateUrl(model.UrlItem url) async {
    return executeDbOperation(
      () async {
        final companion = _mapModelUrlToCompanion(url);
        await database.updateUrl(companion);
        return url;
      },
      'Failed to update URL: ${url.url}',
    );
  }

  /// Deletes a URL by its UUID.
  Future<bool> deleteUrl(String uuid) async {
    return executeDbOperationWithDefault(
      () async {
        final result = await database.softDeleteUrl(uuid);
        return result > 0;
      },
      'Failed to delete URL with UUID: $uuid',
      false,
    );
  }

  /// Deletes all URLs in a category.
  Future<bool> deleteUrlsInCategory(String categoryId) async {
    return executeDbOperationWithDefault(
      () async {
        final result = await database.softDeleteUrlsInCategory(categoryId);
        return result > 0;
      },
      'Failed to delete URLs in category: $categoryId',
      false,
    );
  }

  /// Updates the status of a URL.
  Future<bool> updateUrlStatus(String uuid, model.UrlStatus status) async {
    return executeDbOperationWithDefault(
      () async {
        final result = await database.updateUrlStatus(uuid, status);
        return result > 0;
      },
      'Failed to update URL status for UUID: $uuid',
      false,
    );
  }

  /// Searches for URLs by title, description, or URL.
  Future<List<model.UrlItem>> searchUrls(String query) async {
    return executeDbOperationWithDefault(
      () async {
        final urls = await database.searchUrls(query);
        return urls.map(_mapDbUrlToModel).toList();
      },
      'Failed to search URLs with query: $query',
      <model.UrlItem>[],
    );
  }

  /// Counts the number of URLs in a category.
  Future<int> countUrlsInCategory(String categoryId) async {
    return executeDbOperationWithDefault(
      () async {
        return await database.countUrlsInCategory(categoryId);
      },
      'Failed to count URLs in category: $categoryId',
      0,
    );
  }

  /// Creates a new URL with the given details.
  Future<model.UrlItem?> createNewUrl({
    required String url,
    required String title,
    String? description,
    required String categoryId,
    Map<String, dynamic>? metadata,
    model.UrlStatus status = model.UrlStatus.unknown,
  }) async {
    final newUrl = model.UrlItem(
      id: const Uuid().v4(),
      url: url,
      title: title,
      description: description,
      categoryId: categoryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: metadata,
      status: status,
      lastChecked: status != model.UrlStatus.unknown ? DateTime.now() : null,
    );
    
    return createUrl(newUrl);
  }

  /// Converts a database URL entity to a model URL entity.
  model.UrlItem _mapDbUrlToModel(UrlItem dbUrl) {
    Map<String, dynamic>? metadata;
    if (dbUrl.metadata != null) {
      try {
        metadata = jsonDecode(dbUrl.metadata!) as Map<String, dynamic>;
      } catch (e) {
        // If JSON parsing fails, use null
        metadata = null;
      }
    }
    
    return model.UrlItem(
      id: dbUrl.uuid,
      url: dbUrl.url,
      title: dbUrl.title,
      description: dbUrl.description,
      categoryId: dbUrl.categoryId,
      createdAt: dbUrl.createdAt,
      updatedAt: dbUrl.updatedAt,
      metadata: metadata,
      status: dbUrl.status,
      lastChecked: dbUrl.lastChecked,
    );
  }

  /// Converts a model URL entity to a database URL companion.
  UrlItemsCompanion _mapModelUrlToCompanion(model.UrlItem url) {
    String? metadataJson;
    if (url.metadata != null) {
      try {
        metadataJson = jsonEncode(url.metadata);
      } catch (e) {
        // If JSON encoding fails, use null
        metadataJson = null;
      }
    }
    
    return UrlItemsCompanion(
      uuid: Value(url.id),
      url: Value(url.url),
      title: Value(url.title),
      description: Value(url.description),
      categoryId: Value(url.categoryId),
      createdAt: Value(url.createdAt),
      updatedAt: Value(url.updatedAt ?? DateTime.now()),
      metadata: Value(metadataJson),
      status: Value(url.status),
      lastChecked: Value(url.lastChecked),
    );
  }
}