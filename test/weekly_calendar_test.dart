import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

  test('aligns an arbitrary midweek date to Monday local midnight', () {
    final days = weekDays(DateTime(2026, 4, 1));

    expect(days, [
      DateTime(2026, 3, 30),
      DateTime(2026, 3, 31),
      for (var day = 1; day <= 5; day++) DateTime(2026, 4, day),
    ]);
    expect(days.first, DateTime(2026, 3, 30));
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

  for (final viewport in <String, Size>{
    'phone': const Size(390, 844),
    'desktop': const Size(1100, 800),
  }.entries) {
    testWidgets(
      '${viewport.key} week has a visible control that returns to the previous route',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const Text('Poprzedni ekran'),
                    TextButton(
                      key: const ValueKey('open-week-route'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WeeklyCalendarScreen(
                            tasks: const [],
                            initialWeek: weekStart,
                            onOpenTask: (_) {},
                            onMoveTask: (_, _) {},
                            onQuickAdd: () {},
                          ),
                        ),
                      ),
                      child: const Text('Otwórz tydzień'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('open-week-route')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('week-back')), findsOneWidget);
        expect(find.byTooltip('Wróć'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('week-back')));
        await tester.pumpAndSettle();

        expect(find.text('Poprzedni ekran'), findsOneWidget);
        expect(find.byKey(const ValueKey('week-next')), findsNothing);
      },
    );
  }

  testWidgets('mobile week shows a move sheet that moves the dated task', (
    tester,
  ) async {
    TaskItem? movedTask;
    DateTime? movedDay;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCalendarScreen(
          tasks: [task('spotkanie', DateTime(2026, 9, 7, 14, 30))],
          initialWeek: weekStart,
          onOpenTask: (_) {},
          onMoveTask: (item, day) {
            movedTask = item;
            movedDay = day;
          },
          onQuickAdd: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('week-day-0')), findsOneWidget);
    expect(find.text('spotkanie'), findsOneWidget);
    expect(find.byKey(const ValueKey('move-task-spotkanie')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('move-task-spotkanie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-target-day-1')));
    await tester.pumpAndSettle();

    expect(movedTask?.id, 'spotkanie');
    expect(movedDay, DateTime(2026, 9, 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop week renders drop targets and accepts a dragged task', (
    tester,
  ) async {
    TaskItem? movedTask;
    DateTime? movedDay;
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCalendarScreen(
          tasks: [task('biurko', DateTime(2026, 9, 7, 9))],
          initialWeek: weekStart,
          onOpenTask: (_) {},
          onMoveTask: (item, day) {
            movedTask = item;
            movedDay = day;
          },
          onQuickAdd: () {},
        ),
      ),
    );

    for (var index = 0; index < 7; index++) {
      expect(find.byKey(ValueKey('week-drop-$index')), findsOneWidget);
    }

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('week-task-biurko'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(480, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedTask?.id, 'biurko');
    expect(movedDay, DateTime(2026, 9, 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop week gives every drop target the same width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCalendarScreen(
          tasks: const [],
          initialWeek: weekStart,
          onOpenTask: (_) {},
          onMoveTask: (_, _) {},
          onQuickAdd: () {},
        ),
      ),
    );

    final widths = [
      for (var index = 0; index < 7; index++)
        tester.getSize(find.byKey(ValueKey('week-drop-$index'))).width,
    ];

    expect(widths, everyElement(widths.first));
  });

  testWidgets('empty selected day offers quick add', (tester) async {
    var quickAdds = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyCalendarScreen(
          tasks: const [],
          initialWeek: weekStart,
          onOpenTask: (_) {},
          onMoveTask: (_, _) {},
          onQuickAdd: () => quickAdds++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('week-empty-add')));

    expect(quickAdds, 1);
  });
}
