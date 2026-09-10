import 'package:flutter/material.dart';

import 'task_item.dart';
import 'weekly_review.dart';

class RemasterWeeklyReviewScreen extends StatelessWidget {
  const RemasterWeeklyReviewScreen({
    super.key,
    required this.review,
    required this.onOpenDailyPlan,
  });

  final WeeklyReview review;
  final VoidCallback onOpenDailyPlan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth >= 760 ? 32 : 20,
              20,
              constraints.maxWidth >= 760 ? 32 : 20,
              28,
            ),
            children: [
              Row(children: [
                IconButton(
                  tooltip: 'Wróć',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Przegląd tygodnia', style: Theme.of(context).textTheme.headlineMedium)),
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MINIONY TYDZIEŃ', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text('${review.completedCount}', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const Text('ukończonych zadań'),
                  const SizedBox(height: 14),
                  Text(
                    review.completedCount == 0 ? 'Zaczynamy od nowa, bez presji.' : 'Każdy zamknięty temat robi miejsce na kolejny.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              _MetricRow(
                overdue: review.overdue.length,
                upcoming: review.nextDue.length,
              ),
              const SizedBox(height: 28),
              _ReviewTasks(
                title: 'Wymagają uwagi',
                icon: Icons.schedule_rounded,
                tasks: review.overdue,
                empty: 'Nic nie zalega. Dobra robota.',
                tone: scheme.error,
              ),
              const SizedBox(height: 24),
              _ReviewTasks(
                title: 'Najbliższe terminy',
                icon: Icons.arrow_forward_rounded,
                tasks: review.nextDue,
                empty: 'Brak terminów na najbliższe dni.',
                tone: scheme.primary,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onOpenDailyPlan,
                icon: const Icon(Icons.wb_sunny_outlined),
                label: const Text('Wróć do planu dnia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.overdue, required this.upcoming});
  final int overdue;
  final int upcoming;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final cards = [
        _Metric(label: 'Zaległe', value: overdue, icon: Icons.schedule_outlined),
        _Metric(label: 'Najbliższe', value: upcoming, icon: Icons.event_outlined),
      ];
      return compact
          ? Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
          : Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]);
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      Icon(icon),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
    ]),
  );
}

class _ReviewTasks extends StatelessWidget {
  const _ReviewTasks({required this.title, required this.icon, required this.tasks, required this.empty, required this.tone});
  final String title;
  final IconData icon;
  final List<TaskItem> tasks;
  final String empty;
  final Color tone;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: tone), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge)]),
    const SizedBox(height: 10),
    if (tasks.isEmpty)
      Text(empty, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
    else
      ...tasks.map((task) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.circle_outlined),
          title: Text(task.title),
          subtitle: Text(task.category),
        ),
      )),
  ]);
}
