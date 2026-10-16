import 'package:dzien_po_dniu/business_screen.dart';
import 'package:dzien_po_dniu/remaster_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(390, 844), const Size(1366, 768)]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'Business screen fits $size in $brightness text=$textScale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({});

            await tester.pumpWidget(
              MaterialApp(
                theme: buildRemasterTheme(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Pomysły, produkty i testy'), findsOneWidget);
            expect(find.text('Przegląd'), findsOneWidget);
            expect(find.text('Produkty'), findsWidgets);
            if (size.width < 700) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(-800, 0),
              );
              await tester.pumpAndSettle();
            }
            if (textScale == 1.0) {
              for (final (tab, heading) in [
                ('Testy', 'Laboratorium testów'),
                ('Focus', 'Ustaw czas i przejdź do działania.'),
                ('Parking', 'Parking pomysłów'),
              ]) {
                await tester.tap(find.widgetWithText(ChoiceChip, tab));
                await tester.pumpAndSettle();
                expect(find.text(heading), findsOneWidget);
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('business quick add saves a product with only its name', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const Scaffold(
          body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nowy produkt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Termos');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Termos'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product editor stays usable on a narrow phone with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const Scaffold(
          body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nowy produkt'));
    await tester.pumpAndSettle();

    expect(find.text('Nazwa produktu *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop product editor uses a wide dialog and keeps actions visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1366, 768);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.dark),
          home: const Scaffold(
            body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nowy produkt'));
      await tester.pumpAndSettle();

      final editor = tester.getRect(
        find.byKey(const ValueKey('business-product-editor-content')),
      );
      final delivery = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is InputDecorator &&
              widget.decoration.labelText == 'Dostawa (zł)',
        ),
      );
      final other = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is InputDecorator &&
              widget.decoration.labelText == 'Inne (zł)',
        ),
      );
      expect(editor.width, greaterThanOrEqualTo(760));
      expect(other.top - delivery.bottom, greaterThanOrEqualTo(8));
      expect(
        tester.getRect(find.text('Zapisz')).bottom,
        lessThanOrEqualTo(768),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'business tabs do not overlap on a narrow phone with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRemasterTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const Scaffold(
            body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (tab, heading) in [
        ('Testy', 'Laboratorium testów'),
        ('Focus', 'Ustaw czas i przejdź do działania.'),
        ('Parking', 'Parking pomysłów'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(tab),
          240,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('business-tabs')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zakładka $tab');
      }

      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Focus'),
        240,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('business-tabs')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Focus'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Focus'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Własny workflow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Własny workflow'));
      await tester.pumpAndSettle();
      expect(find.text('Nowy workflow'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Formularz workflow');
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Parking'),
        240,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('business-tabs')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Parking'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Parking'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nowy pomysł'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nowy pomysł'));
      await tester.pumpAndSettle();
      expect(find.text('Szybki pomysł'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Formularz pomysłu');
    },
  );

  testWidgets('product cards remain usable at 320 px with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRemasterTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const Scaffold(
          body: BusinessScreen(ownerId: 'local-user', cloudMode: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nowy produkt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Produkt testowy');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Produkty'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('business-tabs')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Produkty'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Produkty'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
