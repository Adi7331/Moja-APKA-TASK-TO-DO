import 'package:dzien_po_dniu/cost_item.dart';
import 'package:dzien_po_dniu/local_cost_store.dart';
import 'package:dzien_po_dniu/main.dart';
import 'package:dzien_po_dniu/start_cost_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Start shows saved upcoming costs without visiting Costs first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'ui_remaster_v2': true});
    final store = LocalCostStore(
      await SharedPreferences.getInstance(),
      ownerId: 'local-user',
    );
    await store.save(
      CostSnapshot(
        subscriptions: [
          CostSubscription(
            id: 'subscription-1',
            name: 'Spotify Premium',
            amountCents: 2999,
            cycle: BillingCycle.monthly,
            nextPaymentAt: DateTime.now().add(const Duration(days: 4)),
          ),
        ],
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    expect(find.text('Najbliższa płatność'), findsOneWidget);
    expect(find.text('Spotify Premium'), findsWidgets);
    expect(find.textContaining('29,99'), findsWidgets);

    await tester.ensureVisible(find.text('Najbliższa płatność'));
    await tester.tap(find.text('Najbliższa płatność'));
    await tester.pumpAndSettle();
    expect(find.text('Przegląd'), findsWidgets);
  });

  testWidgets('Start still shows a payment beyond the 90-day forecast', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'ui_remaster_v2': true});
    final store = LocalCostStore(
      await SharedPreferences.getInstance(),
      ownerId: 'local-user',
    );
    await store.save(
      CostSnapshot(
        subscriptions: [
          CostSubscription(
            id: 'yearly',
            name: 'Roczny abonament',
            amountCents: 12000,
            cycle: BillingCycle.yearly,
            nextPaymentAt: DateTime.now().add(const Duration(days: 120)),
          ),
        ],
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    expect(find.text('Najbliższa płatność'), findsOneWidget);
    expect(find.text('Roczny abonament'), findsWidgets);
  });

  testWidgets('Start offers a useful empty payment state', (tester) async {
    SharedPreferences.setMockInitialValues({'ui_remaster_v2': true});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tryb lokalny'));
    await tester.pumpAndSettle();

    expect(find.text('Brak zaplanowanych płatności'), findsOneWidget);
    expect(find.text('Dodaj pierwszą płatność'), findsOneWidget);
  });

  testWidgets('payment card fits a narrow phone with enlarged text', (
    tester,
  ) async {
    await initializeDateFormatting('pl_PL');
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = CostSnapshot(
      subscriptions: [
        CostSubscription(
          id: 'long',
          name: 'Bardzo długa nazwa subskrypcji do sprawdzenia',
          amountCents: 2999,
          cycle: BillingCycle.monthly,
          nextPaymentAt: DateTime(2026, 9, 28),
        ),
        CostSubscription(
          id: 'second',
          name: 'Druga subskrypcja',
          amountCents: 4300,
          cycle: BillingCycle.monthly,
          nextPaymentAt: DateTime(2026, 10, 3),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: SingleChildScrollView(
              child: StartCostCard(
                snapshot: snapshot,
                now: DateTime(2026, 9, 24),
                onOpenCosts: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Najbliższa płatność'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
