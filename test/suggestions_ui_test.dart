import 'package:dzien_po_dniu/remaster_shell.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('suggestions open only after an explicit tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterShell(
          syncStatus: 'Lokalnie',
          tasks: List.generate(
            6,
            (index) =>
                TaskItem(id: '$index', title: 'Zadanie $index', status: 'todo'),
          ),
          notes: const [],
          tasksContent: const SizedBox(),
          notesContent: const SizedBox(),
          onAddTask: () {},
          onAddNote: () {},
          onOpenTask: (_) {},
          onOpenNote: (_) {},
          onCompleteTask: (_) {},
          onOpenFocus: (_) {},
          onLegacy: () {},
          themeMode: ThemeMode.system,
          onThemeMode: (_) {},
        ),
      ),
    );

    expect(find.text('Zaplanuj 2 zadania na ten tydzień'), findsNothing);
    await tester.tap(find.byTooltip('Podpowiedzi'));
    await tester.pumpAndSettle();
    expect(find.text('Zaplanuj 2 zadania na ten tydzień'), findsOneWidget);
  });
}
