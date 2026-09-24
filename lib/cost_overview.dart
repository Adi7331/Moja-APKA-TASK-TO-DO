import 'cost_item.dart';
import 'local_cost_store.dart';

enum CostForecastMode { allOccurrences, nextOnly }

class UpcomingCostPayment {
  const UpcomingCostPayment({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.dueAt,
    required this.isSubscription,
    this.canMarkPaid = false,
  });

  final String id;
  final String title;
  final int amountCents;
  final DateTime dueAt;
  final bool isSubscription;

  /// Only the subscription's next actual due date can be confirmed as paid.
  final bool canMarkPaid;
}

class CostCategoryOverview {
  const CostCategoryOverview({
    required this.categoryId,
    required this.name,
    required this.paidCents,
    required this.previousPaidCents,
    required this.plannedCents,
  });

  final String? categoryId;
  final String name;
  final int paidCents;
  final int previousPaidCents;
  final int plannedCents;

  int get differenceCents => paidCents - previousPaidCents;
}

class CostOverview {
  const CostOverview({
    required this.paidExpensesCents,
    required this.plannedPaymentsCents,
    required this.monthlySubscriptionsCents,
    required this.annualSubscriptionsCents,
    required this.receivedIncomeCents,
    required this.plannedIncomeCents,
    required this.hasIncome,
    required this.periodPaidExpensesCents,
    required this.previousPeriodPaidExpensesCents,
    required this.categoryBreakdown,
    required this.nextPayment,
    required this.upcomingPayments,
  });

  final int paidExpensesCents;
  final int plannedPaymentsCents;
  final int monthlySubscriptionsCents;
  final int annualSubscriptionsCents;
  final int receivedIncomeCents;
  final int plannedIncomeCents;
  final bool hasIncome;
  final int periodPaidExpensesCents;
  final int previousPeriodPaidExpensesCents;
  final List<CostCategoryOverview> categoryBreakdown;
  final UpcomingCostPayment? nextPayment;
  final List<UpcomingCostPayment> upcomingPayments;

  int get periodDifferenceCents =>
      periodPaidExpensesCents - previousPeriodPaidExpensesCents;

  /// Kept as a nullable compatibility getter for earlier dashboard callers.
  int? get incomeCents => hasIncome ? receivedIncomeCents : null;

  factory CostOverview.build({
    required CostSnapshot snapshot,
    required DateTime month,
    required DateTime now,
    CostForecastMode forecastMode = CostForecastMode.allOccurrences,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonthStart = DateTime(month.year, month.month + 1);
    final today = DateTime(now.year, now.month, now.day);
    final currentPeriodEnd = DateTime(now.year, now.month, now.day + 1);
    final safeCurrentPeriodEnd = currentPeriodEnd.isAfter(nextMonthStart)
        ? nextMonthStart
        : currentPeriodEnd;
    final previousMonthStart = DateTime(month.year, month.month - 1);
    final previousMonthEnd = DateTime(month.year, month.month);
    final elapsedDays = safeCurrentPeriodEnd.difference(monthStart).inDays;
    final previousMonthLength = previousMonthEnd
        .difference(previousMonthStart)
        .inDays;
    final previousPeriodEnd = previousMonthStart.add(
      Duration(days: elapsedDays.clamp(0, previousMonthLength)),
    );

    final paidExpenseEntries = snapshot.entries.where(
      (entry) =>
          entry.type == CostEntryType.expense &&
          entry.status == CostEntryStatus.paid &&
          _isInPeriod(entry.occurredAt, monthStart, nextMonthStart),
    );
    final paidExpenses = paidExpenseEntries.fold<int>(
      0,
      (total, entry) => total + entry.amountCents,
    );
    final paidInCurrentPeriod = snapshot.entries.where(
      (entry) =>
          entry.type == CostEntryType.expense &&
          entry.status == CostEntryStatus.paid &&
          _isInPeriod(entry.occurredAt, monthStart, safeCurrentPeriodEnd),
    );
    final paidInPreviousPeriod = snapshot.entries.where(
      (entry) =>
          entry.type == CostEntryType.expense &&
          entry.status == CostEntryStatus.paid &&
          _isInPeriod(entry.occurredAt, previousMonthStart, previousPeriodEnd),
    );

    final plannedEntries = snapshot.entries.where(
      (entry) =>
          entry.type == CostEntryType.expense &&
          entry.status == CostEntryStatus.planned &&
          _isInPeriod(entry.occurredAt, monthStart, nextMonthStart),
    );
    final activeSubscriptions = snapshot.subscriptions
        .where((subscription) => subscription.active)
        .toList();
    final plannedSubscriptionPayments = [
      for (final subscription in activeSubscriptions)
        ..._subscriptionPaymentsInRange(
          subscription,
          monthStart,
          nextMonthStart,
        ),
    ];

    final incomeEntries = snapshot.entries.where(
      (entry) =>
          entry.type == CostEntryType.income &&
          _isInPeriod(entry.occurredAt, monthStart, nextMonthStart),
    );
    final receivedIncome = incomeEntries.where(
      (entry) => entry.status == CostEntryStatus.paid,
    );
    final plannedIncome = incomeEntries.where(
      (entry) => entry.status == CostEntryStatus.planned,
    );

    final periodPaidTotal = paidInCurrentPeriod.fold<int>(
      0,
      (total, entry) => total + entry.amountCents,
    );
    final previousPeriodPaidTotal = paidInPreviousPeriod.fold<int>(
      0,
      (total, entry) => total + entry.amountCents,
    );

    final categoryById = {
      for (final category in snapshot.categories) category.id: category,
    };
    final categoryTotals = <String?, _MutableCategoryOverview>{};
    void addCategoryAmount(
      String? categoryId,
      int amount, {
      required bool previous,
      required bool planned,
    }) {
      final normalizedId =
          categoryId != null && categoryById.containsKey(categoryId)
          ? categoryId
          : null;
      final categoryName = normalizedId == null
          ? 'Bez kategorii'
          : categoryById[normalizedId]!.name;
      final total = categoryTotals.putIfAbsent(
        normalizedId,
        () => _MutableCategoryOverview(name: categoryName),
      );
      if (previous) {
        total.previousPaid += amount;
      } else if (planned) {
        total.planned += amount;
      } else {
        total.paid += amount;
      }
    }

    for (final entry in paidInCurrentPeriod) {
      addCategoryAmount(
        entry.categoryId,
        entry.amountCents,
        previous: false,
        planned: false,
      );
    }
    for (final entry in paidInPreviousPeriod) {
      addCategoryAmount(
        entry.categoryId,
        entry.amountCents,
        previous: true,
        planned: false,
      );
    }
    for (final entry in plannedEntries) {
      addCategoryAmount(
        entry.categoryId,
        entry.amountCents,
        previous: false,
        planned: true,
      );
    }
    for (final payment in plannedSubscriptionPayments) {
      final subscription = activeSubscriptions.firstWhere(
        (item) => item.id == payment.id,
      );
      addCategoryAmount(
        subscription.categoryId,
        payment.amountCents,
        previous: false,
        planned: true,
      );
    }
    final categoryBreakdown =
        categoryTotals.entries
            .map(
              (entry) => CostCategoryOverview(
                categoryId: entry.key,
                name: entry.value.name,
                paidCents: entry.value.paid,
                previousPaidCents: entry.value.previousPaid,
                plannedCents: entry.value.planned,
              ),
            )
            .where(
              (item) =>
                  item.paidCents != 0 ||
                  item.previousPaidCents != 0 ||
                  item.plannedCents != 0,
            )
            .toList()
          ..sort((a, b) {
            final byPaid = b.paidCents.compareTo(a.paidCents);
            if (byPaid != 0) return byPaid;
            final byPlanned = b.plannedCents.compareTo(a.plannedCents);
            return byPlanned != 0 ? byPlanned : a.name.compareTo(b.name);
          });

    final horizon = today.add(const Duration(days: 90));
    final upcoming =
        <UpcomingCostPayment>[
          for (final entry in snapshot.entries)
            if (entry.type == CostEntryType.expense &&
                entry.status == CostEntryStatus.planned &&
                !entry.occurredAt.isBefore(today) &&
                entry.occurredAt.isBefore(horizon))
              UpcomingCostPayment(
                id: entry.id,
                title: entry.title,
                amountCents: entry.amountCents,
                dueAt: entry.occurredAt,
                isSubscription: false,
                canMarkPaid: true,
              ),
          for (final subscription in activeSubscriptions)
            ..._forecastSubscriptionPayments(
              subscription,
              today,
              horizon,
              forecastMode,
            ),
        ]..sort((a, b) {
          final byDate = a.dueAt.compareTo(b.dueAt);
          if (byDate != 0) return byDate;
          return a.title.compareTo(b.title);
        });

    final nextCandidates = <UpcomingCostPayment>[
      for (final entry in snapshot.entries)
        if (entry.type == CostEntryType.expense &&
            entry.status == CostEntryStatus.planned)
          UpcomingCostPayment(
            id: entry.id,
            title: entry.title,
            amountCents: entry.amountCents,
            dueAt: entry.occurredAt,
            isSubscription: false,
            canMarkPaid: true,
          ),
      for (final subscription in activeSubscriptions)
        UpcomingCostPayment(
          id: subscription.id,
          title: subscription.name,
          amountCents: subscription.amountCents,
          dueAt: subscription.nextPaymentAt,
          isSubscription: true,
          canMarkPaid: true,
        ),
    ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    final monthlySubscriptions = activeSubscriptions.fold<int>(
      0,
      (total, subscription) => total + subscription.monthlyEquivalentCents,
    );

    return CostOverview(
      paidExpensesCents: paidExpenses,
      plannedPaymentsCents:
          plannedEntries.fold<int>(
            0,
            (total, entry) => total + entry.amountCents,
          ) +
          plannedSubscriptionPayments.fold<int>(
            0,
            (total, payment) => total + payment.amountCents,
          ),
      monthlySubscriptionsCents: monthlySubscriptions,
      annualSubscriptionsCents: monthlySubscriptions * 12,
      receivedIncomeCents: receivedIncome.fold<int>(
        0,
        (total, entry) => total + entry.amountCents,
      ),
      plannedIncomeCents: plannedIncome.fold<int>(
        0,
        (total, entry) => total + entry.amountCents,
      ),
      hasIncome: incomeEntries.isNotEmpty,
      periodPaidExpensesCents: periodPaidTotal,
      previousPeriodPaidExpensesCents: previousPeriodPaidTotal,
      categoryBreakdown: List.unmodifiable(categoryBreakdown),
      nextPayment: nextCandidates.firstOrNull,
      upcomingPayments: List.unmodifiable(upcoming),
    );
  }
}

class _MutableCategoryOverview {
  _MutableCategoryOverview({required this.name});

  final String name;
  int paid = 0;
  int previousPaid = 0;
  int planned = 0;
}

List<UpcomingCostPayment> _forecastSubscriptionPayments(
  CostSubscription subscription,
  DateTime start,
  DateTime end,
  CostForecastMode mode,
) {
  final payments = <UpcomingCostPayment>[];
  var dueAt = subscription.nextPaymentAt;
  var guard = 0;
  while (dueAt.isBefore(start) && guard < 10000) {
    final next = nextBillingDate(dueAt, subscription.cycle);
    if (!next.isAfter(dueAt)) break;
    dueAt = next;
    guard++;
  }

  while (!dueAt.isBefore(start) && dueAt.isBefore(end) && guard < 10000) {
    payments.add(
      UpcomingCostPayment(
        id: subscription.id,
        title: subscription.name,
        amountCents: subscription.amountCents,
        dueAt: dueAt,
        isSubscription: true,
        canMarkPaid: dueAt.isAtSameMomentAs(subscription.nextPaymentAt),
      ),
    );
    if (mode == CostForecastMode.nextOnly) break;
    final next = nextBillingDate(dueAt, subscription.cycle);
    if (!next.isAfter(dueAt)) break;
    dueAt = next;
    guard++;
  }
  return payments;
}

List<UpcomingCostPayment> _subscriptionPaymentsInRange(
  CostSubscription subscription,
  DateTime start,
  DateTime end,
) => _forecastSubscriptionPayments(
  subscription,
  start,
  end,
  CostForecastMode.allOccurrences,
);

bool _isInPeriod(DateTime value, DateTime start, DateTime end) =>
    !value.isBefore(start) && value.isBefore(end);
