import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../utils/url_validator.dart';

@immutable
class UrlItem {
  final String id;
  final String url;
  final String title;
  final String? description;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;
  final UrlStatus status;
  final DateTime? lastChecked;

  UrlItem({
    String? id,
    required this.url,
    required this.title,
    this.description,
    required this.categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata,
    this.status = UrlStatus.unknown,
    this.lastChecked,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UrlItem copyWith({
    String? url,
    String? title,
    String? description,
    String? categoryId,
    Map<String, dynamic>? metadata,
    UrlStatus? status,
    DateTime? lastChecked,
  }) {
    return UrlItem(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
      'status': status.index,
      'lastChecked': lastChecked?.toIso8601String(),
    };
  }

  factory UrlItem.fromJson(Map<String, dynamic> json) {
    return UrlItem(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryId: json['categoryId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] != null ? UrlStatus.values[json['status'] as int] : UrlStatus.unknown,
      lastChecked: json['lastChecked'] != null ? DateTime.parse(json['lastChecked'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UrlItem && other.id == id && other.url == url && other.title == title && other.description == description && other.categoryId == categoryId && other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^ url.hashCode ^ title.hashCode ^ description.hashCode ^ categoryId.hashCode ^ status.hashCode;
  }

  @override
  String toString() {
    return 'UrlItem(id: $id, url: $url, title: $title, categoryId: $categoryId, status: ${status.name})';
  }
}
