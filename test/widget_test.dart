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
import 'package:dzien_po_dniu/task_category_icon.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maps known categories to a restrained emoji hint', () {
    expect(categoryEmoji('Praca'), '💼');
    expect(categoryEmoji('Dom'), '🏠');
    expect(categoryEmoji('Skrzynka'), isNull);
  });

  testWidgets('shows the compact Today task list instead of a counter',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Zaloguj się'), findsOneWidget);
    expect(find.text('Kontynuuj z Google'), findsOneWidget);
    expect(find.text('Adres e-mail'), findsOneWidget);
  });

  testWidgets('marks a task as completed from the compact list', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();
    expect(find.textContaining('Ukończone'), findsWidgets);
  });

  testWidgets('can mark a local task as in progress', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>).at(1));
    await tester.pumpAndSettle();

    expect(find.textContaining('W trakcie'), findsWidgets);
  });

  testWidgets('shows a delete action in the task menu', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();

    expect(find.text('Usuń zadanie'), findsOneWidget);
  });

  testWidgets('filters local tasks by the search phrase', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'grafikę');
    await tester.pump();

    expect(find.text('Poprawić grafikę'), findsOneWidget);
    expect(find.text('Wykosić trawnik'), findsNothing);
  });

  testWidgets('shows only completed tasks after selecting that filter', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pump();

    await tester.tap(find.byType(ChoiceChip).at(3));
    await tester.pump();

    expect(find.text('Wykosić trawnik'), findsOneWidget);
    expect(find.text('Poprawić grafikę'), findsNothing);
  });

  testWidgets('opens an edit sheet after tapping a task title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();

    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    expect(find.text('Edytuj zadanie'), findsOneWidget);
  });

  testWidgets('adds a local checklist step and shows its progress', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('subtask-input')), 'Przygotować baner');
    await tester.ensureVisible(find.byKey(const ValueKey('add-subtask')));
    await tester.tap(find.byKey(const ValueKey('add-subtask')));
    await tester.pump();
    expect(find.text('Przygotować baner'), findsOneWidget);
    await tester.ensureVisible(find.text('Zapisz zmiany'));
    await tester.tap(find.text('Zapisz zmiany'));
    await tester.pumpAndSettle();

    expect(find.text('Poprawić grafikę'), findsOneWidget);
    expect(find.text('0/1 kroków'), findsOneWidget);
  });

  testWidgets('marks a checklist step as completed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pump();
    await tester.tap(find.text('Poprawić grafikę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('subtask-input')), 'Przygotować baner');
    await tester.tap(find.byKey(const ValueKey('add-subtask')));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.ensureVisible(find.text('Zapisz zmiany'));
    await tester.tap(find.text('Zapisz zmiany'));
    await tester.pumpAndSettle();

    expect(find.text('1/1 kroków'), findsOneWidget);
  });
}
