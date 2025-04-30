import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../../models/category.dart' as model;
import 'base_repository.dart';

/// Repository for managing categories in the database.
/// 
/// This repository provides methods for creating, reading, updating, and deleting
/// categories, as well as converting between database and model entities.
class CategoryRepository extends BaseRepository {
  /// Creates a new repository with the given [database].
  CategoryRepository(super.database);

  /// Gets all categories that are not marked as deleted.
  Future<List<model.Category>> getAllCategories() async {
    return executeDbOperationWithDefault(
      () async {
        final categories = await database.getAllCategories();
        return categories.map(_mapDbCategoryToModel).toList();
      },
      'Failed to get all categories',
      <model.Category>[],
    );
  }

  /// Watches all categories that are not marked as deleted.
  Stream<List<model.Category>> watchAllCategories() {
    return executeDbStreamOperation(
      () {
        return database.watchAllCategories().map(
          (categories) => categories.map(_mapDbCategoryToModel).toList(),
        );
      },
      'Failed to watch all categories',
      <model.Category>[],
    );
  }

  /// Gets a category by its UUID.
  Future<model.Category?> getCategoryByUuid(String uuid) async {
    return executeDbOperation<model.Category?>(
      () async {
        final category = await database.getCategoryByUuid(uuid);
        return category != null ? _mapDbCategoryToModel(category) : null;
      },
      'Failed to get category by UUID: $uuid',
    );
  }

  /// Creates a new category.
  Future<model.Category?> createCategory(model.Category category) async {
    return executeDbOperation<model.Category?>(
      () async {
        final companion = _mapModelCategoryToCompanion(category);
        await database.insertCategory(companion);
        return category;
      },
      'Failed to create category: ${category.name}',
    );
  }

  /// Updates an existing category.
  Future<model.Category?> updateCategory(model.Category category) async {
    return executeDbOperation<model.Category?>(
      () async {
        final companion = _mapModelCategoryToCompanion(category);
        await database.updateCategory(companion);
        return category;
      },
      'Failed to update category: ${category.name}',
    );
  }

  /// Deletes a category by its UUID.
  Future<bool> deleteCategory(String uuid) async {
    return executeDbOperationWithDefault(
      () async {
        final result = await database.softDeleteCategory(uuid);
        return result > 0;
      },
      'Failed to delete category with UUID: $uuid',
      false,
    );
  }

  /// Converts a database category entity to a model category entity.
  model.Category _mapDbCategoryToModel(Category dbCategory) {
    return model.Category(
      id: dbCategory.uuid,
      name: dbCategory.name,
      iconName: dbCategory.iconName,
      createdAt: dbCategory.createdAt,
      updatedAt: dbCategory.updatedAt,
    );
  }

  /// Converts a model category entity to a database category companion.
  CategoriesCompanion _mapModelCategoryToCompanion(model.Category category) {
    return CategoriesCompanion(
      uuid: Value(category.id),
      name: Value(category.name),
      iconName: Value(category.iconName),
      createdAt: Value(category.createdAt),
      updatedAt: Value(category.updatedAt ?? DateTime.now()),
    );
  }

  /// Creates a new category with the given name and icon name.
  Future<model.Category?> createNewCategory(String name, {String? iconName}) async {
    final newCategory = model.Category(
      id: const Uuid().v4(),
      name: name,
      iconName: iconName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    return createCategory(newCategory);
  }
}