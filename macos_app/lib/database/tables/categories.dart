import 'package:drift/drift.dart';

/// Table definition for categories in the Later app.
@DataClassName('Category')
class Categories extends Table {
  /// Auto-incrementing primary key for the database.
  IntColumn get id => integer().autoIncrement()();
  
  /// Unique identifier (UUID) for the category.
  /// This is used for references and synchronization.
  TextColumn get uuid => text().unique()();
  
  /// The name of the category.
  TextColumn get name => text()();
  
  /// The icon name for the category (optional).
  /// This is stored as a string (e.g., 'folder', 'bookmark', etc.)
  TextColumn get iconName => text().nullable()();
  
  /// The timestamp when the category was created.
  DateTimeColumn get createdAt => dateTime()();
  
  /// The timestamp when the category was last updated.
  DateTimeColumn get updatedAt => dateTime()();
  
  /// Flag indicating whether the category has been deleted.
  /// This is used for soft deletes to maintain sync history.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(uuid)',
  ];
}