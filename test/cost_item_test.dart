import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/cost_item.dart';

void main() {
  group('CostSubscription', () {
    test('normalizes recurring amounts to monthly cents', () {
      expect(
        CostSubscription(
          id: 'annual',
          name: 'Roczna usługa',
          amountCents: 120000,
          cycle: BillingCycle.yearly,
          nextPaymentAt: DateTime(2026, 10, 1),
        ).monthlyEquivalentCents,
        10000,
      );

      expect(
        CostSubscription(
          id: 'quarterly',
          name: 'Usługa kwartalna',
          amountCents: 3000,
          cycle: BillingCycle.quarterly,
          nextPaymentAt: DateTime(2026, 10, 1),
        ).monthlyEquivalentCents,
        1000,
      );
    });

    test('monthly recurrence stays on the last day in short months', () {
      expect(
        nextBillingDate(DateTime(2026, 1, 31), BillingCycle.monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        nextBillingDate(DateTime(2026, 3, 31), BillingCycle.monthly),
        DateTime(2026, 4, 30),
      );
    });

    test('yearly recurrence clamps leap day to the final day of February', () {
      expect(
        nextBillingDate(DateTime(2024, 2, 29), BillingCycle.yearly),
        DateTime(2025, 2, 28),
      );
    });

    test('weekly recurrence preserves the local date and time across DST', () {
      expect(
        nextBillingDate(DateTime(2026, 10, 23, 9), BillingCycle.weekly),
        DateTime(2026, 10, 30, 9),
      );
    });

    test('round-trips optional reminder preferences and category id', () {
      final original = CostSubscription(
        id: 'subscription-1',
        name: 'Muzyka',
        amountCents: 2399,
        cycle: BillingCycle.monthly,
        nextPaymentAt: DateTime(2026, 10, 3),
        categoryId: 'media',
        reminderDays: const [3, 1],
      );

      expect(CostSubscription.fromStorage(original.toStorage()), original);
    });
  });
}
