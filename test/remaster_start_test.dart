import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/main.dart';
import 'package:dzien_po_dniu/remaster_shell.dart';

void main() {
  testWidgets(
    'preview keeps the search when switching tabs and completes real tasks',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'ui_remaster_v2': true});
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tryb lokalny'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Kreacje');
      await tester.pumpAndSettle();
      expect(find.text('Wykosić trawnik'), findsNothing);
      await tester.tap(find.text('Zadania').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start').last);
      await tester.pumpAndSettle();
      expect(find.text('Kreacje'), findsOneWidget);
      await tester.tap(find.byTooltip('Ukończ zadanie').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Przywróć zadanie'), findsOneWidget);
      await tester.tap(find.text('Cofnij'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ukończ zadanie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('preview is opt-in and can return to the original interface', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Podgląd nowego interfejsu'));
    await tester.pumpAndSettle();
    expect(find.byType(RemasterShell), findsOneWidget);
    await tester.tap(find.byTooltip('Konto i wygląd').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wróć do poprzedniego wyglądu'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Podgląd nowego interfejsu'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool('ui_remaster_v2'),
      false,
    );
  });
}
