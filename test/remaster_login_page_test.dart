import 'package:dzien_po_dniu/remaster_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remastered login offers Google and local mode access', (
    tester,
  ) async {
    var localModeOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RemasterLoginPage(
          onLocalMode: () => localModeOpened = true,
          onSignedIn: () async {},
          onGoogleSignIn: () async {},
        ),
      ),
    );

    expect(find.text('Dniówka'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-mark')), findsOneWidget);
    expect(find.text('Kontynuuj z Google'), findsOneWidget);
    expect(find.text('Tryb lokalny'), findsOneWidget);

    await tester.tap(find.text('Tryb lokalny'));
    expect(localModeOpened, isTrue);
  });
}
