import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/cost_item.dart';
import 'package:dzien_po_dniu/local_cost_store.dart';

void main() {
  test('a clean or older install loads empty cost collections', () async {
    SharedPreferences.setMockInitialValues({'local_tasks_v1': '[]'});
    final store = LocalCostStore(await SharedPreferences.getInstance());

    final snapshot = await store.load();

    expect(snapshot.entries, isEmpty);
    expect(snapshot.subscriptions, isEmpty);
    expect(snapshot.categories, isEmpty);
  });

  test('persists expenses, subscriptions and categories together', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = LocalCostStore(preferences);
    final snapshot = CostSnapshot(
      entries: [
        CostEntry(
          id: 'expense-1',
          title: 'Rachunek za internet',
          amountCents: 7900,
          type: CostEntryType.expense,
          status: CostEntryStatus.planned,
          occurredAt: DateTime(2026, 10, 5),
        ),
      ],
      subscriptions: [
        CostSubscription(
          id: 'subscription-1',
          name: 'Muzyka',
          amountCents: 2399,
          cycle: BillingCycle.monthly,
          nextPaymentAt: DateTime(2026, 10, 3),
        ),
      ],
      categories: [const CostCategory(id: 'home', name: 'Dom')],
    );

    await store.save(snapshot);
    final restored = await LocalCostStore(preferences).load();

    expect(restored.entries.single.amountCents, 7900);
    expect(restored.subscriptions.single.name, 'Muzyka');
    expect(restored.categories.single.name, 'Dom');
  });

  test('keeps local financial data isolated per account', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = LocalCostStore(preferences, ownerId: 'account-a');
    await first.save(
      CostSnapshot(
        entries: [
          CostEntry(
            id: 'private-entry',
            title: 'Prywatny wydatek',
            amountCents: 1500,
            type: CostEntryType.expense,
            status: CostEntryStatus.paid,
            occurredAt: DateTime(2026, 9, 24),
          ),
        ],
      ),
    );

    expect(
      (await LocalCostStore(preferences, ownerId: 'account-b').load()).entries,
      isEmpty,
    );
    expect((await first.load()).entries.single.title, 'Prywatny wydatek');
  });
}
