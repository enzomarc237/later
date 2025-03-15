import 'category.dart';
import 'url_item.dart';

class ExportData {
  final List<Category> categories;
  final List<UrlItem> urls;
  final String version;
  final DateTime exportedAt;

  ExportData({
    required this.categories,
    required this.urls,
    required this.version,
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'categories': categories.map((category) => category.toJson()).toList(),
      'urls': urls.map((url) => url.toJson()).toList(),
    };
  }

  factory ExportData.fromJson(Map<String, dynamic> json) {
    return ExportData(
      version: json['version'] as String,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      categories: (json['categories'] as List)
          .map((categoryJson) => Category.fromJson(categoryJson as Map<String, dynamic>))
          .toList(),
      urls: (json['urls'] as List)
          .map((urlJson) => UrlItem.fromJson(urlJson as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'ExportData(categories: ${categories.length}, urls: ${urls.length}, version: $version, exportedAt: $exportedAt)';
  }
}