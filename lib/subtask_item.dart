class SubtaskItem {
  const SubtaskItem({
    required this.id,
    required this.title,
    required this.isDone,
    required this.position,
  });

  factory SubtaskItem.fromStorage(Map<String, dynamic> stored) => SubtaskItem(
        id: stored['id'] as String,
        title: stored['title'] as String,
        isDone: stored['isDone'] as bool? ?? false,
        position: stored['position'] as int? ?? 0,
      );

  factory SubtaskItem.fromRow(Map<String, dynamic> row) => SubtaskItem(
        id: row['id'] as String,
        title: row['title'] as String,
        isDone: row['is_done'] as bool? ?? false,
        position: row['position'] as int? ?? 0,
      );

  final String id;
  final String title;
  final bool isDone;
  final int position;

  Map<String, dynamic> toStorage() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'position': position,
      };
}
