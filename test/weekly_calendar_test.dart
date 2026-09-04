import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/weekly_calendar.dart';

TaskItem task(String id, DateTime? dueAt) =>
    TaskItem(id: id, title: id, status: 'todo', dueAt: dueAt);

void main() {
  final weekStart = DateTime(2026, 9, 7);

  test('returns seven local-midnight dates beginning on Monday', () {
    final days = weekDays(weekStart);

    expect(days, hasLength(7));
    expect(days.first, DateTime(2026, 9, 7));
    expect(days.last, DateTime(2026, 9, 13));
    expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
  });

  test('keeps every day at local midnight across a DST transition', () {
    final days = weekDays(DateTime(2026, 10, 19));

    expect(days, [
      for (var day = 19; day <= 25; day++) DateTime(2026, 10, day),
    ]);
    expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
  });

  test('groups a task by its due date and leaves the next day empty', () {
    final grouped = tasksByDay([
      task('monday', DateTime(2026, 9, 7, 14, 30)),
    ], weekStart);

    expect(grouped[DateTime(2026, 9, 7)]!.map((item) => item.id), ['monday']);
    expect(grouped[DateTime(2026, 9, 8)], isEmpty);
  });

  test('sorts tasks and excludes undated and out-of-week tasks', () {
    final grouped = tasksByDay([
      task('late', DateTime(2026, 9, 7, 16)),
      task('undated', null),
      task('early', DateTime(2026, 9, 7, 9)),
      task('outside', DateTime(2026, 9, 14, 9)),
    ], weekStart);

    expect(grouped[DateTime(2026, 9, 7)]!.map((item) => item.id), [
      'early',
      'late',
    ]);
    expect(
      grouped.values.expand((items) => items).map((item) => item.id),
      isNot(contains('undated')),
    );
    expect(
      grouped.values.expand((items) => items).map((item) => item.id),
      isNot(contains('outside')),
    );
  });

  test('moves a task while preserving its due time', () {
    final moved = moveTaskToDay(
      task('timed', DateTime(2026, 9, 7, 14, 30)),
      DateTime(2026, 9, 10),
    );

    expect(moved.dueAt, DateTime(2026, 9, 10, 14, 30));
  });

  test('uses 09:00 when moving an undated task', () {
    final moved = moveTaskToDay(task('unset', null), DateTime(2026, 9, 10));

    expect(moved.dueAt, DateTime(2026, 9, 10, 9));
  });
}
