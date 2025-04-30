import 'package:drift/drift.dart';

/// Table definition for tags in the Later app.
/// 
/// Tags provide an additional way to organize URLs beyond categories.
/// A URL can belong to multiple tags, enabling more flexible organization.
@DataClassName('Tag')
class Tags extends Table {
  /// Auto-incrementing primary key for the database.
  IntColumn get id => integer().autoIncrement()();
  
  /// Unique identifier (UUID) for the tag.
  /// This is used for references and synchronization.
  TextColumn get uuid => text().unique()();
  
  /// The name of the tag.
  TextColumn get name => text()();
  
  /// The timestamp when the tag was created.
  DateTimeColumn get createdAt => dateTime()();
  
  /// The timestamp when the tag was last updated.
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(uuid)',
  ];
}