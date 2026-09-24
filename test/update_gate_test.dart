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

    await tester.tap(
      find.bySemanticsLabel('Zamknij informację o aktualizacji'),
    );
    await tester.pump();

    expect(find.text('Dostępna aktualizacja 1.1.0'), findsNothing);
  });

  testWidgets('renders an update notice from MaterialApp builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UpdateGate(
          currentVersion: '1.0.0',
          platform: UpdatePlatform.android,
          checkForUpdate: () async => release,
          openDownload: (_) async => true,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Dostępna aktualizacja 1.1.0'), findsOneWidget);
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

  testWidgets('keeps the close control disabled while an update starts', (
    tester,
  ) async {
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

    final close = tester.widget<IconButton>(find.byType(IconButton));
    expect(close.onPressed, isNull);
    expect(find.text('Dostępna aktualizacja 1.1.1'), findsOneWidget);
  });

  testWidgets(
    'keeps manual download retryable and reports a failed manual launch',
    (tester) async {
      var manualAttempts = 0;
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
                const WindowsUpdateStartResult.failed('Automatyczna porażka'),
            openDownload: (_) async {
              manualAttempts++;
              if (manualAttempts == 1) throw StateError('Brak przeglądarki');
              return false;
            },
            child: const Scaffold(body: Text('Aplikacja')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Aktualizuj teraz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pobierz ręcznie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(manualAttempts, 1);

      expect(
        find.text('Nie udało się otworzyć ręcznego pobierania.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Pobierz ręcznie'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Pobierz ręcznie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(manualAttempts, 2);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Pobierz ręcznie'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('shows Windows manual fallback when starting an update throws', (
    tester,
  ) async {
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
          startUpdate: (_, _) async => throw StateError('Preflight failed'),
          child: const Scaffold(body: Text('Aplikacja')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Aktualizuj teraz'));
    await tester.pump();

    expect(find.text('Nie udało się rozpocząć aktualizacji.'), findsOneWidget);
    expect(find.text('Pobierz ręcznie'), findsOneWidget);
    expect(find.text('Aktualizuj teraz'), findsOneWidget);
  });

  testWidgets('exits after a successful Windows start even after unmounting', (
    tester,
  ) async {
    final pendingStart = Completer<WindowsUpdateStartResult>();
    var helperStarted = 0;
    var exits = 0;
    var showGate = true;
    StateSetter? setHostState;
    final windowsRelease = ReleaseInfo.fromJson({
      'version': '1.1.1',
      'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/app.apk',
      'windowsUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/dzien-po-dniu-v1.1.1.zip',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return showGate
                ? UpdateGate(
                    currentVersion: '1.1.0',
                    platform: UpdatePlatform.windows,
                    checkForUpdate: () async => windowsRelease,
                    startUpdate: (_, _) => pendingStart.future,
                    onWindowsHelperStarted: () => helperStarted++,
                    exitApplication: (_) => exits++,
                    child: const Scaffold(body: Text('Aplikacja')),
                  )
                : const Scaffold(body: Text('Następny ekran'));
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Aktualizuj teraz'));
    await tester.pump();
    setHostState!(() => showGate = false);
    await tester.pump();
    pendingStart.complete(const WindowsUpdateStartResult.started());
    await tester.pump();

    expect(helperStarted, 1);
    expect(exits, 1);
  });
}
