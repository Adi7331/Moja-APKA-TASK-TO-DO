import 'package:dzien_po_dniu/remaster_focus_mode_screen.dart';
import 'package:dzien_po_dniu/focus_session.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remastered focus mode exposes complete and postpone actions', (
    tester,
  ) async {
    var completed = false;
    var postponed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RemasterFocusModeScreen(
          task: TaskItem(id: '1', title: 'Przygotować plan', status: 'todo'),
          onComplete: () => completed = true,
          onPostpone: () => postponed = true,
        ),
      ),
    );

    expect(find.text('Skupienie'), findsOneWidget);
    expect(find.text('Przygotować plan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remaster-focus-complete')));
    expect(completed, isTrue);
    await tester.tap(find.byKey(const ValueKey('remaster-focus-postpone')));
    expect(postponed, isTrue);
  });

  testWidgets('remastered focus mode offers pomodoro and a custom timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RemasterFocusModeScreen(
          task: TaskItem(id: '1', title: 'Przygotować plan', status: 'todo'),
          onComplete: () {},
          onPostpone: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('focus-pomodoro')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-custom')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-start')), findsOneWidget);
  });

  testWidgets('finishing a running focus task saves a completed session', (
    tester,
  ) async {
    final sessions = <dynamic>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RemasterFocusModeScreen(
          task: TaskItem(id: 'task-1', title: 'Plan', status: 'todo'),
          onComplete: () {},
          onPostpone: () {},
          onSessionSaved: sessions.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('focus-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('remaster-focus-complete')));

    expect(sessions, hasLength(1));
    expect(sessions.single.completed, isTrue);
  });

  testWidgets('focus mode shows recent session history for its task', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterFocusModeScreen(
          task: const TaskItem(id: 'task-1', title: 'Plan', status: 'todo'),
          onComplete: () {},
          onPostpone: () {},
          recentSessions: [
            FocusSession(
              id: 'session-1',
              taskId: 'task-1',
              startedAt: now.subtract(const Duration(minutes: 25)),
              endedAt: now,
              plannedWorkSeconds: 1500,
              completed: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Ostatnia sesja'), findsOneWidget);
    expect(find.text('Ukończona · 25 min'), findsOneWidget);
  });
}
