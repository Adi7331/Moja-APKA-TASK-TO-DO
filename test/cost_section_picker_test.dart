import 'package:dzien_po_dniu/costs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Costs tabs show the full subscription label at ${width.toInt()}dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CostsSectionPicker(
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Subskrypcje'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(find.text('Subskrypcje'));
      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
    });
  }

  testWidgets('Costs tabs keep labels readable with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CostsSectionPicker(
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Subskrypcje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
