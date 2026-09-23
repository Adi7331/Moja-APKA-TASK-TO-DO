import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/task_postpone_sheet.dart';
import 'package:dzien_po_dniu/task_schedule.dart';

void main() {
  testWidgets('offers clear postponement choices in a phone-safe sheet', (
    tester,
  ) async {
    PostponeOption? selected;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async => selected = await showTaskPostponeSheet(context),
            child: const Text('Odłóż'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Odłóż'));
    await tester.pumpAndSettle();
    expect(find.text('Odłóż zadanie'), findsOneWidget);
    expect(find.text('Za godzinę'), findsOneWidget);
    expect(find.text('Jutro rano'), findsOneWidget);
    expect(find.text('W poniedziałek'), findsOneWidget);

    await tester.tap(find.text('Jutro rano'));
    await tester.pumpAndSettle();
    expect(selected, PostponeOption.tomorrowMorning);
  });
}
