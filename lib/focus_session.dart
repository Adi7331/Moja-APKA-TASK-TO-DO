class FocusPlan {
  const FocusPlan({
    required this.workDuration,
    required this.breakDuration,
    required this.label,
  });

  const FocusPlan.pomodoro()
    : workDuration = const Duration(minutes: 25),
      breakDuration = const Duration(minutes: 5),
      label = 'Pomodoro 25 / 5';

  final Duration workDuration;
  final Duration breakDuration;
  final String label;
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedWorkSeconds,
    required this.completed,
  });

  factory FocusSession.fromStorage(Map<String, dynamic> json) => FocusSession(
    id: json['id'] as String,
    taskId: json['taskId'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
    endedAt: DateTime.parse(json['endedAt'] as String).toUtc(),
    plannedWorkSeconds: json['plannedWorkSeconds'] as int,
    completed: json['completed'] as bool,
  );

  factory FocusSession.fromSupabaseRow(Map<String, dynamic> row) =>
      FocusSession(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        startedAt: DateTime.parse(row['started_at'] as String).toUtc(),
        endedAt: DateTime.parse(row['ended_at'] as String).toUtc(),
        plannedWorkSeconds: (row['planned_work_seconds'] as num).toInt(),
        completed: row['completed'] as bool,
      );

  final String id;
  final String taskId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedWorkSeconds;
  final bool completed;

  int get actualWorkSeconds => endedAt.difference(startedAt).inSeconds;

  Map<String, dynamic> toStorage() => {
    'id': id,
    'taskId': taskId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'plannedWorkSeconds': plannedWorkSeconds,
    'completed': completed,
  };

  Map<String, dynamic> toSupabasePayload(String userId) => {
    'id': id,
    'user_id': userId,
    'task_id': taskId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'planned_work_seconds': plannedWorkSeconds,
    'completed': completed,
  };

  @override
  bool operator ==(Object other) =>
      other is FocusSession &&
      other.id == id &&
      other.taskId == taskId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.plannedWorkSeconds == plannedWorkSeconds &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    startedAt,
    endedAt,
    plannedWorkSeconds,
    completed,
  );
}
