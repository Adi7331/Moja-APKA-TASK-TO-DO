import 'package:flutter/material.dart';

import 'task_item.dart';

class RemasterFocusModeScreen extends StatelessWidget {
  const RemasterFocusModeScreen({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onPostpone,
  });

  final TaskItem task;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 24 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Zamknij skupienie',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text('Skupienie', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.center_focus_strong_rounded, color: scheme.onPrimaryContainer),
                                const SizedBox(width: 10),
                                Text(
                                  'JEDNA RZECZ TERAZ',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                            ),
                            if (task.note.trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                task.note,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: scheme.onPrimaryContainer.withValues(alpha: .82),
                                      height: 1.5,
                                    ),
                              ),
                            ],
                            if (task.category != 'Skrzynka') ...[
                              const SizedBox(height: 24),
                              Text(task.category, style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: .76))),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Nie musisz zrobić wszystkiego. Zrób następny mały krok.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('remaster-focus-complete'),
                      onPressed: onComplete,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Oznacz jako zrobione'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('remaster-focus-postpone'),
                      onPressed: onPostpone,
                      icon: const Icon(Icons.snooze_rounded),
                      label: const Text('Odłóż na później'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
