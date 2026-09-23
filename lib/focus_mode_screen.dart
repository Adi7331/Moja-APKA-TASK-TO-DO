import 'package:flutter/material.dart';

import 'task_item.dart';

class FocusModeScreen extends StatelessWidget {
  const FocusModeScreen({
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
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('focus-back'),
          tooltip: 'Wróć',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Skupienie'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'JEDNA RZECZ TERAZ',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (task.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      task.note,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                  ],
                  if (task.category != 'Skrzynka') ...[
                    const SizedBox(height: 18),
                    Chip(
                      avatar: const Icon(Icons.label_outline, size: 18),
                      label: Text(task.category),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Nie musisz zrobić wszystkiego. Zrób następny mały krok.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('focus-complete'),
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Oznacz jako zrobione'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('focus-postpone'),
                    onPressed: onPostpone,
                    icon: const Icon(Icons.snooze_outlined),
                    label: const Text('Odłóż na później'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
