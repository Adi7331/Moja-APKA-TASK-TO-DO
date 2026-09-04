import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_status_control.dart';

void main() {
  Widget harness({required String status, required ValueChanged<String> onStatusSelected}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TaskStatusControl(
            status: status,
            onStatusSelected: onStatusSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('desktop exposes all status controls and selects in progress', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 600));
    String? selected;
    await tester.pumpWidget(harness(status: 'todo', onStatusSelected: (value) => selected = value));

    expect(find.byKey(const ValueKey('status-todo')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-in_progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-done')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-in_progress')));
    expect(selected, 'in_progress');
  });

  testWidgets('mobile cycles status and offers direct options without layout errors', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    String selected = 'todo';
    await tester.pumpWidget(harness(status: selected, onStatusSelected: (value) => selected = value));

    expect(find.byKey(const ValueKey('mobile-status-cycle')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-status-options')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-status-cycle')));
    expect(selected, 'in_progress');

    await tester.tap(find.byKey(const ValueKey('mobile-status-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gotowe').last);
    expect(selected, 'done');
    expect(tester.takeException(), isNull);
  });
}
