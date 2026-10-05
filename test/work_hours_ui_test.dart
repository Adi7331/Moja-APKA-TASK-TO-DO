import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/work_hours_screen.dart';
import 'package:dzien_po_dniu/work_hours.dart';
import 'package:dzien_po_dniu/work_hours_store.dart';
import 'package:dzien_po_dniu/remaster_tasks_screen.dart';
import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_view.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pl_PL'));
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('hours layout $brightness at $width with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width < 500 ? 1.6 : 1)),
              child: child!,
            ),
            home: const Scaffold(
              body: WorkHoursScreen(ownerId: 'local-user', cloudMode: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('add-work-day')));
        await tester.tap(find.byKey(const Key('add-work-day')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Zapisz'));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('monthly hours summary and visible save work on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = WorkHoursStore(
      await SharedPreferences.getInstance(),
      'local-user',
    );
    await store.setRate(4000);
    await store.put(
      WorkEntry(
        id: 'a',
        date: DateTime.now(),
        name: 'Ferroli',
        startMinute: 480,
        endMinute: 1020,
        rateCents: 4000,
        updatedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkHoursScreen(ownerId: 'local-user', cloudMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Do wypłaty'), findsOneWidget);
    expect(find.text('9 h'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-work-day')));
    await tester.pumpAndSettle();
    expect(find.text('Zapisz'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Zapisz'));
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Zapisz'), findsNothing);
    expect(
      store.entries.length,
      1,
    ); // original instance is a snapshot, not reloaded
    expect(
      WorkHoursStore(
        await SharedPreferences.getInstance(),
        'local-user',
      ).entries.length,
      2,
    );
  });
  testWidgets('tasks omit Inbox and category filter composes with view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemasterTasksScreen(
            tasks: const [
              TaskItem(
                id: 'a',
                title: 'Firma',
                status: 'todo',
                categoryId: 'business',
                category: 'Business',
              ),
              TaskItem(id: 'b', title: 'Domowe', status: 'todo'),
            ],
            selectedView: TaskView.today,
            onViewChanged: (_) {},
            onOpenTask: (_) {},
            onStatusSelected: (_, _) {},
            onPriorityChanged: (_) {},
            onDeleteTask: (_) {},
            onPostponeTask: (_) {},
            onQuickAdd: () {},
            onOpenWeek: () {},
            onOpenWeeklyReview: () {},
          ),
        ),
      ),
    );
    expect(find.text('Skrzynka'), findsNothing);
    await tester.tap(find.byKey(const Key('task-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business').last);
    await tester.pumpAndSettle();
    expect(find.text('Firma'), findsWidgets);
    expect(find.text('Domowe'), findsNothing);
  });
}
