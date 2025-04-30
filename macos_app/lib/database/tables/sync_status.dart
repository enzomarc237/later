import 'package:drift/drift.dart';

/// Table definition for tracking synchronization status of entities.
/// 
/// This table is used for cloud synchronization to track which entities
/// have been synced and which ones need to be synced.
@DataClassName('SyncStatusEntry')
class SyncStatus extends Table {
  /// The type of entity being tracked ('category', 'url', 'tag').
  TextColumn get entityType => text()();
  
  /// The UUID of the entity being tracked.
  TextColumn get entityId => text()();
  
  /// The timestamp when the entity was last synchronized.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  
  /// The status of the synchronization (pending, synced, conflict).
  /// 0 = pending, 1 = synced, 2 = conflict
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  
  /// The timestamp when the remote entity was last updated.
  /// This is used for conflict detection and resolution.
  DateTimeColumn get remoteUpdatedAt => dateTime().nullable()();
  
  /// Define the primary key as a composite of entityType and entityId.
  @override
  Set<Column> get primaryKey => {entityType, entityId};
}