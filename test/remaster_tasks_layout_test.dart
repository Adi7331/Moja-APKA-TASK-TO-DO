import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'phone task row keeps every direct action accessible without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.dark),
          home: Scaffold(
            body: RemasterTasksScreen(
              tasks: const [
                TaskItem(
                  id: 'task',
                  title: 'Przygotować wersję na telefon',
                  status: 'todo',
                  category: 'Praca',
                ),
              ],
              selectedView: TaskView.today,
              onViewChanged: (_) {},
              onOpenTask: (_) {},
              onStatusSelected: (_, _) {},
              onDeleteTask: (_) {},
              onPostponeTask: (_) {},
              onQuickAdd: () {},
              onOpenWeek: () {},
              onOpenWeeklyReview: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Oznacz jako do zrobienia'), findsOneWidget);
      expect(find.byTooltip('Oznacz jako w trakcie'), findsOneWidget);
      expect(find.byTooltip('Oznacz jako gotowe'), findsOneWidget);
      expect(find.byTooltip('Odłóż zadanie'), findsOneWidget);
      expect(find.byTooltip('Usuń zadanie'), findsOneWidget);
      expect(
        tester.getRect(find.text('Przygotować wersję na telefon')).width,
        greaterThan(120),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
