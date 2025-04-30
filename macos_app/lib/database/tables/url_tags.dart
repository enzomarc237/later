import 'package:drift/drift.dart';

/// Table definition for the many-to-many relationship between URLs and tags.
/// 
/// This table enables a URL to have multiple tags and a tag to be associated with multiple URLs.
@DataClassName('UrlTag')
class UrlTags extends Table {
  /// The UUID of the URL.
  /// This is a foreign key reference to the url_items table.
  TextColumn get urlId => text()();
  
  /// The UUID of the tag.
  /// This is a foreign key reference to the tags table.
  TextColumn get tagId => text()();
  
  /// The timestamp when the relationship was created.
  DateTimeColumn get createdAt => dateTime()();
  
  /// Define the primary key as a composite of urlId and tagId.
  /// This ensures that a URL cannot be associated with the same tag multiple times.
  @override
  Set<Column> get primaryKey => {urlId, tagId};
}