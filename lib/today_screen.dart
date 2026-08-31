import 'package:flutter/material.dart';

import 'task_item.dart';
import 'task_row.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.visibleTasks,
    required this.laterTasks,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onQuickAdd,
  });

  final List<TaskItem> visibleTasks;
  final List<TaskItem> laterTasks;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 720;
          final content = _DailyPlan(
            visibleTasks: visibleTasks,
            laterTasks: laterTasks,
            searchQuery: searchQuery,
            onSearchChanged: onSearchChanged,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            onOpenTask: onOpenTask,
            onCompleteTask: onCompleteTask,
            onStatusSelected: onStatusSelected,
            onDeleteTask: onDeleteTask,
            onQuickAdd: onQuickAdd,
            compact: !desktop,
          );
          return Scaffold(
            body: desktop
                ? Row(
                    children: [
                      const _DesktopNavigation(),
                      Expanded(child: content),
                    ],
                  )
                : SafeArea(child: content),
          );
        },
      );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 184,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('✓ Dzień po dniu',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const SizedBox(height: 22),
          const _NavigationItem(icon: Icons.wb_sunny_outlined, label: 'Dzisiaj', selected: true),
          const _NavigationItem(icon: Icons.inbox_outlined, label: 'Skrzynka'),
          const _NavigationItem(icon: Icons.calendar_month_outlined, label: 'Nadchodzące'),
          const _NavigationItem(icon: Icons.check_circle_outline, label: 'Ukończone'),
          const Spacer(),
          const _NavigationItem(icon: Icons.settings_outlined, label: 'Ustawienia'),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPlan extends StatelessWidget {
  const _DailyPlan({
    required this.visibleTasks,
    required this.laterTasks,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onQuickAdd,
    required this.compact,
  });

  final List<TaskItem> visibleTasks;
  final List<TaskItem> laterTasks;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final allTasks = [...visibleTasks, ...laterTasks];
    final focusTask = allTasks.where((task) => !task.isDone).cast<TaskItem?>().firstOrNull;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 30, 24, compact ? 18 : 30, 24),
          children: [
            _Header(compact: compact),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('task-search'),
              initialValue: searchQuery,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Szukaj zadań',
              ),
            ),
            const SizedBox(height: 12),
            _FocusCard(task: focusTask, onOpen: focusTask == null ? null : () => onOpenTask(focusTask)),
            const SizedBox(height: 14),
            _FilterStrip(selected: selectedFilter, onChanged: onFilterChanged),
            const SizedBox(height: 18),
            _SectionHeader(label: 'Najważniejsze', count: visibleTasks.length),
            const SizedBox(height: 7),
            _TaskGroup(
              tasks: visibleTasks,
              onOpenTask: onOpenTask,
              onCompleteTask: onCompleteTask,
              onStatusSelected: onStatusSelected,
              onDeleteTask: onDeleteTask,
            ),
            if (laterTasks.isNotEmpty) ...[
              const SizedBox(height: 19),
              _SectionHeader(label: 'Później', count: laterTasks.length),
              const SizedBox(height: 7),
              _TaskGroup(
                tasks: laterTasks,
                onOpenTask: onOpenTask,
                onCompleteTask: onCompleteTask,
                onStatusSelected: onStatusSelected,
                onDeleteTask: onDeleteTask,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('quick-add-task'),
              onPressed: onQuickAdd,
              icon: const Icon(Icons.add),
              label: const Text('Szybko zapisz zadanie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Poniedziałek, 31 sierpnia',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 3),
              Text('Dzisiaj', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          IconButton(
            tooltip: 'Ustawienia',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      );
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.task, required this.onOpen});
  final TaskItem? task;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = task == null ? 'Wybierz jedną rzecz na start' : task!.title;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✦ TERAZ', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                task?.dueAt == null ? 'Zacznij spokojnie od małego kroku.' : 'Najbliższy termin w Twoim planie.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ])),
            CircleAvatar(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.arrow_forward),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Filter(label: 'Dzisiaj', value: 'todo', selected: selected, onChanged: onChanged),
            _Filter(label: 'W trakcie', value: 'in_progress', selected: selected, onChanged: onChanged),
            _Filter(label: 'Gotowe', value: 'done', selected: selected, onChanged: onChanged),
            _Filter(label: 'Wszystkie', value: 'all', selected: selected, onChanged: onChanged),
          ],
        ),
      );
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.value, required this.selected, required this.onChanged});
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onChanged(value),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$count ${count == 1 ? 'zadanie' : 'zadania'}', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.tasks,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
  });
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem, String) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Text('Brak zadań w tej sekcji.', style: Theme.of(context).textTheme.bodySmall);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: tasks
            .map((task) => TaskRow(
                  task: task,
                  onOpen: () => onOpenTask(task),
                  onComplete: () => onCompleteTask(task),
                  onStatusSelected: (status) => onStatusSelected(task, status),
                  onDelete: () => onDeleteTask(task),
                ))
            .toList(),
      ),
    );
  }
}
