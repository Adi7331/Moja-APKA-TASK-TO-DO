import 'note_item.dart';

/// A lightweight, private notebook folder. Notes keep a nullable [folderId],
/// so a deleted folder naturally returns its notes to "Bez folderu".
class NoteFolder {
  NoteFolder({
    required this.id,
    required this.name,
    this.userId,
    this.colorKey = NoteColorKey.neutral,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory NoteFolder.fromStorage(Map<String, dynamic> json) => NoteFolder(
    id: json['id'] as String,
    userId: json['userId'] as String?,
    name: json['name'] as String? ?? 'Bez nazwy',
    colorKey: NoteColorKey.values.firstWhere(
      (value) => value.name == json['colorKey'],
      orElse: () => NoteColorKey.neutral,
    ),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  final String id;
  final String? userId;
  final String name;
  final NoteColorKey colorKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteFolder copyWith({String? name, NoteColorKey? colorKey, DateTime? updatedAt}) =>
      NoteFolder(
        id: id,
        userId: userId,
        name: name ?? this.name,
        colorKey: colorKey ?? this.colorKey,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toStorage() => {
    'id': id,
    'userId': userId,
    'name': name,
    'colorKey': colorKey.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toSupabasePayload(String ownerId) => {
    'id': id,
    'user_id': ownerId,
    'name': name.trim(),
    'color_key': colorKey.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
