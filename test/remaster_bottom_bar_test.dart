import 'package:dzien_po_dniu/app_navigation_icon.dart';
import 'package:dzien_po_dniu/remaster_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact navigation is icon-only but keeps accessible names', (
    tester,
  ) async {
    AppSpace? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RemasterBottomBar(
            selected: AppSpace.notes,
            onSelected: (value) => chosen = value,
          ),
        ),
      ),
    );

    expect(find.text('Notatki'), findsNothing);
    expect(find.bySemanticsLabel('Notatki'), findsOneWidget);
    final bar = find.byType(RemasterBottomBar);
    expect(
      find.descendant(of: bar, matching: find.byType(Icon)),
      findsNothing,
      reason: 'Navigation marks must not disappear when the release font is subset.',
    );
    final marks = find.descendant(
      of: bar,
      matching: find.byType(AppNavigationIcon),
    );
    expect(marks, findsNWidgets(4));
    expect(
      find.descendant(of: marks, matching: find.byType(CustomPaint)),
      findsNWidgets(4),
    );
    await tester.tap(find.bySemanticsLabel('Koszty'));
    expect(chosen, AppSpace.costs);
    expect(tester.takeException(), isNull);
  });
}
