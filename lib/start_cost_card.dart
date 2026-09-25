import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cost_item.dart';
import 'cost_overview.dart';
import 'local_cost_store.dart';

/// A glanceable payment timeline for Start. No financial records are created
/// here; it only reads the same snapshot as the Costs workspace.
class StartCostCard extends StatelessWidget {
  const StartCostCard({
    super.key,
    required this.snapshot,
    required this.onOpenCosts,
    this.now,
  });

  final CostSnapshot snapshot;
  final VoidCallback onOpenCosts;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    final overview = CostOverview.build(
      snapshot: snapshot,
      month: current,
      now: current,
      forecastMode: CostForecastMode.nextOnly,
    );
    final next = overview.nextPayment;
    final timeline = <UpcomingCostPayment>[
      ?next,
      ...overview.upcomingPayments.where(
        (payment) =>
            next == null ||
            payment.id != next.id ||
            payment.dueAt != next.dueAt,
      ),
    ].take(3).toList();
    final paidThisMonth = snapshot.entries
        .where(
          (entry) =>
              entry.type == CostEntryType.expense &&
              entry.status == CostEntryStatus.paid &&
              entry.subscriptionId != null &&
              entry.occurredAt.year == current.year &&
              entry.occurredAt.month == current.month,
        )
        .fold<int>(0, (total, entry) => total + entry.amountCents);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat.currency(locale: 'pl_PL', symbol: 'zł');
    String money(int cents) => formatter.format(cents / 100);

    return Material(
      color: dark ? const Color(0xff252c3d) : const Color(0xffe9eefb),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenCosts,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Najbliższa płatność',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
              const SizedBox(height: 16),
              if (next == null) ...[
                Text(
                  'Brak zaplanowanych płatności',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Dodaj wydatek lub subskrypcję, a termin pojawi się tutaj.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dodaj pierwszą płatność',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: dark ? .32 : .7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              next.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              next.isSubscription ? 'Subskrypcja' : 'Płatność',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(next.amountCents),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            DateFormat('d MMM', 'pl_PL').format(next.dueAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (timeline.length > 1) ...[
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final stacked =
                          bounds.maxWidth < 320 ||
                          MediaQuery.textScalerOf(context).scale(16) > 22;
                      if (stacked) {
                        return Column(
                          children: [
                            for (final payment in timeline)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        payment.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'd MMM',
                                        'pl_PL',
                                      ).format(payment.dueAt),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final payment in timeline)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 9,
                                      width: 9,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat(
                                        'd MMM',
                                        'pl_PL',
                                      ).format(payment.dueAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                    Text(
                                      payment.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    Text(
                                      money(payment.amountCents),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Średnio / mies.: ${money(overview.monthlySubscriptionsCents)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Opłacone w tym miesiącu: ${money(paidThisMonth)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
