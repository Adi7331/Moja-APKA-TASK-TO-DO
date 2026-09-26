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
            onPressed: () =>
                showTaskEditor(context, remastered: true, onSave: (_) async {}),
            child: const Text('Otwórz'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remaster-task-editor')), findsOneWidget);
    expect(find.text('Następny krok'), findsOneWidget);
    expect(find.text('Opis (opcjonalnie)'), findsOneWidget);
    expect(find.text('Termin'), findsOneWidget);
    expect(find.text('Lista kroków'), findsNothing);

    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();

    expect(find.text('Lista kroków'), findsOneWidget);
    expect(find.text('Wygląd zadania'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-color-mint')), findsOneWidget);
  });

  testWidgets('saves the selected emoji, color and uncategorized state', (
    tester,
  ) async {
    TaskDraft? saved;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.light),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showTaskEditor(
              context,
              remastered: true,
              onSave: (draft) async => saved = draft,
            ),
            child: const Text('Otwórz'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-input')),
      'Spacer',
    );
    await tester.tap(find.text('Więcej opcji'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-emoji-input')),
      '🏃',
    );
    await tester.tap(find.byKey(const ValueKey('task-color-mint')));
    await tester.ensureVisible(find.text('Dodaj zadanie'));
    await tester.tap(find.text('Dodaj zadanie'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.categoryId, isNull);
    expect(saved!.category, 'Bez kategorii');
    expect(saved!.emoji, '🏃');
    expect(saved!.colorKey, 'mint');
  });
}
