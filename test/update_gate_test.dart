import 'package:dzien_po_dniu/update_gate.dart';
import 'package:dzien_po_dniu/update_service.dart';
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
    expect(find.text('Pobierz'), findsOneWidget);

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
            return true;
          },
          child: const Scaffold(body: Text('Aplikacja')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Pobierz'));
    await tester.pump();

    expect(started, isTrue);
  });
}
