import 'package:dzien_po_dniu/cost_dashboard.dart';
import 'package:dzien_po_dniu/cost_item.dart';
import 'package:dzien_po_dniu/cost_overview.dart';
import 'package:dzien_po_dniu/local_cost_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  await initializeDateFormatting('pl_PL');
  testWidgets('dashboard presents forecast, month summary and categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostDashboard(snapshot: const CostSnapshot(), onAdd: () {}),
        ),
      ),
    );

    expect(find.text('Koszty'), findsOneWidget);
    expect(find.text('Prognoza płatności'), findsOneWidget);
    expect(find.textContaining('90 dni'), findsOneWidget);
    expect(find.text('Podsumowanie miesiąca'), findsOneWidget);
    expect(find.text('Wydatki według kategorii'), findsOneWidget);
    expect(find.text('Dodaj pierwszą płatność'), findsOneWidget);
  });

  testWidgets('dashboard distinguishes received and expected income', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostDashboard(
            snapshot: CostSnapshot(
              entries: [
                CostEntry(
                  id: 'received',
                  title: 'Pensja',
                  amountCents: 500000,
                  type: CostEntryType.income,
                  status: CostEntryStatus.paid,
                  occurredAt: DateTime.now(),
                ),
                CostEntry(
                  id: 'expected',
                  title: 'Premia',
                  amountCents: 10000,
                  type: CostEntryType.income,
                  status: CostEntryStatus.planned,
                  occurredAt: DateTime.now(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Otrzymane wpływy'), findsOneWidget);
    expect(find.text('Oczekiwane wpływy'), findsOneWidget);
  });

  testWidgets('nearest card labels an unpaid past-due subscription', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostDashboard(
            snapshot: CostSnapshot(
              subscriptions: [
                CostSubscription(
                  id: 'overdue',
                  name: 'Rachunek za internet',
                  amountCents: 7000,
                  cycle: BillingCycle.monthly,
                  nextPaymentAt: DateTime.now().subtract(
                    const Duration(days: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Po terminie'), findsOneWidget);
  });

  testWidgets('forecast menu exposes both subscription recurrence modes', (
    tester,
  ) async {
    CostForecastMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostDashboard(
            snapshot: const CostSnapshot(),
            onForecastModeChanged: (mode) => selected = mode,
          ),
        ),
      ),
    );

    final forecastMenu = find.byTooltip('Sposób prognozy');
    await tester.ensureVisible(forecastMenu);
    await tester.tap(forecastMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tylko najbliższy termin'));

    expect(selected, CostForecastMode.nextOnly);
  });

  testWidgets('A+B dashboard has no overflow on phone, tablet or desktop', (
    tester,
  ) async {
    final sizes = [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1366, 768),
    ];
    addTearDown(() => tester.view.resetPhysicalSize());
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CostDashboard(snapshot: const CostSnapshot(), onAdd: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
  });

  testWidgets('A+B dashboard remains readable at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: CostDashboard(snapshot: const CostSnapshot(), onAdd: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category rows remain readable with data at 200 percent text scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: CostDashboard(
                snapshot: CostSnapshot(
                  categories: const [
                    CostCategory(id: 'home', name: 'Dom i rachunki'),
                  ],
                  entries: [
                    CostEntry(
                      id: 'paid',
                      title: 'Prąd',
                      amountCents: 42000,
                      type: CostEntryType.expense,
                      status: CostEntryStatus.paid,
                      occurredAt: DateTime.now(),
                      categoryId: 'home',
                    ),
                    CostEntry(
                      id: 'planned',
                      title: 'Woda',
                      amountCents: 10000,
                      type: CostEntryType.expense,
                      status: CostEntryStatus.planned,
                      occurredAt: DateTime.now(),
                      categoryId: 'home',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dom i rachunki'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
