import 'package:flutter/material.dart';

import 'task_item.dart';
import 'task_appearance.dart';
import 'task_view.dart';

/// The task workspace used by the opt-in remaster. It deliberately owns only
/// presentation state (view, search and selected row); task data stays in
/// [MyApp], so offline persistence and Supabase sync remain unchanged.
class RemasterTasksScreen extends StatefulWidget {
  const RemasterTasksScreen({
    super.key,
    required this.tasks,
    required this.selectedView,
    required this.onViewChanged,
    required this.onOpenTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onPostponeTask,
    required this.onQuickAdd,
    required this.onOpenWeek,
    required this.onOpenWeeklyReview,
  });

  final List<TaskItem> tasks;
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final ValueChanged<TaskItem> onPostponeTask;
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenWeek;
  final VoidCallback onOpenWeeklyReview;

  @override
  State<RemasterTasksScreen> createState() => _RemasterTasksScreenState();
}

class _RemasterTasksScreenState extends State<RemasterTasksScreen> {
  final _search = TextEditingController();
  TaskView? _view;
  String _query = '';
  String? _selectedTaskId;

  TaskView get _activeView => _view ?? widget.selectedView;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TaskItem> get _tasks {
    final normalized = _query.trim().toLowerCase();
    return tasksForView(widget.tasks, _activeView, DateTime.now()).where((
      task,
    ) {
      return normalized.isEmpty ||
          task.title.toLowerCase().contains(normalized) ||
          task.note.toLowerCase().contains(normalized) ||
          task.category.toLowerCase().contains(normalized);
    }).toList();
  }

  TaskItem? get _selected {
    final id = _selectedTaskId;
    if (id == null) return _tasks.firstOrNull;
    return _tasks.where((task) => task.id == id).firstOrNull ??
        _tasks.firstOrNull;
  }

  void _setView(TaskView view) {
    setState(() {
      _view = view;
      _selectedTaskId = null;
    });
    widget.onViewChanged(view);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final list = _TaskList(
          queryController: _search,
          query: _query,
          activeView: _activeView,
          tasks: _tasks,
          selectedTaskId: _selectedTaskId,
          onQueryChanged: (value) => setState(() => _query = value),
          onViewChanged: _setView,
          onSelect: (task) => setState(() => _selectedTaskId = task.id),
          onOpen: widget.onOpenTask,
          onStatusSelected: widget.onStatusSelected,
          onDelete: widget.onDeleteTask,
          onPostpone: widget.onPostponeTask,
          onAdd: widget.onQuickAdd,
          onOpenWeek: widget.onOpenWeek,
          onOpenReview: widget.onOpenWeeklyReview,
        );
        if (!wide) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            Container(width: 1, color: scheme.outlineVariant),
            SizedBox(
              width: 348,
              child: _TaskInspector(
                task: _selected,
                onOpen: widget.onOpenTask,
                onStatusSelected: widget.onStatusSelected,
                onPostpone: widget.onPostponeTask,
                onDelete: widget.onDeleteTask,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.queryController,
    required this.query,
    required this.activeView,
    required this.tasks,
    required this.selectedTaskId,
    required this.onQueryChanged,
    required this.onViewChanged,
    required this.onSelect,
    required this.onOpen,
    required this.onStatusSelected,
    required this.onDelete,
    required this.onPostpone,
    required this.onAdd,
    required this.onOpenWeek,
    required this.onOpenReview,
  });

  final TextEditingController queryController;
  final String query;
  final TaskView activeView;
  final List<TaskItem> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TaskView> onViewChanged;
  final ValueChanged<TaskItem> onSelect;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDelete;
  final ValueChanged<TaskItem> onPostpone;
  final VoidCallback onAdd;
  final VoidCallback onOpenWeek;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      key: const PageStorageKey('remaster-tasks-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zadania',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Widok tygodnia',
                      onPressed: onOpenWeek,
                      icon: const Icon(Icons.calendar_view_week_outlined),
                    ),
                    IconButton(
                      tooltip: 'Przegląd tygodnia',
                      onPressed: onOpenReview,
                      icon: const Icon(Icons.auto_graph_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: queryController,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Szukaj zadań',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TaskView.values
                        .map(
                          (view) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_viewTitle(view)),
                              selected: activeView == view,
                              onSelected: (_) => onViewChanged(view),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          sliver: tasks.isEmpty
              ? SliverToBoxAdapter(child: _EmptyTasks(onAdd: onAdd))
              : SliverList.separated(
                  itemCount: tasks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${tasks.length} ${tasks.length == 1 ? 'zadanie' : 'zadań'}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      );
                    }
                    final task = tasks[index - 1];
                    return _TaskRow(
                      task: task,
                      selected: task.id == selectedTaskId,
                      onSelect: () => onSelect(task),
                      onOpen: () => onOpen(task),
                      onStatusSelected: (status) =>
                          onStatusSelected(task, status),
                      onPostpone: () => onPostpone(task),
                      onDelete: () => onDelete(task),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onStatusSelected,
    required this.onPostpone,
    required this.onDelete,
  });

  final TaskItem task;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback onPostpone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseBackground = TaskAppearance.background(context, task.colorKey);
    final taskForeground = TaskAppearance.foreground(context, task.colorKey);
    final completedColor = scheme.onSurfaceVariant.withValues(alpha: .62);
    final actions = [
      _TaskStatusButton(
        tooltip: 'Oznacz jako do zrobienia',
        icon: Icons.radio_button_unchecked_rounded,
        selected: task.status == 'todo',
        onPressed: () => onStatusSelected('todo'),
      ),
      _TaskStatusButton(
        tooltip: 'Oznacz jako w trakcie',
        icon: Icons.timelapse_rounded,
        selected: task.status == 'doing',
        onPressed: () => onStatusSelected('doing'),
      ),
      _TaskStatusButton(
        tooltip: 'Oznacz jako gotowe',
        icon: Icons.check_circle_outline_rounded,
        selected: task.status == 'done',
        onPressed: () => onStatusSelected('done'),
      ),
      IconButton(
        tooltip: 'Odłóż zadanie',
        onPressed: onPostpone,
        icon: const Icon(Icons.snooze_rounded),
      ),
      IconButton(
        tooltip: 'Usuń zadanie',
        onPressed: onDelete,
        color: scheme.onSurfaceVariant,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ];
    final title = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.emoji?.isNotEmpty == true ? '${task.emoji} ' : ''}${task.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: task.isDone ? completedColor : taskForeground,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                decorationThickness: task.isDone ? 2 : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _taskMeta(task),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: task.isDone
                    ? completedColor
                    : taskForeground.withValues(alpha: .8),
              ),
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Semantics(
          button: true,
          label: 'Zadanie ${task.title}',
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: scheme.copyWith(
                onSurface: taskForeground,
                onSurfaceVariant: taskForeground.withValues(alpha: .8),
              ),
            ),
            child: Material(
              color: selected
                  ? Color.alphaBlend(
                      scheme.primary.withValues(alpha: .12),
                      baseBackground,
                    )
                  : baseBackground,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onSelect,
                onDoubleTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: task.isDone
                                      ? 'Przywróć zadanie'
                                      : 'Ukończ zadanie',
                                  onPressed: () => onStatusSelected(
                                    task.isDone ? 'todo' : 'done',
                                  ),
                                  icon: Icon(
                                    task.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                  ),
                                  color: task.isDone
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: title),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: actions),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: task.isDone
                                  ? 'Przywróć zadanie'
                                  : 'Ukończ zadanie',
                              onPressed: () => onStatusSelected(
                                task.isDone ? 'todo' : 'done',
                              ),
                              icon: Icon(
                                task.isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                              ),
                              color: task.isDone
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: title),
                            ...actions,
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskStatusButton extends StatelessWidget {
  const _TaskStatusButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? scheme.primaryContainer
            : Colors.transparent,
        foregroundColor: selected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
      ),
      icon: Icon(icon),
    );
  }
}

class _TaskInspector extends StatelessWidget {
  const _TaskInspector({
    required this.task,
    required this.onOpen,
    required this.onStatusSelected,
    required this.onPostpone,
    required this.onDelete,
  });
  final TaskItem? task;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onPostpone;
  final ValueChanged<TaskItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final current = task;
    final scheme = Theme.of(context).colorScheme;
    if (current == null) {
      return Center(
        child: Text(
          'Wybierz zadanie',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SZCZEGÓŁY',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(letterSpacing: 1.1, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(current.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _taskMeta(current),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (current.note.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(current.note, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => onOpen(current),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edytuj zadanie'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Odłóż zadanie',
                onPressed: () => onPostpone(current),
                icon: const Icon(Icons.snooze_rounded),
              ),
              IconButton(
                tooltip: 'Usuń zadanie',
                onPressed: () => onDelete(current),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Tu jest spokojnie',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dodaj pierwsze zadanie albo wróć do niego później.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Dodaj zadanie'),
          ),
        ],
      ),
    ),
  );
}

String _viewTitle(TaskView view) => switch (view) {
  TaskView.today => 'Dzisiaj',
  TaskView.inbox => 'Skrzynka',
  TaskView.upcoming => 'Nadchodzące',
  TaskView.completed => 'Ukończone',
};

String _taskMeta(TaskItem task) {
  final due = task.dueAt;
  final day = due == null
      ? null
      : '${due.day.toString().padLeft(2, '0')}.${due.month.toString().padLeft(2, '0')}';
  return [
    task.category,
    ?day,
    if (task.priority == 'high') 'Wysoki priorytet',
  ].join(' · ');
}
