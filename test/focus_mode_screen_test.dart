import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/focus_mode_screen.dart';
import 'package:dzien_po_dniu/task_item.dart';

void main() {
  for (final viewport in <String, Size>{
    'phone': const Size(390, 844),
    'desktop': const Size(1100, 800),
  }.entries) {
    testWidgets('${viewport.key} focus view exposes clear task actions', (
      tester,
    ) async {
      var completed = false;
      var postponed = false;
      await tester.binding.setSurfaceSize(viewport.value);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: FocusModeScreen(
            task: const TaskItem(
              id: 'focus-task',
              title: 'Przygotować prezentację',
              status: 'todo',
              note: 'Pierwszy krok: szkic slajdów.',
            ),
            onComplete: () => completed = true,
            onPostpone: () => postponed = true,
          ),
        ),
      );

      expect(find.text('Skupienie'), findsOneWidget);
      expect(find.text('Przygotować prezentację'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-complete')), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-postpone')), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-back')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('focus-complete')));
      await tester.tap(find.byKey(const ValueKey('focus-postpone')));
      expect(completed, isTrue);
      expect(postponed, isTrue);
    });
  }
}
