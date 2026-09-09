// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/main.dart';
import 'package:dzien_po_dniu/subtask_item.dart';
import 'package:dzien_po_dniu/task_editor.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_row.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:dzien_po_dniu/today_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('moving a task reschedules its implicit due-time reminder', () {
    final plan = planTaskMoveToWeekDay(
      TaskItem(
        id: 'implicit-reminder',
        title: 'Spotkanie',
        status: 'todo',
        dueAt: DateTime(2026, 9, 7, 14, 30),
      ),
      DateTime(2026, 9, 9),
    );

    expect(plan.updatedTask.dueAt, DateTime(2026, 9, 9, 14, 30));
    expect(plan.updatedTask.reminderAt, isNull);
    expect(plan.reminderTime, DateTime(2026, 9, 9, 14, 30));
  });

  test('moving a task preserves a custom reminder without rescheduling it', () {
    final customReminder = DateTime(2026, 9, 7, 13, 45);
    final plan = planTaskMoveToWeekDay(
      TaskItem(
        id: 'custom-reminder',
        title: 'Spotkanie',
        status: 'todo',
        dueAt: DateTime(2026, 9, 7, 14, 30),
        reminderAt: customReminder,
      ),
      DateTime(2026, 9, 9),
    );

    expect(plan.updatedTask.dueAt, DateTime(2026, 9, 9, 14, 30));
    expect(plan.updatedTask.reminderAt, customReminder);
    expect(plan.reminderTime, isNull);
  });

  testWidgets('shows the current cloud sync status in the daily header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          syncStatus: 'Zsynchronizowano',
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () {},
        ),
      ),
    );

    expect(find.text('Zsynchronizowano'), findsOneWidget);
  });

  testWidgets('offers sign out in the account menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () {},
          onSignOut: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('task-view-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Wyloguj'), findsOneWidget);
  });

  testWidgets('shows the sectioned daily plan', (WidgetTester tester) async {
    var quickAddTapped = false;
    final important = TaskItem(
      id: 'important',
      title: 'Poprawić grafikę',
      status: 'todo',
      category: 'Praca',
      dueAt: DateTime(2026, 8, 31, 14),
      subtasks: const [
        SubtaskItem(id: '1', title: 'Pierwszy', isDone: true, position: 0),
        SubtaskItem(id: '2', title: 'Drugi', isDone: true, position: 1),
        SubtaskItem(id: '3', title: 'Trzeci', isDone: false, position: 2),
        SubtaskItem(id: '4', title: 'Czwarty', isDone: false, position: 3),
        SubtaskItem(id: '5', title: 'Piąty', isDone: false, position: 4),
      ],
    );
    final later = TaskItem(
      id: 'later',
      title: 'Wykosić trawnik',
      status: 'todo',
      category: 'Dom',
      dueAt: DateTime(2026, 9, 1, 18),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: [important],
          laterTasks: [later],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () => quickAddTapped = true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Najważniejsze'), findsOneWidget);
    expect(find.text('Później'), findsOneWidget);
    expect(find.text('Poprawić grafikę'), findsWidgets);
    expect(find.text('2 z 5 kroków'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Szybko zapisz zadanie'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-add-task')));
    expect(quickAddTapped, isTrue);
  });

  testWidgets('opens quick add when the empty focus card is tapped', (
    WidgetTester tester,
  ) async {
    var quickAddTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          syncStatus: 'Lokalnie',
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () => quickAddTapped = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-focus-mode')));

    expect(quickAddTapped, isTrue);
  });

  testWidgets('does not render category emoji in a task row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskRow(
            task: const TaskItem(
              id: 'no-category-emoji',
              title: 'Zadanie bez emoji',
              status: 'todo',
              category: 'Dom',
            ),
            onOpen: () {},
            onComplete: () {},
            onStatusSelected: (_) {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('🏠'), findsNothing);
    expect(find.text('Dom'), findsOneWidget);
  });

  testWidgets('submits a compact quick task without opening the full editor', (
    WidgetTester tester,
  ) async {
    var submitted = '';
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () {},
          onQuickAddText: (value) => submitted = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('quick-task-input')),
      'Zadzwonić jutro 18:30',
    );
    await tester.tap(find.byKey(const ValueKey('quick-task-submit')));

    expect(submitted, 'Zadzwonić jutro 18:30');
  });

  testWidgets(
    'opens focus from the now card when a focus callback is available',
    (WidgetTester tester) async {
      TaskItem? focused;
      final task = TaskItem(
        id: 'now-task',
        title: 'Jedna ważna rzecz',
        status: 'todo',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TodayScreen(
            visibleTasks: [task],
            laterTasks: const [],
            selectedView: TaskView.today,
            onViewChanged: (_) {},
            themeMode: ThemeMode.system,
            onThemeModeChanged: (_) {},
            successNotice: null,
            searchQuery: '',
            onSearchChanged: (_) {},
            selectedFilter: 'all',
            onFilterChanged: (_) {},
            onOpenTask: (_) {},
            onCompleteTask: (_) {},
            onStatusSelected: (_, _) {},
            onDeleteTask: (_) {},
            onQuickAdd: () {},
            onOpenFocus: (item) => focused = item,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-focus-mode')));
      expect(focused?.id, 'now-task');
    },
  );

  testWidgets('opens the focus route from the local daily plan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-focus-mode')));
    await tester.pumpAndSettle();

    expect(find.text('Skupienie'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-complete')), findsOneWidget);
  });

  testWidgets('changes the current view from the compact menu', (
    WidgetTester tester,
  ) async {
    TaskView? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (view) => selected = view,
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('task-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skrzynka').last);
    expect(selected, TaskView.inbox);
  });

  testWidgets('selects the dark appearance from settings', (
    WidgetTester tester,
  ) async {
    ThemeMode? selectedTheme;
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.today,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (mode) => selectedTheme = mode,
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('task-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ustawienia').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ciemny'));

    expect(selectedTheme, ThemeMode.dark);
  });

  testWidgets('shows a Google login error and keeps local mode available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLocalMode: () {},
          onSignedIn: () async {},
          onGoogleSignIn: () async {
            throw Exception('Google is unavailable');
          },
        ),
      ),
    );

    await tester.tap(find.text('Kontynuuj z Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nie udało się połączyć z Google. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.text('Tryb lokalny'), findsOneWidget);
  });

  testWidgets('shows the compact Today task list instead of a counter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Kontynuuj z Google'), findsOneWidget);
    expect(find.text('Adres e-mail'), findsOneWidget);
  });

  testWidgets('marks a task as completed from the compact list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsWidgets);
  });

  testWidgets(
    'uses direct desktop status controls without a task overflow menu',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var statusSelections = 0;
      var selectedStatus = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskRow(
              task: const TaskItem(
                id: 'desktop-status',
                title: 'Przygotować kreację',
                status: 'todo',
                note: 'Sprawdzić formaty na Instagram.',
                category: 'Praca',
              ),
              onOpen: () {},
              onComplete: () {},
              onStatusSelected: (status) {
                statusSelections++;
                selectedStatus = status;
              },
              onDelete: () {},
              onTogglePin: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('status-todo')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-in_progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-done')), findsOneWidget);
      expect(find.text('Sprawdzić formaty na Instagram.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('status-in_progress')));
      await tester.pumpAndSettle();
      expect(statusSelections, 1);
      expect(selectedStatus, 'in_progress');

      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(
        find.byKey(const ValueKey('delete-task-desktop-status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pin-task-desktop-status')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'keeps all desktop status controls visible in a sidebar-constrained task row',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 844)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 476,
                  child: TaskRow(
                    task: const TaskItem(
                      id: 'sidebar-constrained-desktop-status',
                      title: 'Przygotować kreację',
                      status: 'todo',
                      category: 'Praca',
                    ),
                    onOpen: () {},
                    onComplete: () {},
                    onStatusSelected: (_) {},
                    onDelete: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('status-todo')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-in_progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-done')), findsOneWidget);
      expect(find.text('Do zrobienia'), findsNothing);
      expect(find.text('W trakcie'), findsNothing);
      expect(find.text('Gotowe'), findsNothing);
      expect(find.byTooltip('Do zrobienia'), findsOneWidget);
      expect(find.byTooltip('W trakcie'), findsOneWidget);
      expect(find.byTooltip('Gotowe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows both mobile status actions in a 390 pixel task row without overflow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: TaskRow(
                task: const TaskItem(
                  id: 'mobile-status-integration',
                  title: 'Przygotować kreację',
                  status: 'todo',
                ),
                onOpen: () {},
                onComplete: () {},
                onStatusSelected: (_) {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('mobile-status-cycle')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-status-options')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows direct delete and pin actions without a task overflow menu',
    (WidgetTester tester) async {
      var deleted = false;
      var pinned = false;
      var postponed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskRow(
              task: const TaskItem(
                id: 'direct-actions',
                title: 'Zadanie z szybkim działaniem',
                status: 'todo',
              ),
              onOpen: () {},
              onComplete: () {},
              onStatusSelected: (_) {},
              onDelete: () => deleted = true,
              onTogglePin: () => pinned = true,
              onPostpone: () => postponed = true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('delete-task-direct-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pin-task-direct-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('postpone-task-direct-actions')),
        findsOneWidget,
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pin-task-direct-actions')));
      await tester.tap(
        find.byKey(const ValueKey('postpone-task-direct-actions')),
      );
      await tester.tap(
        find.byKey(const ValueKey('delete-task-direct-actions')),
      );

      expect(pinned, isTrue);
      expect(postponed, isTrue);
      expect(deleted, isTrue);
    },
  );

  testWidgets('restores a locally deleted task from the undo action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-task-local-1')).first);
    await tester.pumpAndSettle();
    expect(find.text('Usunąć zadanie?'), findsOneWidget);
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();

    expect(find.text('Zadanie usunięte'), findsOneWidget);
    expect(find.text('Wykosić trawnik'), findsNothing);
    await tester.tap(find.text('Cofnij'));
    await tester.pumpAndSettle();

    expect(find.text('Wykosić trawnik'), findsWidgets);
  });

  testWidgets('restores a completed local task from the undo action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Zadanie oznaczone jako gotowe'), findsOneWidget);
    await tester.tap(find.text('Cofnij'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle_outlined), findsWidgets);
  });

  testWidgets('postpones a local task from its direct task action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('postpone-task-local-1')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jutro rano'));
    await tester.pumpAndSettle();

    expect(find.text('Zadanie odłożone'), findsOneWidget);
  });

  testWidgets('filters local tasks by the search phrase', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('task-search')),
      'grafikę',
    );
    await tester.pump();

    expect(find.text('Poprawić grafikę'), findsWidgets);
    expect(find.text('Wykosić trawnik'), findsNothing);
  });

  testWidgets('shows only completed tasks after selecting that filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.circle_outlined).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gotowe'));
    await tester.pump();

    expect(find.text('Wykosić trawnik'), findsOneWidget);
    expect(find.text('Poprawić grafikę'), findsNothing);
  });

  testWidgets('opens an edit sheet after tapping a task title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    expect(find.text('Edytuj zadanie'), findsOneWidget);
  });

  testWidgets('adds a task from the quick daily action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-input')),
      'Nowe zadanie',
    );
    await tester.tap(find.text('Dodaj zadanie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Dodaj zadanie'), findsNothing);
    expect(find.text('Nowe zadanie'), findsWidgets);
    expect(find.text('Zapisano zadanie'), findsOneWidget);
  });

  testWidgets('adds a locally parsed quick task from the daily plan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick-task-input')),
      'Oddzwonić do Marka jutro 18:30',
    );
    await tester.tap(find.byKey(const ValueKey('quick-task-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Zapisano zadanie'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Oddzwonić do Marka'), findsWidgets);
  });

  testWidgets('expands additional task editor options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    expect(find.text('Edytuj zadanie'), findsOneWidget);
    expect(find.text('Termin'), findsOneWidget);
    expect(find.text('Więcej opcji'), findsOneWidget);
    expect(find.text('Opis (opcjonalnie)'), findsNothing);

    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();

    expect(find.text('Opis (opcjonalnie)'), findsOneWidget);
    expect(find.text('Kategoria'), findsOneWidget);
    expect(find.text('Priorytet'), findsOneWidget);
  });

  testWidgets('adds a local checklist step and shows its progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('subtask-input')),
      'Przygotować baner',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('add-subtask')));
    await tester.tap(find.byKey(const ValueKey('add-subtask')));
    await tester.pump();
    expect(find.text('Przygotować baner'), findsOneWidget);
    await tester.ensureVisible(find.text('Zapisz zmiany'));
    await tester.tap(find.text('Zapisz zmiany'));
    await tester.pumpAndSettle();

    expect(find.text('Poprawić grafikę'), findsWidgets);
    expect(find.text('0 z 1 kroków'), findsOneWidget);
  });

  testWidgets('marks a checklist step as completed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('subtask-input')),
      'Przygotować baner',
    );
    await tester.tap(find.byKey(const ValueKey('add-subtask')));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.ensureVisible(find.text('Zapisz zmiany'));
    await tester.tap(find.text('Zapisz zmiany'));
    await tester.pumpAndSettle();

    expect(find.text('1 z 1 kroków'), findsOneWidget);
  });

  testWidgets('sets a quick deadline from the task editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showTaskEditor(context, onSave: (_) async {}),
            child: const Text('Otwórz edytor'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz edytor'));
    await tester.pumpAndSettle();

    expect(find.text('Dodaj termin i godzinę'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('due-today')));
    await tester.pump();

    expect(find.text('Dodaj termin i godzinę'), findsNothing);
  });

  testWidgets('editor saves a due-date reminder and weekly repeat', (
    tester,
  ) async {
    TaskDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () =>
                showTaskEditor(context, onSave: (draft) async => saved = draft),
            child: const Text('Otwórz edytor organizera'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz edytor organizera'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-input')),
      'Rytuał',
    );
    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('repeat-weekly')));
    await tester.tap(find.byKey(const ValueKey('repeat-weekly')));
    await tester.ensureVisible(find.byKey(const ValueKey('reminder-due')));
    await tester.tap(find.byKey(const ValueKey('reminder-due')));
    await tester.ensureVisible(find.text('Dodaj zadanie'));
    await tester.tap(find.text('Dodaj zadanie'));
    await tester.pumpAndSettle();

    expect(saved!.repeatRule?.unit.name, 'week');
    expect(saved!.reminderAt, isNull);
  });

  testWidgets('shows task status, priority, and a note preview', (
    WidgetTester tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskRow(
            task: const TaskItem(
              id: 'in-progress',
              title: 'Przygotować kreację',
              status: 'in_progress',
              priority: 'high',
              note: 'Sprawdzić formaty na Instagram.',
              category: 'Praca',
            ),
            onOpen: () {},
            onComplete: () => completed = true,
            onStatusSelected: (_) {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('W trakcie'), findsOneWidget);
    expect(find.text('Wysoki priorytet'), findsOneWidget);
    expect(find.text('Sprawdzić formaty na Instagram.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.circle_outlined));
    expect(completed, isTrue);
  });

  testWidgets('guides the user when the inbox is empty', (
    WidgetTester tester,
  ) async {
    var quickAddTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          visibleTasks: const [],
          laterTasks: const [],
          selectedView: TaskView.inbox,
          onViewChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          successNotice: null,
          searchQuery: '',
          onSearchChanged: (_) {},
          selectedFilter: 'all',
          onFilterChanged: (_) {},
          onOpenTask: (_) {},
          onCompleteTask: (_) {},
          onStatusSelected: (_, _) {},
          onDeleteTask: (_) {},
          onQuickAdd: () => quickAddTapped = true,
        ),
      ),
    );

    expect(find.text('Skrzynka jest pusta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('empty-add-task')));
    expect(quickAddTapped, isTrue);
  });

  testWidgets('opens week from the compact menu at 390 pixels', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final futureDate = DateTime.now().add(const Duration(days: 30));
    SharedPreferences.setMockInitialValues({
      'local_tasks_v1': jsonEncode([
        {
          'id': 'hidden-completed',
          'title': 'Ukończone później',
          'status': 'done',
          'note': '',
          'category': 'Skrzynka',
          'priority': 'medium',
          'dueAt': futureDate.toIso8601String(),
          'reminderAt': null,
          'repeatRule': null,
          'pinnedToday': false,
          'completedAt': null,
          'subtasks': <Map<String, Object?>>[],
        },
      ]),
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tydzień').last);
    await tester.pumpAndSettle();

    expect(find.text('Tydzień'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-next')), findsOneWidget);
  });

  testWidgets('opens week from desktop navigation', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tydzień'));
    await tester.pumpAndSettle();

    expect(find.text('Tydzień'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-next')), findsOneWidget);
  });

  testWidgets('persists a task moved to another day from the mobile week', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );
    final sourceDue = DateTime(
      monday.year,
      monday.month,
      monday.day + 6,
      9,
      30,
    );
    final targetDue = DateTime(
      monday.year,
      monday.month,
      monday.day + 1,
      9,
      30,
    );
    SharedPreferences.setMockInitialValues({
      'local_tasks_v1': jsonEncode([
        {
          'id': 'seeded-week',
          'title': 'Zadanie do przeniesienia',
          'status': 'todo',
          'note': '',
          'category': 'Praca',
          'priority': 'medium',
          'dueAt': sourceDue.toIso8601String(),
          'reminderAt': null,
          'repeatRule': null,
          'pinnedToday': false,
          'completedAt': null,
          'subtasks': <Map<String, Object?>>[],
        },
      ]),
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tydzień').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('week-day-0')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('week-day-6')));
    await tester.pumpAndSettle();
    expect(find.text('Zadanie do przeniesienia'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-task-seeded-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-target-day-1')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Tydzień'))).pop();
    await tester.binding.setSurfaceSize(const Size(700, 844));
    await tester.pumpAndSettle();

    final expectedDate =
        '${targetDue.day.toString().padLeft(2, '0')}.${targetDue.month.toString().padLeft(2, '0')} · 09:30';
    expect(find.text('Zadanie do przeniesienia'), findsWidgets);
    expect(find.textContaining(expectedDate), findsOneWidget);
  });

  testWidgets('opens weekly review from desktop navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Przegląd tygodnia'));
    await tester.pumpAndSettle();

    expect(find.text('Ukończone w poprzednim tygodniu'), findsOneWidget);
  });
}
