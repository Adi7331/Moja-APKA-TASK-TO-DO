import 'dart:async';

import 'package:dzien_po_dniu/update_gate.dart';
import 'package:dzien_po_dniu/update_service.dart';
import 'package:dzien_po_dniu/windows_zip_update_installer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final release = ReleaseInfo.fromJson({
    'version': '1.1.0',
    'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.0/app.apk',
  });

  testWidgets('shows a dismissible update notice for a newer Android release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGate(
          currentVersion: '1.0.0',
          platform: UpdatePlatform.android,
          checkForUpdate: () async => release,
          openDownload: (_) async => true,
          child: const Scaffold(body: Text('Aplikacja')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dostępna aktualizacja 1.1.0'), findsOneWidget);
    expect(find.text('Aktualizuj teraz'), findsOneWidget);

    await tester.tap(find.byTooltip('Zamknij informację o aktualizacji'));
    await tester.pump();

    expect(find.text('Dostępna aktualizacja 1.1.0'), findsNothing);
  });

  testWidgets('does not show an update notice without a system download', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGate(
          currentVersion: '1.0.0',
          platform: UpdatePlatform.windows,
          checkForUpdate: () async => release,
          openDownload: (_) async => true,
          child: const Scaffold(body: Text('Aplikacja')),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Dostępna aktualizacja'), findsNothing);
  });

  testWidgets('starts an Android ZIP update from the notice', (tester) async {
    var started = false;
    final zipRelease = ReleaseInfo.fromJson({
      'version': '1.1.1',
      'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/dzien-po-dniu-v1.1.1.zip',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGate(
          currentVersion: '1.1.0',
          platform: UpdatePlatform.android,
          checkForUpdate: () async => zipRelease,
          startUpdate: (_, _) async {
            started = true;
            return const WindowsUpdateStartResult.started();
          },
          child: const Scaffold(body: Text('Aplikacja')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Aktualizuj teraz'));
    await tester.pump();

    expect(started, isTrue);
  });

  testWidgets(
    'shows progress and the installer failure message for a Windows update',
    (tester) async {
      final pendingStart = Completer<WindowsUpdateStartResult>();
      final windowsRelease = ReleaseInfo.fromJson({
        'version': '1.1.1',
        'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/app.apk',
        'windowsUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/dzien-po-dniu-v1.1.1.zip',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UpdateGate(
            currentVersion: '1.1.0',
            platform: UpdatePlatform.windows,
            checkForUpdate: () async => windowsRelease,
            startUpdate: (_, _) => pendingStart.future,
            child: const Scaffold(body: Text('Aplikacja')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Aktualizuj teraz'));
      await tester.pump();

      expect(find.text('Pobieranie…'), findsOneWidget);

      pendingStart.complete(
        const WindowsUpdateStartResult.failed(
          'Nie udało się rozpocząć aktualizacji',
        ),
      );
      await tester.pump();

      expect(find.text('Nie udało się rozpocząć aktualizacji'), findsOneWidget);
      expect(find.text('Pobierz ręcznie'), findsOneWidget);
    },
  );

  testWidgets(
    'exits once after the Windows helper starts without opening a browser',
    (tester) async {
      var helperStarted = 0;
      var browserOpens = 0;
      var exits = 0;
      final windowsRelease = ReleaseInfo.fromJson({
        'version': '1.1.1',
        'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/app.apk',
        'windowsUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/dzien-po-dniu-v1.1.1.zip',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UpdateGate(
            currentVersion: '1.1.0',
            platform: UpdatePlatform.windows,
            checkForUpdate: () async => windowsRelease,
            startUpdate: (_, _) async =>
                const WindowsUpdateStartResult.started(),
            onWindowsHelperStarted: () => helperStarted++,
            exitApplication: (_) => exits++,
            openDownload: (_) async {
              browserOpens++;
              return true;
            },
            child: const Scaffold(body: Text('Aplikacja')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Aktualizuj teraz'));
      await tester.pump();

      expect(helperStarted, 1);
      expect(exits, 1);
      expect(browserOpens, 0);
    },
  );
}
