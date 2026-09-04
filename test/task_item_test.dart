import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/subtask_item.dart';

void main() {
  test('keeps the database id when a task is created from a cloud row', () {
    final task = TaskItem.fromRow({
      'id': '8de852fa-5c83-4b01-8e22-bb0e1901d95e',
      'title': 'Wykosić trawnik',
      'status': 'todo',
      'note': '',
      'category': 'Dom',
      'priority': 'medium',
    });

    expect(task.id, '8de852fa-5c83-4b01-8e22-bb0e1901d95e');
    expect(task.isDone, isFalse);
  });

  test('round-trips a locally stored task including its due date', () {
    final original = TaskItem(
      id: 'local-4',
      title: 'Poprawić grafikę',
      status: 'in_progress',
      note: 'Baner do reklamy',
      category: 'Praca',
      priority: 'high',
      dueAt: DateTime(2026, 8, 31, 17),
    );

    final restored = TaskItem.fromStorage(original.toStorage());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.status, 'in_progress');
    expect(restored.dueAt, original.dueAt);
  });

  test('round-trips locally stored checklist progress', () {
    final task = TaskItem(
      id: 'local-5',
      title: 'Przygotować reklamę',
      status: 'todo',
      subtasks: const [
        SubtaskItem(id: 'step-1', title: 'Grafika', isDone: true, position: 0),
        SubtaskItem(id: 'step-2', title: 'Tekst', isDone: false, position: 1),
      ],
    );

    final restored = TaskItem.fromStorage(task.toStorage());

    expect(restored.subtaskCount, 2);
    expect(restored.completedSubtaskCount, 1);
  });

  test('retains organizer fields when a local task is restored', () {
    final restored = TaskItem.fromStorage({
      'id': 'local-organizer',
      'title': 'Rozciąganie',
      'status': 'todo',
      'reminderAt': '2026-09-07T08:45:00.000',
      'repeatRule': {
        'unit': 'week',
        'interval': 1,
        'weekdays': [1, 4],
      },
      'pinnedToday': true,
      'completedAt': '2026-09-06T18:00:00.000',
    });

    expect(restored.toStorage(), containsPair('reminderAt', '2026-09-07T08:45:00.000'));
    expect(restored.toStorage(), containsPair('repeatRule', {
      'unit': 'week',
      'interval': 1,
      'weekdays': [1, 4],
    }));
    expect(restored.toStorage(), containsPair('pinnedToday', true));
    expect(restored.toStorage(), containsPair('completedAt', '2026-09-06T18:00:00.000'));
  });

  test('creates a Supabase payload using database organizer field names', () {
    final task = TaskItem.fromStorage({
      'id': 'cloud-organizer',
      'title': 'Przegląd tygodnia',
      'status': 'done',
      'reminderAt': '2026-09-07T00:00:00.000',
      'repeatRule': {'unit': 'week', 'interval': 1, 'weekdays': [1]},
      'pinnedToday': false,
      'completedAt': '2026-09-06T18:00:00.000',
    });

    expect(task.toSupabasePayload(), {
      'title': 'Przegląd tygodnia',
      'status': 'done',
      'note': '',
      'category': 'Skrzynka',
      'priority': 'medium',
      'due_at': null,
      'reminder_at': '2026-09-06T22:00:00.000Z',
      'repeat_rule': {'unit': 'week', 'interval': 1, 'weekdays': [1]},
      'pinned_today': false,
      'completed_at': '2026-09-06T16:00:00.000Z',
    });
  });

  test('reads a synchronized subtask row from Supabase', () {
    final step = SubtaskItem.fromRow({
      'id': 'step-cloud-1',
      'title': 'Ustawić budżet',
      'is_done': true,
      'position': 3,
    });

    expect(step.isDone, isTrue);
    expect(step.position, 3);
  });
}
