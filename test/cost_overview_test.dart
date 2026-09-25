import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/cost_item.dart';
import 'package:dzien_po_dniu/cost_overview.dart';
import 'package:dzien_po_dniu/local_cost_store.dart';

void main() {
  test(
    'separates paid expenses, planned payments and monthly subscriptions',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24, 12),
        snapshot: CostSnapshot(
          entries: [
            CostEntry(
              id: 'paid',
              title: 'Zakupy',
              amountCents: 18640,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 9, 4),
            ),
            CostEntry(
              id: 'planned',
              title: 'Rachunek',
              amountCents: 7900,
              type: CostEntryType.expense,
              status: CostEntryStatus.planned,
              occurredAt: DateTime(2026, 9, 28),
            ),
            CostEntry(
              id: 'income',
              title: 'Wynagrodzenie',
              amountCents: 500000,
              type: CostEntryType.income,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 9, 10),
            ),
          ],
          subscriptions: [
            CostSubscription(
              id: 'monthly',
              name: 'Netflix',
              amountCents: 4999,
              cycle: BillingCycle.monthly,
              nextPaymentAt: DateTime(2026, 9, 27),
            ),
            CostSubscription(
              id: 'annual',
              name: 'Roczna usługa',
              amountCents: 120000,
              cycle: BillingCycle.yearly,
              nextPaymentAt: DateTime(2027, 1, 1),
            ),
          ],
        ),
      );

      expect(overview.paidExpensesCents, 18640);
      expect(overview.plannedPaymentsCents, 12899);
      expect(overview.monthlySubscriptionsCents, 14999);
      expect(overview.annualSubscriptionsCents, 179988);
      expect(overview.incomeCents, 500000);
      expect(overview.nextPayment?.title, 'Netflix');
    },
  );

  test('does not present an empty income total as zero', () {
    final overview = CostOverview.build(
      month: DateTime(2026, 9),
      now: DateTime(2026, 9, 24),
      snapshot: const CostSnapshot(),
    );

    expect(overview.incomeCents, isNull);
    expect(overview.hasIncome, isFalse);
  });

  test(
    'only shows active subscriptions in monthly total and planned amount',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24),
        snapshot: CostSnapshot(
          subscriptions: [
            CostSubscription(
              id: 'active',
              name: 'Aktywna',
              amountCents: 3000,
              cycle: BillingCycle.quarterly,
              nextPaymentAt: DateTime(2026, 9, 25),
            ),
            CostSubscription(
              id: 'inactive',
              name: 'Zakończona',
              amountCents: 9000,
              cycle: BillingCycle.monthly,
              nextPaymentAt: DateTime(2026, 9, 25),
              active: false,
            ),
          ],
        ),
      );

      expect(overview.monthlySubscriptionsCents, 1000);
      expect(overview.plannedPaymentsCents, 3000);
      expect(overview.upcomingPayments, hasLength(1));
    },
  );

  test(
    'forecasts each recurring subscription payment across the next 90 days',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24, 12),
        snapshot: CostSnapshot(
          entries: [
            CostEntry(
              id: 'planned-later',
              title: 'Ubezpieczenie',
              amountCents: 12000,
              type: CostEntryType.expense,
              status: CostEntryStatus.planned,
              occurredAt: DateTime(2026, 12, 22),
            ),
          ],
          subscriptions: [
            CostSubscription(
              id: 'weekly',
              name: 'Karnet',
              amountCents: 5000,
              cycle: BillingCycle.weekly,
              nextPaymentAt: DateTime(2026, 9, 25),
            ),
          ],
        ),
      );

      final weeklyPayments = overview.upcomingPayments
          .where((payment) => payment.id == 'weekly')
          .toList();
      expect(weeklyPayments, hasLength(13));
      expect(
        DateTime(
          weeklyPayments.first.dueAt.year,
          weeklyPayments.first.dueAt.month,
          weeklyPayments.first.dueAt.day,
        ),
        DateTime(2026, 9, 25),
      );
      expect(
        DateTime(
          weeklyPayments.last.dueAt.year,
          weeklyPayments.last.dueAt.month,
          weeklyPayments.last.dueAt.day,
        ),
        DateTime(2026, 12, 18),
      );
      expect(overview.upcomingPayments.last.title, 'Ubezpieczenie');
    },
  );

  test(
    'keeps the nearest payment visible when it is more than 30 days away',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24),
        snapshot: CostSnapshot(
          subscriptions: [
            CostSubscription(
              id: 'annual',
              name: 'Ubezpieczenie roczne',
              amountCents: 120000,
              cycle: BillingCycle.yearly,
              nextPaymentAt: DateTime(2026, 11, 8),
            ),
          ],
        ),
      );

      expect(overview.upcomingPayments, hasLength(1));
      expect(overview.nextPayment?.title, 'Ubezpieczenie roczne');
    },
  );

  test(
    'shows a planned one-off payment past its due date in the nearest card',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24),
        snapshot: CostSnapshot(
          entries: [
            CostEntry(
              id: 'overdue',
              title: 'Zaległy rachunek',
              amountCents: 15000,
              type: CostEntryType.expense,
              status: CostEntryStatus.planned,
              occurredAt: DateTime(2026, 9, 3),
            ),
          ],
        ),
      );

      expect(overview.nextPayment?.title, 'Zaległy rachunek');
      expect(overview.nextPayment?.canMarkPaid, isTrue);
    },
  );

  test(
    'keeps an overdue subscription payment visible for manual confirmation',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24),
        snapshot: CostSnapshot(
          subscriptions: [
            CostSubscription(
              id: 'weekly',
              name: 'Karnet',
              amountCents: 5000,
              cycle: BillingCycle.weekly,
              nextPaymentAt: DateTime(2026, 9, 3),
            ),
          ],
        ),
      );

      expect(overview.nextPayment?.title, 'Karnet');
      expect(overview.nextPayment?.dueAt, DateTime(2026, 9, 3));
      expect(overview.nextPayment?.canMarkPaid, isTrue);
    },
  );

  test(
    'next-only forecast includes only the next occurrence per subscription',
    () {
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24),
        forecastMode: CostForecastMode.nextOnly,
        snapshot: CostSnapshot(
          subscriptions: [
            CostSubscription(
              id: 'weekly',
              name: 'Karnet',
              amountCents: 5000,
              cycle: BillingCycle.weekly,
              nextPaymentAt: DateTime(2026, 9, 25),
            ),
          ],
        ),
      );

      expect(overview.upcomingPayments, hasLength(1));
      expect(overview.upcomingPayments.single.dueAt, DateTime(2026, 9, 25));
    },
  );

  test('separates received and planned income for the selected month', () {
    final overview = CostOverview.build(
      month: DateTime(2026, 9),
      now: DateTime(2026, 9, 24),
      snapshot: CostSnapshot(
        entries: [
          CostEntry(
            id: 'received',
            title: 'Wypłata',
            amountCents: 400000,
            type: CostEntryType.income,
            status: CostEntryStatus.paid,
            occurredAt: DateTime(2026, 9, 10),
          ),
          CostEntry(
            id: 'expected',
            title: 'Premia',
            amountCents: 25000,
            type: CostEntryType.income,
            status: CostEntryStatus.planned,
            occurredAt: DateTime(2026, 9, 30),
          ),
        ],
      ),
    );

    expect(overview.receivedIncomeCents, 400000);
    expect(overview.plannedIncomeCents, 25000);
    expect(overview.upcomingPayments, isEmpty);
  });

  test(
    'compares paid categories against the same elapsed period last month',
    () {
      const home = CostCategory(id: 'home', name: 'Dom');
      const food = CostCategory(id: 'food', name: 'Jedzenie');
      final overview = CostOverview.build(
        month: DateTime(2026, 9),
        now: DateTime(2026, 9, 24, 18),
        snapshot: CostSnapshot(
          categories: [home, food],
          entries: [
            CostEntry(
              id: 'home-now',
              title: 'Rachunek',
              amountCents: 42000,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 9, 3),
              categoryId: 'home',
            ),
            CostEntry(
              id: 'food-now',
              title: 'Zakupy',
              amountCents: 68000,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 9, 24, 16),
              categoryId: 'food',
            ),
            CostEntry(
              id: 'home-planned',
              title: 'Prąd',
              amountCents: 5000,
              type: CostEntryType.expense,
              status: CostEntryStatus.planned,
              occurredAt: DateTime(2026, 9, 30),
              categoryId: 'home',
            ),
            CostEntry(
              id: 'home-before',
              title: 'Rachunek',
              amountCents: 40000,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 8, 3),
              categoryId: 'home',
            ),
            CostEntry(
              id: 'food-before',
              title: 'Zakupy',
              amountCents: 90000,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 8, 20),
              categoryId: 'food',
            ),
            CostEntry(
              id: 'outside-equivalent-window',
              title: 'Nie w tym okresie',
              amountCents: 990000,
              type: CostEntryType.expense,
              status: CostEntryStatus.paid,
              occurredAt: DateTime(2026, 8, 31),
            ),
          ],
        ),
      );

      final categories = {
        for (final item in overview.categoryBreakdown) item.categoryId: item,
      };
      expect(overview.periodPaidExpensesCents, 110000);
      expect(overview.previousPeriodPaidExpensesCents, 130000);
      expect(overview.periodDifferenceCents, -20000);
      expect(categories['home']?.paidCents, 42000);
      expect(categories['home']?.plannedCents, 5000);
      expect(categories['home']?.previousPaidCents, 40000);
      expect(categories['food']?.paidCents, 68000);
      expect(categories.containsKey(null), isFalse);
    },
  );

  test('clamps the matching comparison period to a shorter previous month', () {
    final overview = CostOverview.build(
      month: DateTime(2026, 3),
      now: DateTime(2026, 3, 31, 21),
      snapshot: CostSnapshot(
        entries: [
          CostEntry(
            id: 'march',
            title: 'Zakupy',
            amountCents: 10000,
            type: CostEntryType.expense,
            status: CostEntryStatus.paid,
            occurredAt: DateTime(2026, 3, 31),
          ),
          CostEntry(
            id: 'february-last-day',
            title: 'Zakupy',
            amountCents: 20000,
            type: CostEntryType.expense,
            status: CostEntryStatus.paid,
            occurredAt: DateTime(2026, 2, 28),
          ),
        ],
      ),
    );

    expect(overview.periodPaidExpensesCents, 10000);
    expect(overview.previousPeriodPaidExpensesCents, 20000);
  });
}
