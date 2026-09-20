import 'package:dzien_po_dniu/remaster_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/organizer_settings.dart';

void main() {
  testWidgets(
    'settings keeps appearance and sign out in one predictable view',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      ThemeMode? selected;
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RemasterSettingsScreen(
            appVersion: '1.1.4',
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
      await tester.scrollUntilVisible(
        find.text('Wyloguj się'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Wyloguj się'));
      expect(signedOut, isTrue);
    },
  );

  testWidgets('connected calendar can change its selected calendars', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var chooseCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterSettingsScreen(
          appVersion: '1.1.4',
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
    await tester.scrollUntilVisible(
      find.text('Wybierz kalendarze'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Wybierz kalendarze'));
    expect(chooseCalls, 1);
  });

  testWidgets('shows the app version and starts a manual update check', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterSettingsScreen(
          appVersion: '1.1.4',
          syncStatus: 'Zsynchronizowano',
          themeMode: ThemeMode.dark,
          onThemeMode: (_) {},
          onLegacy: () {},
          onCheckForUpdate: () async => checks++,
        ),
      ),
    );

    expect(find.text('Wersja aplikacji'), findsOneWidget);
    expect(find.text('1.1.4'), findsOneWidget);
    await tester.tap(find.text('Sprawdź aktualizacje'));
    await tester.pump();
    expect(checks, 1);
  });

  testWidgets('reminder settings are opt-in and expose test action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    OrganizerSettings? changed;
    var testSent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RemasterSettingsScreen(
          appVersion: '1.1.4',
          syncStatus: 'Zsynchronizowano',
          themeMode: ThemeMode.dark,
          onThemeMode: (_) {},
          onLegacy: () {},
          onOrganizerSettings: (value) => changed = value,
          onTestReminder: () => testSent = true,
        ),
      ),
    );

    expect(find.text('Wyłączone domyślnie — włącz, gdy tego potrzebujesz.'),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(SwitchListTile));
    expect(changed?.dailyPlanEnabled, isTrue);
    await tester.scrollUntilVisible(
      find.text('Wyślij test'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Wyślij test'));
    expect(testSent, isTrue);
  });
}
