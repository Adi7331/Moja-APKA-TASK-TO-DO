class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.emoji,
  });

  factory TaskCategory.fromStorage(Map<String, dynamic> stored) => TaskCategory(
        id: stored['id'] as String,
        userId: stored['userId'] as String,
        name: stored['name'] as String,
        color: stored['color'] as String,
        emoji: stored['emoji'] as String?,
        createdAt: DateTime.parse(stored['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(stored['updatedAt'] as String).toUtc(),
      );

  factory TaskCategory.fromRow(Map<String, dynamic> row) => TaskCategory(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        color: row['color'] as String,
        emoji: row['emoji'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );

  final String id;
  final String userId;
  final String name;
  final String color;
  final String? emoji;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskCategory copyWith({
    String? name,
    String? color,
    Object? emoji = _unset,
    DateTime? updatedAt,
  }) =>
      TaskCategory(
        id: id,
        userId: userId,
        name: name ?? this.name,
        color: color ?? this.color,
        emoji: identical(emoji, _unset) ? this.emoji : emoji as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toStorage() => {
        'id': id,
        'userId': userId,
        'name': name,
        'color': color,
        'emoji': emoji,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toSupabasePayload() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': color,
        'emoji': emoji,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is TaskCategory &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.color == color &&
      other.emoji == emoji &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, userId, name, color, emoji, createdAt, updatedAt);
}

const _unset = Object();
