import 'package:flutter/material.dart';

import 'task_category_icon.dart';
import 'task_item.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onOpen,
    required this.onComplete,
    required this.onStatusSelected,
    required this.onDelete,
  });

  final TaskItem task;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emoji = categoryEmoji(task.category);
    final progress = task.subtaskCount == 0
        ? null
        : task.completedSubtaskCount / task.subtaskCount;
    final status = _statusLabel(task.status);

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: task.isDone ? 'Zadanie ukończone' : 'Oznacz jako zrobione',
                  onPressed: task.isDone ? null : onComplete,
                  icon: Icon(
                    task.isDone
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: task.isDone ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: task.isDone ? scheme.onSurfaceVariant : null,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _TaskTag(
                          label: status,
                          icon: _statusIcon(task.status),
                          backgroundColor: _statusBackground(
                            task.status,
                            scheme,
                          ),
                          foregroundColor: _statusForeground(
                            task.status,
                            scheme,
                          ),
                        ),
                        if (task.priority == 'high')
                          _TaskTag(
                            label: 'Wysoki priorytet',
                            icon: Icons.priority_high_rounded,
                            backgroundColor: scheme.errorContainer,
                            foregroundColor: scheme.onErrorContainer,
                          ),
                      ],
                    ),
                    if (task.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _metadata(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(value: progress),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.completedSubtaskCount} z ${task.subtaskCount} kroków',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (emoji != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: 'Kategoria ${task.category}',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Text(emoji),
                    ),
                  ),
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else {
                    onStatusSelected(value);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'todo', child: Text('Do zrobienia')),
                  PopupMenuItem(value: 'in_progress', child: Text('W trakcie')),
                  PopupMenuItem(value: 'done', child: Text('Oznacz jako zrobione')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Usuń zadanie')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metadata() {
    final parts = <String>[
      if (task.category != 'Skrzynka') task.category,
      if (task.dueAt != null) _dueLabel(task.dueAt!),
    ];
    return parts.isEmpty ? 'Bez terminu' : parts.join(' · ');
  }

  String _dueLabel(DateTime dueAt) =>
      '${dueAt.day.toString().padLeft(2, '0')}.${dueAt.month.toString().padLeft(2, '0')} · ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';

  String _statusLabel(String status) => switch (status) {
        'in_progress' => 'W trakcie',
        'done' => 'Ukończone',
        _ => 'Do zrobienia',
      };

  IconData _statusIcon(String status) => switch (status) {
        'in_progress' => Icons.play_arrow_rounded,
        'done' => Icons.check_rounded,
        _ => Icons.circle_outlined,
      };

  Color _statusBackground(String status, ColorScheme scheme) => switch (status) {
        'in_progress' => scheme.secondaryContainer,
        'done' => scheme.primaryContainer,
        _ => scheme.surfaceContainerHighest,
      };

  Color _statusForeground(String status, ColorScheme scheme) => switch (status) {
        'in_progress' => scheme.onSecondaryContainer,
        'done' => scheme.onPrimaryContainer,
        _ => scheme.onSurfaceVariant,
      };
}

class _TaskTag extends StatelessWidget {
  const _TaskTag({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: foregroundColor),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}
