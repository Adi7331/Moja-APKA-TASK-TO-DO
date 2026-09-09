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
    this.syncStatus = 'Lokalnie',
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onQuickAdd,
    this.onQuickAddText,
    this.pinnedTasks = const [],
    this.onTogglePin,
    this.onPostponeTask,
    this.onOpenWeek,
    this.onOpenWeeklyReview,
    this.onOpenNotes,
    this.onOpenFocus,
    this.onSignOut,
  });

  final List<TaskItem> visibleTasks;
  final List<TaskItem> laterTasks;
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? successNotice;
  final String syncStatus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;
  final ValueChanged<String>? onQuickAddText;
  final List<TaskItem> pinnedTasks;
  final ValueChanged<TaskItem>? onTogglePin;
  final ValueChanged<TaskItem>? onPostponeTask;
  final VoidCallback? onOpenWeek;
  final VoidCallback? onOpenWeeklyReview;
  final VoidCallback? onOpenNotes;
  final ValueChanged<TaskItem>? onOpenFocus;
  final VoidCallback? onSignOut;

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
        syncStatus: syncStatus,
        searchQuery: searchQuery,
        onSearchChanged: onSearchChanged,
        selectedFilter: selectedFilter,
        onFilterChanged: onFilterChanged,
        onOpenTask: onOpenTask,
        onCompleteTask: onCompleteTask,
        onStatusSelected: onStatusSelected,
        onDeleteTask: onDeleteTask,
        onQuickAdd: onQuickAdd,
        onQuickAddText: onQuickAddText,
        pinnedTasks: pinnedTasks,
        onTogglePin: onTogglePin,
        onPostponeTask: onPostponeTask,
        onOpenWeek: onOpenWeek,
        onOpenFocus: onOpenFocus,
        onOpenNotes: onOpenNotes,
        onSignOut: onSignOut,
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
                    onOpenWeek: onOpenWeek,
                    onOpenWeeklyReview: onOpenWeeklyReview,
                    onOpenNotes: onOpenNotes,
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
    this.onOpenWeek,
    this.onOpenWeeklyReview,
    this.onOpenNotes,
  });

  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenWeek;
  final VoidCallback? onOpenWeeklyReview;
  final VoidCallback? onOpenNotes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: scheme.primary,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dzień po dniu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _NavigationItem(
            icon: Icons.wb_sunny_outlined,
            label: 'Dzisiaj',
            view: TaskView.today,
            selected: selectedView == TaskView.today,
            onTap: onViewChanged,
          ),
          if (onOpenWeek != null)
            _NavigationItem(
              icon: Icons.calendar_view_week_outlined,
              label: 'Tydzień',
              onPressed: onOpenWeek,
            ),
          if (onOpenWeeklyReview != null)
            _NavigationItem(
              icon: Icons.insights_outlined,
              label: 'Przegląd tygodnia',
              onPressed: onOpenWeeklyReview,
            ),
          if (onOpenNotes != null)
            _NavigationItem(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notatki',
              onPressed: onOpenNotes,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: onPressed ?? (view == null ? null : () => onTap!(view!)),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: scheme.primary.withValues(alpha: .10),
        focusColor: scheme.primary.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
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
    required this.syncStatus,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onStatusSelected,
    required this.onDeleteTask,
    required this.onQuickAdd,
    required this.onQuickAddText,
    required this.compact,
    required this.pinnedTasks,
    required this.onTogglePin,
    required this.onPostponeTask,
    required this.onOpenWeek,
    required this.onOpenFocus,
    required this.onOpenNotes,
    this.onSignOut,
  });

  final List<TaskItem> visibleTasks;
  final List<TaskItem> laterTasks;
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? successNotice;
  final String syncStatus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem task, String status) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;
  final ValueChanged<String>? onQuickAddText;
  final bool compact;
  final List<TaskItem> pinnedTasks;
  final ValueChanged<TaskItem>? onTogglePin;
  final ValueChanged<TaskItem>? onPostponeTask;
  final VoidCallback? onOpenWeek;
  final ValueChanged<TaskItem>? onOpenFocus;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onSignOut;

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
              onOpenWeek: onOpenWeek,
              onOpenNotes: onOpenNotes,
              onSignOut: onSignOut,
              syncStatus: syncStatus,
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
            if (onQuickAddText != null) ...[
              const SizedBox(height: 12),
              _QuickTaskEntry(onSubmitted: onQuickAddText!),
            ],
            const SizedBox(height: 12),
            if (selectedView == TaskView.today) ...[
              if (pinnedTasks.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Plan na dziś',
                  count: pinnedTasks.length,
                ),
                const SizedBox(height: 7),
                _TaskGroup(
                  tasks: pinnedTasks,
                  view: TaskView.today,
                  onOpenTask: onOpenTask,
                  onCompleteTask: onCompleteTask,
                  onStatusSelected: onStatusSelected,
                  onDeleteTask: onDeleteTask,
                  onQuickAdd: onQuickAdd,
                  onTogglePin: onTogglePin,
                  onPostponeTask: onPostponeTask,
                ),
                const SizedBox(height: 18),
              ],
              _FocusCard(
                task: focusTask,
                onOpen: focusTask == null
                    ? onQuickAdd
                    : () => (onOpenFocus ?? onOpenTask)(focusTask),
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
              onPostponeTask: onPostponeTask,
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
                onPostponeTask: onPostponeTask,
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

class _QuickTaskEntry extends StatefulWidget {
  const _QuickTaskEntry({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_QuickTaskEntry> createState() => _QuickTaskEntryState();
}

class _QuickTaskEntryState extends State<_QuickTaskEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmitted(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Szybkie dodawanie zadania',
    child: TextField(
      key: const ValueKey('quick-task-input'),
      controller: _controller,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.bolt_outlined),
        hintText: 'Szybkie zadanie, np. „Oddzwonić jutro 18:00”',
        suffixIcon: IconButton(
          key: const ValueKey('quick-task-submit'),
          tooltip: 'Dodaj szybkie zadanie',
          onPressed: _submit,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ),
    ),
  );
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
    required this.onOpenWeek,
    required this.onOpenNotes,
    this.onSignOut,
    required this.syncStatus,
  });
  final bool compact;
  final TaskView selectedView;
  final ValueChanged<TaskView> onViewChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onOpenWeek;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onSignOut;
  final String syncStatus;

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
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SyncIndicator(status: syncStatus),
          const SizedBox(height: 6),
          PopupMenuButton<_HeaderMenuAction>(
            key: const ValueKey('task-view-menu'),
            tooltip: 'Zmień widok',
            onSelected: (action) {
              if (action.view != null) {
                onViewChanged(action.view!);
              } else if (action.opensWeek) {
                onOpenWeek?.call();
              } else if (action.opensNotes) {
                onOpenNotes?.call();
              } else if (action.signsOut) {
                onSignOut?.call();
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
                      if (view == selectedView)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              if (onOpenWeek != null)
                const PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.week(),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_view_week_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Tydzień'),
                    ],
                  ),
                ),
              if (onOpenNotes != null)
                const PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.notes(),
                  child: Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Notatki'),
                    ],
                  ),
                ),
              if (onSignOut != null)
                const PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.signOut(),
                  child: Row(
                    children: [
                      Icon(Icons.logout_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Wyloguj'),
                    ],
                  ),
                ),
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
      ),
    ],
  );
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncing = status == 'Synchronizowanie…';
    final failed = status == 'Błąd synchronizacji';
    final color = failed
        ? scheme.error
        : syncing
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final icon = failed
        ? Icons.cloud_off_outlined
        : syncing
        ? Icons.sync
        : status == 'Lokalnie'
        ? Icons.phone_android_outlined
        : Icons.cloud_done_outlined;
    return Semantics(
      liveRegion: true,
      label: 'Status synchronizacji: $status',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              status,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMenuAction {
  const _HeaderMenuAction.view(this.view)
      : opensWeek = false,
        opensNotes = false,
        signsOut = false;
  const _HeaderMenuAction.week()
      : view = null,
        opensWeek = true,
        opensNotes = false,
        signsOut = false;
  const _HeaderMenuAction.notes()
      : view = null,
        opensWeek = false,
        opensNotes = true,
        signsOut = false;
  const _HeaderMenuAction.signOut()
      : view = null,
        opensWeek = false,
        opensNotes = false,
        signsOut = true;
  const _HeaderMenuAction.settings()
      : view = null,
        opensWeek = false,
        opensNotes = false,
        signsOut = false;

  final TaskView? view;
  final bool opensWeek;
  final bool opensNotes;
  final bool signsOut;
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
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = task == null ? 'Wybierz jedną rzecz na start' : task!.title;
    final isEmpty = task == null;
    return Semantics(
      button: true,
      label: isEmpty ? 'Dodaj pierwsze zadanie' : 'Otwórz tryb skupienia: $text',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: .9),
              scheme.secondaryContainer.withValues(alpha: .96),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('open-focus-mode'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            hoverColor: scheme.onPrimary.withValues(alpha: .06),
            focusColor: scheme.onPrimary.withValues(alpha: .09),
            splashColor: scheme.onPrimary.withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_strong, size: 16, color: scheme.onSecondaryContainer),
                            const SizedBox(width: 6),
                            Text(
                              'TERAZ',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          text,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEmpty ? 'Zacznij spokojnie od małego kroku.' : 'Najbliższy termin w Twoim planie.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer.withValues(alpha: .82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      tooltip: isEmpty ? 'Dodaj pierwsze zadanie' : 'Otwórz tryb skupienia',
                      onPressed: onOpen,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      icon: Icon(isEmpty ? Icons.add_task : Icons.arrow_forward),
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
    this.onTogglePin,
    this.onPostponeTask,
  });
  final List<TaskItem> tasks;
  final TaskView view;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final void Function(TaskItem, String) onStatusSelected;
  final ValueChanged<TaskItem> onDeleteTask;
  final VoidCallback onQuickAdd;
  final ValueChanged<TaskItem>? onTogglePin;
  final ValueChanged<TaskItem>? onPostponeTask;

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
                onTogglePin: onTogglePin == null
                    ? null
                    : () => onTogglePin!(task),
                onPostpone: onPostponeTask == null
                    ? null
                    : () => onPostponeTask!(task),
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
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            content.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
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
