import 'package:flutter/material.dart';

import 'task_item.dart';
import 'task_row.dart';
import 'task_view.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.visibleTasks,
    required this.laterTasks,
    required this.selectedView,
    required this.onViewChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.successNotice,
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
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? successNotice;
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
        selectedView: selectedView,
        onViewChanged: onViewChanged,
        themeMode: themeMode,
        onThemeModeChanged: onThemeModeChanged,
        successNotice: successNotice,
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
                  _DesktopNavigation(
                    selectedView: selectedView,
                    onViewChanged: onViewChanged,
                    onOpenSettings: () => _showAppearanceSheet(
                      context,
                      themeMode,
                      onThemeModeChanged,
                    ),
                  ),
                  Expanded(child: content),
                ],
              )
            : SafeArea(child: content),
        floatingActionButton: desktop
            ? FloatingActionButton.extended(
                key: const ValueKey('quick-add-task'),
                onPressed: onQuickAdd,
                icon: const Icon(Icons.add),
                label: const Text('Szybko zapisz'),
              )
            : null,
      );
    },
  );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedView,
    required this.onViewChanged,
    required this.onOpenSettings,
  });

  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final VoidCallback onOpenSettings;

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
            child: Text(
              '✓ Dzień po dniu',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 22),
          _NavigationItem(
            icon: Icons.wb_sunny_outlined,
            label: 'Dzisiaj',
            view: TaskView.today,
            selected: selectedView == TaskView.today,
            onTap: onViewChanged,
          ),
          _NavigationItem(
            icon: Icons.inbox_outlined,
            label: 'Skrzynka',
            view: TaskView.inbox,
            selected: selectedView == TaskView.inbox,
            onTap: onViewChanged,
          ),
          _NavigationItem(
            icon: Icons.calendar_month_outlined,
            label: 'Nadchodzące',
            view: TaskView.upcoming,
            selected: selectedView == TaskView.upcoming,
            onTap: onViewChanged,
          ),
          _NavigationItem(
            icon: Icons.check_circle_outline,
            label: 'Ukończone',
            view: TaskView.completed,
            selected: selectedView == TaskView.completed,
            onTap: onViewChanged,
          ),
          const Spacer(),
          _NavigationItem(
            icon: Icons.settings_outlined,
            label: 'Ustawienia',
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    this.view,
    this.onTap,
    this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final TaskView? view;
  final ValueChanged<TaskView>? onTap;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onPressed ?? (view == null ? null : () => onTap!(view!)),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
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
        ),
      ),
    );
  }
}

class _DailyPlan extends StatelessWidget {
  const _DailyPlan({
    required this.visibleTasks,
    required this.laterTasks,
    required this.selectedView,
    required this.onViewChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.successNotice,
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
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? successNotice;
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
    final focusTask = allTasks
        .where((task) => !task.isDone)
        .cast<TaskItem?>()
        .firstOrNull;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 30,
            24,
            compact ? 18 : 30,
            24,
          ),
          children: [
            _Header(
              compact: compact,
              selectedView: selectedView,
              onViewChanged: onViewChanged,
              themeMode: themeMode,
              onThemeModeChanged: onThemeModeChanged,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: successNotice == null
                  ? const SizedBox.shrink()
                  : _SuccessNotice(
                      key: ValueKey(successNotice),
                      message: successNotice!,
                    ),
            ),
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
            if (selectedView == TaskView.today) ...[
              _FocusCard(
                task: focusTask,
                onOpen: focusTask == null ? null : () => onOpenTask(focusTask),
              ),
              const SizedBox(height: 14),
              _FilterStrip(
                selected: selectedFilter,
                onChanged: onFilterChanged,
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 18),
            _SectionHeader(
              label: selectedView == TaskView.today
                  ? 'Najważniejsze'
                  : _viewSectionLabel(selectedView),
              count: visibleTasks.length,
            ),
            const SizedBox(height: 7),
            _TaskGroup(
              tasks: visibleTasks,
              view: selectedView,
              onOpenTask: onOpenTask,
              onCompleteTask: onCompleteTask,
              onStatusSelected: onStatusSelected,
              onDeleteTask: onDeleteTask,
              onQuickAdd: onQuickAdd,
            ),
            if (laterTasks.isNotEmpty) ...[
              const SizedBox(height: 19),
              _SectionHeader(label: 'Później', count: laterTasks.length),
              const SizedBox(height: 7),
              _TaskGroup(
                tasks: laterTasks,
                view: TaskView.upcoming,
                onOpenTask: onOpenTask,
                onCompleteTask: onCompleteTask,
                onStatusSelected: onStatusSelected,
                onDeleteTask: onDeleteTask,
                onQuickAdd: onQuickAdd,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: ValueKey(compact ? 'quick-add-task' : 'quick-add-task-list'),
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

class _SuccessNotice extends StatelessWidget {
  const _SuccessNotice({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: scheme.primary, size: 19),
            const SizedBox(width: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.selectedView,
    required this.onViewChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  final bool compact;
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poniedziałek, 31 sierpnia',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _viewTitle(selectedView),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      PopupMenuButton<_HeaderMenuAction>(
        key: const ValueKey('task-view-menu'),
        tooltip: 'Zmień widok',
        onSelected: (action) {
          if (action.view != null) {
            onViewChanged(action.view!);
          } else {
            _showAppearanceSheet(context, themeMode, onThemeModeChanged);
          }
        },
        icon: const Icon(Icons.more_horiz),
        itemBuilder: (context) => [
          ...TaskView.values.map(
            (view) => PopupMenuItem<_HeaderMenuAction>(
              value: _HeaderMenuAction.view(view),
              child: Row(
                children: [
                  Expanded(child: Text(_viewTitle(view))),
                  if (view == selectedView) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<_HeaderMenuAction>(
            value: _HeaderMenuAction.settings(),
            child: Row(
              children: [
                Icon(Icons.settings_outlined, size: 18),
                SizedBox(width: 10),
                Text('Ustawienia'),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _HeaderMenuAction {
  const _HeaderMenuAction.view(this.view);
  const _HeaderMenuAction.settings() : view = null;

  final TaskView? view;
}

void _showAppearanceSheet(
  BuildContext context,
  ThemeMode themeMode,
  ValueChanged<ThemeMode> onThemeModeChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AppearanceSheet(
      selected: themeMode,
      onChanged: (mode) {
        onThemeModeChanged(mode);
        Navigator.pop(context);
      },
    ),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wygląd',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Wybierz motyw aplikacji.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _ThemeOption(
            label: 'Systemowy',
            detail: 'Zgodny z urządzeniem',
            mode: ThemeMode.system,
            selected: selected,
            onChanged: onChanged,
          ),
          _ThemeOption(
            label: 'Jasny',
            detail: 'Zawsze jasny wygląd',
            mode: ThemeMode.light,
            selected: selected,
            onChanged: onChanged,
          ),
          _ThemeOption(
            label: 'Ciemny',
            detail: 'Zawsze ciemny wygląd',
            mode: ThemeMode.dark,
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.detail,
    required this.mode,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final ThemeMode mode;
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      selected == mode ? Icons.radio_button_checked : Icons.radio_button_off,
    ),
    title: Text(label),
    subtitle: Text(detail),
    onTap: () => onChanged(mode),
  );
}

String _viewTitle(TaskView view) => switch (view) {
  TaskView.today => 'Dzisiaj',
  TaskView.inbox => 'Skrzynka',
  TaskView.upcoming => 'Nadchodzące',
  TaskView.completed => 'Ukończone',
};

String _viewSectionLabel(TaskView view) => switch (view) {
  TaskView.inbox => 'Do uporządkowania',
  TaskView.upcoming => 'Zaplanowane',
  TaskView.completed => 'Zrobione',
  TaskView.today => 'Najważniejsze',
};

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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✦ TERAZ',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      text,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task?.dueAt == null
                          ? 'Zacznij spokojnie od małego kroku.'
                          : 'Najbliższy termin w Twoim planie.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
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
        _Filter(
          label: 'Dzisiaj',
          value: 'todo',
          selected: selected,
          onChanged: onChanged,
        ),
        _Filter(
          label: 'W trakcie',
          value: 'in_progress',
          selected: selected,
          onChanged: onChanged,
        ),
        _Filter(
          label: 'Gotowe',
          value: 'done',
          selected: selected,
          onChanged: onChanged,
        ),
        _Filter(
          label: 'Wszystkie',
          value: 'all',
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });
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
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      Text(
        '$count ${count == 1 ? 'zadanie' : 'zadania'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.tasks,
    required this.view,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onQuickAdd,
  });
  final List<TaskItem> tasks;
  final TaskView view;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem, String) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _EmptyTaskState(view: view, onQuickAdd: onQuickAdd);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: tasks
            .map(
              (task) => TaskRow(
                task: task,
                onOpen: () => onOpenTask(task),
                onComplete: () => onCompleteTask(task),
                onStatusSelected: (status) => onStatusSelected(task, status),
                onDelete: () => onDeleteTask(task),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState({required this.view, required this.onQuickAdd});

  final TaskView view;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = switch (view) {
      TaskView.inbox => (
          icon: Icons.inbox_outlined,
          title: 'Skrzynka jest pusta',
          detail: 'Dodaj sprawę, która przyszła Ci właśnie do głowy.',
        ),
      TaskView.upcoming => (
          icon: Icons.calendar_month_outlined,
          title: 'Nic nie czeka w kolejce',
          detail: 'Dodaj termin, żeby zaplanować następne dni.',
        ),
      TaskView.completed => (
          icon: Icons.check_circle_outline,
          title: 'Jeszcze nic nie jest ukończone',
          detail: 'Pierwsze zrobione zadanie pojawi się tutaj.',
        ),
      TaskView.today => (
          icon: Icons.wb_sunny_outlined,
          title: 'Dzisiaj masz wolną przestrzeń',
          detail: 'Dodaj jedno małe zadanie na dobry start.',
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: Icon(content.icon),
          ),
          const SizedBox(height: 10),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            content.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('empty-add-task'),
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Dodaj zadanie'),
          ),
        ],
      ),
    );
  }
}
