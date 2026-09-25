import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cost_item.dart';
import 'cost_overview.dart';
import 'local_cost_store.dart';

/// The accepted A+B layout: nearest payment first, followed by useful month
/// totals and a compact, expandable 90-day forecast.
class CostDashboard extends StatelessWidget {
  const CostDashboard({
    super.key,
    required this.snapshot,
    this.forecastMode = CostForecastMode.allOccurrences,
    this.onForecastModeChanged,
    this.onAdd,
    this.onMarkPaid,
    this.onOpenSubscription,
  });

  final CostSnapshot snapshot;
  final CostForecastMode forecastMode;
  final ValueChanged<CostForecastMode>? onForecastModeChanged;
  final VoidCallback? onAdd;
  final ValueChanged<UpcomingCostPayment>? onMarkPaid;
  final ValueChanged<CostSubscription>? onOpenSubscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final overview = CostOverview.build(
      snapshot: snapshot,
      month: now,
      now: now,
      forecastMode: forecastMode,
    );
    final formatter = NumberFormat.currency(locale: 'pl_PL', symbol: 'zł');
    String money(int cents) => formatter.format(cents / 100);
    final next = overview.nextPayment;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
        final paymentsByMonth = _groupPayments(overview.upcomingPayments);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 24, wide ? 32 : 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TWOJE FINANSE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                letterSpacing: 1.4,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Koszty',
                              style: theme.textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMM('pl_PL').format(now),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onAdd != null)
                        FilledButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Dodaj'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _NextPaymentCard(
                    title: next?.title,
                    dueLabel: next == null
                        ? null
                        : _relativeDate(next.dueAt, now),
                    amount: next == null ? null : money(next.amountCents),
                    isSubscription: next?.isSubscription ?? false,
                    onMarkPaid:
                        next == null || !next.canMarkPaid || onMarkPaid == null
                        ? null
                        : () => onMarkPaid!(next),
                    onAdd: onAdd,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Podsumowanie miesiąca',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _SummaryGrid(
                    wide: wide,
                    tight: constraints.maxWidth < 480,
                    largeText: largeText,
                    cards: [
                      _SummaryData(
                        icon: Icons.calendar_month_rounded,
                        label: 'Planowane płatności',
                        value: money(overview.plannedPaymentsCents),
                        detail: 'do końca miesiąca',
                        accent: scheme.primaryContainer,
                      ),
                      _SummaryData(
                        icon: Icons.receipt_long_rounded,
                        label: 'Opłacone wydatki',
                        value: money(overview.paidExpensesCents),
                        detail: 'w tym miesiącu',
                        accent: scheme.surfaceContainerHigh,
                      ),
                      _SummaryData(
                        icon: Icons.autorenew_rounded,
                        label: 'Subskrypcje / mies.',
                        value: money(overview.monthlySubscriptionsCents),
                        detail:
                            'Rocznie: ${money(overview.annualSubscriptionsCents)}',
                        accent: scheme.tertiaryContainer,
                      ),
                      if (overview.hasIncome) ...[
                        _SummaryData(
                          icon: Icons.south_west_rounded,
                          label: 'Otrzymane wpływy',
                          value: money(overview.receivedIncomeCents),
                          detail: 'już otrzymane w tym miesiącu',
                          accent: scheme.secondaryContainer,
                        ),
                        _SummaryData(
                          icon: Icons.event_available_rounded,
                          label: 'Oczekiwane wpływy',
                          value: money(overview.plannedIncomeCents),
                          detail: 'zaplanowane na ten miesiąc',
                          accent: scheme.surfaceContainerHigh,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Wydatki według kategorii',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _CategoryBreakdown(overview: overview, money: money),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prognoza płatności',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '90 dni · ${forecastMode == CostForecastMode.allOccurrences ? 'wszystkie wystąpienia' : 'tylko najbliższy termin'}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onForecastModeChanged != null)
                        PopupMenuButton<CostForecastMode>(
                          tooltip: 'Sposób prognozy',
                          initialValue: forecastMode,
                          onSelected: onForecastModeChanged,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: CostForecastMode.allOccurrences,
                              child: _ForecastModeLabel(
                                label: 'Wszystkie wystąpienia',
                                selected:
                                    forecastMode ==
                                    CostForecastMode.allOccurrences,
                              ),
                            ),
                            PopupMenuItem(
                              value: CostForecastMode.nextOnly,
                              child: _ForecastModeLabel(
                                label: 'Tylko najbliższy termin',
                                selected:
                                    forecastMode == CostForecastMode.nextOnly,
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.tune_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (paymentsByMonth.isEmpty)
                    _EmptyPayments(onAdd: onAdd, nextPayment: next, now: now)
                  else
                    _ForecastTimeline(
                      paymentsByMonth: paymentsByMonth,
                      now: now,
                      money: money,
                      subscriptions: snapshot.subscriptions,
                      onMarkPaid: onMarkPaid,
                      onOpenSubscription: onOpenSubscription,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({
    required this.title,
    required this.dueLabel,
    required this.amount,
    required this.isSubscription,
    required this.onMarkPaid,
    required this.onAdd,
  });

  final String? title, dueLabel, amount;
  final bool isSubscription;
  final VoidCallback? onMarkPaid, onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nextExists = title != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerLow],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'NAJBLIŻEJ',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (nextExists) ...[
            Text(title!, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '$dueLabel${isSubscription ? ' · subskrypcja' : ''}',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 12,
              children: [
                Text(
                  amount!,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (onMarkPaid != null)
                  FilledButton.tonalIcon(
                    onPressed: onMarkPaid,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Oznacz jako opłacone'),
                  ),
              ],
            ),
          ] else ...[
            Text(
              'Na razie nic pilnego',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Dodaj płatność lub subskrypcję, a pokażemy ją tutaj.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (onAdd != null)
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Dodaj pierwszą płatność'),
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String label, value, detail;
  final Color accent;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.wide,
    required this.tight,
    required this.largeText,
    required this.cards,
  });

  final bool wide;
  final bool tight;
  final bool largeText;
  final List<_SummaryData> cards;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: cards.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: largeText ? (wide ? 2 : 1) : (wide ? 4 : 2),
      mainAxisExtent: largeText ? 340 : (tight ? 216 : (wide ? 176 : 184)),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemBuilder: (context, index) {
      final item = cards[index];
      return Card(
        color: item.accent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 20),
              const Spacer(),
              Text(item.value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(item.label, style: Theme.of(context).textTheme.labelLarge),
              Text(
                item.detail,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.overview, required this.money});

  final CostOverview overview;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = overview.periodDifferenceCents;
    final trendIcon = change > 0
        ? Icons.trending_up_rounded
        : change < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final trendLabel = change > 0
        ? 'więcej o ${money(change)} niż poprzednio'
        : change < 0
        ? 'mniej o ${money(-change)} niż poprzednio'
        : 'tyle samo co w poprzednim okresie';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wydano od początku miesiąca',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              money(overview.periodPaidExpensesCents),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(trendIcon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$trendLabel · poprzedni okres ${money(overview.previousPeriodPaidExpensesCents)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (overview.categoryBreakdown.isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Dodaj opłacony albo zaplanowany wydatek, aby zobaczyć kategorie.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const Divider(height: 24),
              for (
                var index = 0;
                index < overview.categoryBreakdown.length;
                index++
              ) ...[
                if (index > 0) const Divider(height: 20),
                _CategoryAmountRow(
                  item: overview.categoryBreakdown[index],
                  money: money,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryAmountRow extends StatelessWidget {
  const _CategoryAmountRow({required this.item, required this.money});

  final CostCategoryOverview item;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      'Poprzednio ${money(item.previousPaidCents)}',
      if (item.plannedCents > 0) 'Planowane ${money(item.plannedCents)}',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: theme.textTheme.titleSmall),
              Text(
                details.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(money(item.paidCents), style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _ForecastModeLabel extends StatelessWidget {
  const _ForecastModeLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 24,
        child: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label, softWrap: true)),
    ],
  );
}

class _ForecastTimeline extends StatelessWidget {
  const _ForecastTimeline({
    required this.paymentsByMonth,
    required this.now,
    required this.money,
    required this.subscriptions,
    required this.onMarkPaid,
    required this.onOpenSubscription,
  });

  final SplayTreeMap<DateTime, List<UpcomingCostPayment>> paymentsByMonth;
  final DateTime now;
  final String Function(int cents) money;
  final List<CostSubscription> subscriptions;
  final ValueChanged<UpcomingCostPayment>? onMarkPaid;
  final ValueChanged<CostSubscription>? onOpenSubscription;

  @override
  Widget build(BuildContext context) {
    final months = paymentsByMonth.keys.toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < months.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _ForecastMonth(
              month: months[index],
              payments: paymentsByMonth[months[index]]!,
              initiallyExpanded: index == 0,
              now: now,
              money: money,
              subscriptions: subscriptions,
              onMarkPaid: onMarkPaid,
              onOpenSubscription: onOpenSubscription,
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastMonth extends StatelessWidget {
  const _ForecastMonth({
    required this.month,
    required this.payments,
    required this.initiallyExpanded,
    required this.now,
    required this.money,
    required this.subscriptions,
    required this.onMarkPaid,
    required this.onOpenSubscription,
  });

  final DateTime month;
  final List<UpcomingCostPayment> payments;
  final bool initiallyExpanded;
  final DateTime now;
  final String Function(int cents) money;
  final List<CostSubscription> subscriptions;
  final ValueChanged<UpcomingCostPayment>? onMarkPaid;
  final ValueChanged<CostSubscription>? onOpenSubscription;

  @override
  Widget build(BuildContext context) {
    final monthTotal = payments.fold<int>(
      0,
      (total, payment) => total + payment.amountCents,
    );
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: const Icon(Icons.calendar_month_rounded),
      title: Text(DateFormat.yMMMM('pl_PL').format(month)),
      subtitle: Text(
        '${payments.length} ${payments.length == 1 ? 'płatność' : 'płatności'} · ${money(monthTotal)}',
      ),
      children: [
        for (var index = 0; index < payments.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 72),
          _UpcomingPaymentRow(
            payment: payments[index],
            now: now,
            amount: money(payments[index].amountCents),
            onMarkPaid: onMarkPaid == null || !payments[index].canMarkPaid
                ? null
                : () => onMarkPaid!(payments[index]),
            onOpenSubscription: onOpenSubscription,
            subscription: payments[index].isSubscription
                ? subscriptions
                      .where((item) => item.id == payments[index].id)
                      .firstOrNull
                : null,
          ),
        ],
      ],
    );
  }
}

SplayTreeMap<DateTime, List<UpcomingCostPayment>> _groupPayments(
  List<UpcomingCostPayment> payments,
) {
  final groups = SplayTreeMap<DateTime, List<UpcomingCostPayment>>(
    (a, b) => a.compareTo(b),
  );
  for (final payment in payments) {
    final month = DateTime(payment.dueAt.year, payment.dueAt.month);
    groups.putIfAbsent(month, () => []).add(payment);
  }
  return groups;
}

class _UpcomingPaymentRow extends StatelessWidget {
  const _UpcomingPaymentRow({
    required this.payment,
    required this.now,
    required this.amount,
    required this.onMarkPaid,
    required this.onOpenSubscription,
    required this.subscription,
  });

  final UpcomingCostPayment payment;
  final DateTime now;
  final String amount;
  final VoidCallback? onMarkPaid;
  final ValueChanged<CostSubscription>? onOpenSubscription;
  final CostSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minLeadingWidth: 40,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(
          payment.isSubscription
              ? Icons.autorenew_rounded
              : Icons.receipt_long_rounded,
        ),
      ),
      title: Text(payment.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_relativeDate(payment.dueAt, now)),
      onTap: subscription != null && onOpenSubscription != null
          ? () => onOpenSubscription!(subscription!)
          : null,
      trailing: SizedBox(
        width: 132,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (onMarkPaid != null)
              IconButton(
                tooltip: 'Oznacz jako opłacone',
                onPressed: onMarkPaid,
                icon: const Icon(Icons.check_circle_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments({
    required this.onAdd,
    required this.nextPayment,
    required this.now,
  });

  final VoidCallback? onAdd;
  final UpcomingCostPayment? nextPayment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = nextPayment == null
        ? 'Brak zaplanowanych płatności.'
        : 'Najbliższa płatność: ${nextPayment!.title} · ${_relativeDate(nextPayment!.dueAt, now)}.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Icon(
              Icons.event_available_outlined,
              color: theme.colorScheme.primary,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Text(
                nextPayment == null
                    ? '$message Dodaj płatność, aby zobaczyć ją tutaj.'
                    : 'Brak płatności w kolejnych 90 dniach. $message',
              ),
            ),
            if (onAdd != null)
              TextButton(onPressed: onAdd, child: const Text('Dodaj')),
          ],
        ),
      ),
    );
  }
}

String _relativeDate(DateTime value, DateTime now) {
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = date.difference(today).inDays;
  if (days < 0) {
    return 'Po terminie · ${DateFormat('d MMM', 'pl_PL').format(value)}';
  }
  if (days == 0) return 'Dzisiaj';
  if (days == 1) return 'Jutro';
  if (days == 2) return 'Pojutrze';
  return DateFormat('d MMM', 'pl_PL').format(value);
}
