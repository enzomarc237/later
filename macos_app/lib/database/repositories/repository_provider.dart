import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../database_provider.dart';
import 'category_repository.dart';
import 'url_repository.dart';

/// Provider for the category repository.
/// 
/// This provider creates a CategoryRepository instance using the database from the databaseProvider.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepository(database);
});

/// Provider for the URL repository.
/// 
/// This provider creates a UrlRepository instance using the database from the databaseProvider.
final urlRepositoryProvider = Provider<UrlRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return UrlRepository(database);
});