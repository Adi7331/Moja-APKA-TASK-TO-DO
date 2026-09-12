import 'package:dzien_po_dniu/remaster_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings keeps appearance and sign out in one predictable view',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      ThemeMode? selected;
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RemasterSettingsScreen(
            syncStatus: 'Zsynchronizowano',
            themeMode: ThemeMode.system,
            onThemeMode: (mode) => selected = mode,
            onLegacy: () {},
            onSignOut: () => signedOut = true,
          ),
        ),
      );

      expect(find.text('Konto i ustawienia'), findsOneWidget);
      expect(find.text('Zsynchronizowano'), findsOneWidget);
      await tester.tap(find.text('Ciemny'));
      expect(selected, ThemeMode.dark);
      await tester.tap(find.text('Wyloguj się'));
      expect(signedOut, isTrue);
    },
  );

  testWidgets('connected calendar can change its selected calendars', (
    tester,
  ) async {
    var chooseCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterSettingsScreen(
          syncStatus: 'Zsynchronizowano',
          themeMode: ThemeMode.dark,
          onThemeMode: (_) {},
          onLegacy: () {},
          calendarConnected: true,
          onChooseCalendars: () => chooseCalls++,
        ),
      ),
    );

    expect(find.text('Wybierz kalendarze'), findsOneWidget);
    await tester.tap(find.text('Wybierz kalendarze'));
    expect(chooseCalls, 1);
  });
}
