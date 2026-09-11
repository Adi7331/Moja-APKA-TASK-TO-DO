import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remastered task editor presents an intentional task draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showTaskEditor(
              context,
              remastered: true,
              onSave: (_) async {},
            ),
            child: const Text('Otwórz'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remaster-task-editor')), findsOneWidget);
    expect(find.text('Następny krok'), findsOneWidget);
    expect(find.text('Termin'), findsOneWidget);
  });
}
