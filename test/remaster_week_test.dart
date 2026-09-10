import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/remaster_weekly_calendar.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone week selects a day without horizontal task scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildRemasterTheme(Brightness.dark),
      home: RemasterWeeklyCalendarScreen(
        tasks: [
          TaskItem(id: 'tuesday', title: 'Wtorkowe zadanie', status: 'todo', dueAt: DateTime(2026, 9, 8)),
        ],
        initialWeek: DateTime(2026, 9, 7),
        onOpenTask: (_) {},
        onMoveTask: (_, _) {},
        onQuickAdd: () {},
      ),
    ));

    await tester.tap(find.text('Wt'));
    await tester.pumpAndSettle();

    expect(find.text('Wtorkowe zadanie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
