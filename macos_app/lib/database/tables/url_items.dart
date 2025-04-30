import 'package:drift/drift.dart';
import 'categories.dart';

/// Table definition for URL items in the Later app.
@DataClassName('UrlItem')
class UrlItems extends Table {
  /// Auto-incrementing primary key for the database.
  IntColumn get id => integer().autoIncrement()();
  
  /// Unique identifier (UUID) for the URL item.
  /// This is used for references and synchronization.
  TextColumn get uuid => text().unique()();
  
  /// The actual URL.
  TextColumn get url => text()();
  
  /// The title of the URL.
  TextColumn get title => text()();
  
  /// The description of the URL (optional).
  TextColumn get description => text().nullable()();
  
  /// The UUID of the category this URL belongs to.
  /// This is a foreign key reference to the categories table.
  TextColumn get categoryId => text().references(Categories, #uuid)();
  
  /// The timestamp when the URL item was created.
  DateTimeColumn get createdAt => dateTime()();
  
  /// The timestamp when the URL item was last updated.
  DateTimeColumn get updatedAt => dateTime()();
  
  /// Additional metadata for the URL, stored as JSON.
  /// This can include favicon URL, preview image, etc.
  TextColumn get metadata => text().nullable()();
  
  /// The status of the URL (valid, invalid, unknown, etc.).
  /// This corresponds to the UrlStatus enum in the model.
  IntColumn get status => integer().withDefault(const Constant(0))();
  
  /// The timestamp when the URL was last checked for validity.
  DateTimeColumn get lastChecked => dateTime().nullable()();
  
  /// Flag indicating whether the URL item has been deleted.
  /// This is used for soft deletes to maintain sync history.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(uuid)',
  ];
}