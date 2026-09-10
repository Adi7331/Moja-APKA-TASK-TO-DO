import 'package:dzien_po_dniu/remaster_focus_mode_screen.dart';
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
}
