import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

@immutable
class Category {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? iconName; // Store icon as a string (e.g., 'folder', 'bookmark', etc.)

  Category({
    String? id,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.iconName,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Get the IconData for this category
  IconData get icon {
    // Default to folder icon if none is set
    if (iconName == null || iconName!.isEmpty) {
      return CupertinoIcons.folder;
    }

    // Map string names to IconData
    switch (iconName) {
      case 'folder':
        return CupertinoIcons.folder;
      case 'bookmark':
        return CupertinoIcons.bookmark;
      case 'link':
        return CupertinoIcons.link;
      case 'doc':
        return CupertinoIcons.doc;
      case 'book':
        return CupertinoIcons.book;
      case 'tag':
        return CupertinoIcons.tag;
      case 'star':
        return CupertinoIcons.star;
      case 'heart':
        return CupertinoIcons.heart;
      case 'globe':
        return CupertinoIcons.globe;
      case 'person':
        return CupertinoIcons.person;
      case 'cart':
        return CupertinoIcons.cart;
      case 'gift':
        return CupertinoIcons.gift;
      case 'calendar':
        return CupertinoIcons.calendar;
      case 'clock':
        return CupertinoIcons.clock;
      case 'music_note':
        return CupertinoIcons.music_note;
      case 'photo':
        return CupertinoIcons.photo;
      case 'video':
        return CupertinoIcons.video_camera;
      case 'game':
        return CupertinoIcons.game_controller;
      case 'mail':
        return CupertinoIcons.mail;
      case 'chat':
        return CupertinoIcons.chat_bubble;
      default:
        return CupertinoIcons.folder;
    }
  }

  Category copyWith({
    String? name,
    String? iconName,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Category && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name)';
}
