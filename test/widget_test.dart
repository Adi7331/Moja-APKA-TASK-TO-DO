// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/main.dart';
import 'package:dzien_po_dniu/subtask_item.dart';
import 'package:dzien_po_dniu/task_category_icon.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:dzien_po_dniu/today_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maps known categories to a restrained emoji hint', () {
    expect(categoryEmoji('Praca'), '💼');
    expect(categoryEmoji('Dom'), '🏠');
    expect(categoryEmoji('Skrzynka'), isNull);
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
    expect(find.text('Szybko zapisz zadanie'), findsOneWidget);
    expect(find.text('Poprawić grafikę'), findsWidgets);
    expect(find.text('2 z 5 kroków'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-add-task')));
    expect(quickAddTapped, isTrue);
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

  testWidgets('can mark a local task as in progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'W trakcie'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'W trakcie'));
    await tester.pumpAndSettle();
    expect(find.text('Wykosić trawnik'), findsWidgets);
  });

  testWidgets('shows a delete action in the task menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Usuń zadanie'), findsOneWidget);
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

    await tester.tap(find.text('Gotowe'));
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
}
