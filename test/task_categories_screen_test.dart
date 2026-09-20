import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/task_categories_screen.dart';
import 'package:dzien_po_dniu/task_category.dart';

void main() {
  testWidgets('offers a clear empty state and creation action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TaskCategoriesScreen(
          categories: const [],
          onSave: (_) async {},
          onDelete: (_) async {},
          userId: 'test-user',
        ),
      ),
    );

    expect(find.text('Kategorie zadań'), findsOneWidget);
    expect(find.text('Bez kategorii'), findsOneWidget);
    expect(find.byTooltip('Dodaj kategorię'), findsOneWidget);
  });

  testWidgets('renders a saved category with its user-entered emoji', (tester) async {
    final time = DateTime.utc(2026, 9, 20);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskCategoriesScreen(
          userId: 'test-user',
          categories: [
            TaskCategory(
              id: 'c1',
              userId: 'test-user',
              name: 'Finanse',
              color: '#2F6FED',
              emoji: '💳',
              createdAt: time,
              updatedAt: time,
            ),
          ],
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('💳 Finanse'), findsOneWidget);
  });
}
