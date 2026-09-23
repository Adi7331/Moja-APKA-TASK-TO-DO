import 'subtask_item.dart';
import 'repeat_rule.dart';

const _unset = Object();

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    this.note = '',
    this.category = 'Skrzynka',
    this.categoryId,
    this.priority = 'medium',
    this.dueAt,
    this.reminderAt,
    this.repeatRule,
    this.pinnedToday = false,
    this.completedAt,
    this.subtasks = const [],
    this.sourceNoteId,
  });

  factory TaskItem.fromRow(Map<String, dynamic> row) => TaskItem(
        id: row['id'] as String,
        title: row['title'] as String,
        status: row['status'] as String? ?? 'todo',
        note: row['note'] as String? ?? '',
        category: row['category'] as String? ?? 'Skrzynka',
        categoryId: row['category_id'] as String?,
        priority: row['priority'] as String? ?? 'medium',
        dueAt: row['due_at'] == null
            ? null
            : DateTime.tryParse(row['due_at'] as String)?.toLocal(),
        reminderAt: row['reminder_at'] == null
            ? null
            : DateTime.tryParse(row['reminder_at'] as String)?.toLocal(),
        repeatRule: _readRepeatRule(row['repeat_rule']),
        pinnedToday: row['pinned_today'] as bool? ?? false,
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.tryParse(row['completed_at'] as String)?.toLocal(),
        subtasks: (row['subtasks'] as List<dynamic>? ?? const [])
            .map((item) => SubtaskItem.fromRow(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        sourceNoteId: row['source_note_id'] as String?,
      );

  factory TaskItem.fromStorage(Map<String, dynamic> stored) => TaskItem(
        id: stored['id'] as String,
        title: stored['title'] as String,
        status: stored['status'] as String? ?? 'todo',
        note: stored['note'] as String? ?? '',
        category: stored['category'] as String? ?? 'Skrzynka',
        categoryId: stored['categoryId'] as String?,
        priority: stored['priority'] as String? ?? 'medium',
        dueAt: stored['dueAt'] == null
            ? null
            : DateTime.tryParse(stored['dueAt'] as String),
        reminderAt: stored['reminderAt'] == null
            ? null
            : DateTime.tryParse(stored['reminderAt'] as String),
        repeatRule: _readRepeatRule(stored['repeatRule']),
        pinnedToday: stored['pinnedToday'] as bool? ?? false,
        completedAt: stored['completedAt'] == null
            ? null
            : DateTime.tryParse(stored['completedAt'] as String),
        subtasks: (stored['subtasks'] as List<dynamic>? ?? const [])
            .map((item) => SubtaskItem.fromStorage(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        sourceNoteId: stored['sourceNoteId'] as String?,
      );

  final String id;
  final String title;
  final String status;
  final String note;
  final String category;
  final String? categoryId;
  final String priority;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final RepeatRule? repeatRule;
  final bool pinnedToday;
  final DateTime? completedAt;
  final List<SubtaskItem> subtasks;
  final String? sourceNoteId;

  bool get isDone => status == 'done';
  int get subtaskCount => subtasks.length;
  int get completedSubtaskCount => subtasks.where((step) => step.isDone).length;

  TaskItem copyWith({
    String? id,
    String? title,
    String? status,
    String? note,
    String? category,
    Object? categoryId = _unset,
    String? priority,
    Object? dueAt = _unset,
    Object? reminderAt = _unset,
    Object? repeatRule = _unset,
    bool? pinnedToday,
    Object? completedAt = _unset,
    List<SubtaskItem>? subtasks,
    Object? sourceNoteId = _unset,
  }) => TaskItem(
        id: id ?? this.id,
        title: title ?? this.title,
        status: status ?? this.status,
        note: note ?? this.note,
        category: category ?? this.category,
        categoryId: identical(categoryId, _unset)
            ? this.categoryId
            : categoryId as String?,
        priority: priority ?? this.priority,
        dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
        reminderAt: identical(reminderAt, _unset)
            ? this.reminderAt
            : reminderAt as DateTime?,
        repeatRule: identical(repeatRule, _unset)
            ? this.repeatRule
            : repeatRule as RepeatRule?,
        pinnedToday: pinnedToday ?? this.pinnedToday,
        completedAt: identical(completedAt, _unset)
            ? this.completedAt
            : completedAt as DateTime?,
        subtasks: subtasks ?? this.subtasks,
        sourceNoteId: identical(sourceNoteId, _unset)
            ? this.sourceNoteId
            : sourceNoteId as String?,
      );

  Map<String, dynamic> toStorage() => {
        'id': id,
        'title': title,
        'status': status,
        'note': note,
        'category': category,
        'categoryId': categoryId,
        'priority': priority,
        'dueAt': dueAt?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'repeatRule': repeatRule?.toJson(),
        'pinnedToday': pinnedToday,
        'completedAt': completedAt?.toIso8601String(),
        'subtasks': subtasks.map((step) => step.toStorage()).toList(),
        'sourceNoteId': sourceNoteId,
      };

  Map<String, dynamic> toSupabasePayload() => {
        'title': title,
        'status': status,
        'note': note,
        'category': category,
        if (categoryId != null) 'category_id': categoryId,
        'priority': priority,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'repeat_rule': repeatRule?.toJson(),
        'pinned_today': pinnedToday,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        if (sourceNoteId != null) 'source_note_id': sourceNoteId,
      };

  static RepeatRule? _readRepeatRule(Object? raw) {
    if (raw is! Map) return null;
    return RepeatRule.fromJson(Map<String, dynamic>.from(raw));
  }
}
