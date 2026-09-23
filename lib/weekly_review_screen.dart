import 'package:flutter/material.dart';

import 'weekly_review.dart';

class WeeklyReviewScreen extends StatelessWidget {
  const WeeklyReviewScreen({super.key, required this.review, required this.onOpenDailyPlan});

  final WeeklyReview review;
  final VoidCallback onOpenDailyPlan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Przegląd tygodnia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.secondaryContainer]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ukończone w poprzednim tygodniu', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text('${review.completedCount}', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Małe kroki też się liczą.'),
            ]),
          ),
          const SizedBox(height: 24),
          _TaskSection(label: 'Zaległe', tasks: review.overdue, empty: 'Nic nie zalega — dobra robota.'),
          const SizedBox(height: 20),
          _TaskSection(label: 'Najbliższe terminy', tasks: review.nextDue, empty: 'Brak najbliższych terminów.'),
          const SizedBox(height: 28),
          FilledButton.icon(onPressed: onOpenDailyPlan, icon: const Icon(Icons.wb_sunny_outlined), label: const Text('Przejdź do planu dnia')),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({required this.label, required this.tasks, required this.empty});
  final String label;
  final List tasks;
  final String empty;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    if (tasks.isEmpty) Text(empty) else ...tasks.map((task) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline), title: Text(task.title))),
  ]);
}
