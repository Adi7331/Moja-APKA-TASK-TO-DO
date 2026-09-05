import 'package:flutter/material.dart';

import 'task_item.dart';

DateTime _localMidnight(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _mondayOf(DateTime date) {
  final midnight = _localMidnight(date);
  return DateTime(
    midnight.year,
    midnight.month,
    midnight.day - (midnight.weekday - DateTime.monday),
  );
}

List<DateTime> weekDays(DateTime weekStart) {
  final monday = _mondayOf(weekStart);
  return List<DateTime>.generate(
    7,
    (index) => DateTime(monday.year, monday.month, monday.day + index),
  );
}

Map<DateTime, List<TaskItem>> tasksByDay(
  Iterable<TaskItem> tasks,
  DateTime weekStart,
) {
  final days = weekDays(weekStart);
  final grouped = <DateTime, List<TaskItem>>{
    for (final day in days) day: <TaskItem>[],
  };
  final monday = days.first;
  final followingMonday = DateTime(monday.year, monday.month, monday.day + 7);

  for (final task in tasks) {
    final dueAt = task.dueAt;
    if (dueAt == null ||
        dueAt.isBefore(monday) ||
        !dueAt.isBefore(followingMonday)) {
      continue;
    }
    final day = _localMidnight(dueAt);
    grouped[day]?.add(task);
  }

  for (final items in grouped.values) {
    items.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }
  return grouped;
}

TaskItem moveTaskToDay(TaskItem task, DateTime targetDay) {
  final dueAt = task.dueAt;
  final hour = dueAt?.hour ?? 9;
  final minute = dueAt?.minute ?? 0;
  return task.copyWith(
    dueAt: DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      hour,
      minute,
    ),
  );
}

class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({
    super.key,
    required this.tasks,
    required this.initialWeek,
    required this.onOpenTask,
    required this.onMoveTask,
    required this.onQuickAdd,
  });

  final List<TaskItem> tasks;
  final DateTime initialWeek;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, DateTime day) onMoveTask;
  final VoidCallback onQuickAdd;

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(widget.initialWeek);
    _selectedDay = _weekStart;
  }

  void _changeWeek(int offset) {
    setState(() {
      _weekStart = DateTime(
        _weekStart.year,
        _weekStart.month,
        _weekStart.day + (7 * offset),
      );
      _selectedDay = _weekStart;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 720;
          final days = weekDays(_weekStart);
          final grouped = tasksByDay(widget.tasks, _weekStart);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 30 : 18,
              24,
              isDesktop ? 30 : 18,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeekHeader(
                  weekStart: _weekStart,
                  onPrevious: () => _changeWeek(-1),
                  onNext: () => _changeWeek(1),
                ),
                const SizedBox(height: 20),
                if (!isDesktop) ...[
                  _WeekDayChips(
                    days: days,
                    selectedDay: _selectedDay,
                    onSelected: (day) => setState(() => _selectedDay = day),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .035),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: isDesktop
                        ? _DesktopWeek(
                            key: ValueKey('week-content-$_weekStart'),
                            days: days,
                            grouped: grouped,
                            onOpenTask: widget.onOpenTask,
                            onMoveTask: widget.onMoveTask,
                            onQuickAdd: widget.onQuickAdd,
                          )
                        : _MobileDayList(
                            key: ValueKey('week-content-$_weekStart'),
                            day: _selectedDay,
                            tasks: grouped[_selectedDay]!,
                            onOpenTask: widget.onOpenTask,
                            onMoveTask: widget.onMoveTask,
                            onQuickAdd: widget.onQuickAdd,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tydzień',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              _weekRangeLabel(weekStart),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        key: const ValueKey('week-previous'),
        tooltip: 'Poprzedni tydzień',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        key: const ValueKey('week-next'),
        tooltip: 'Następny tydzień',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _WeekDayChips extends StatelessWidget {
  const _WeekDayChips({
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final day = days[index];
        return SizedBox(
          key: ValueKey('week-day-$index'),
          height: 48,
          child: ChoiceChip(
            label: Text('${_shortDayLabel(day)} ${day.day}'),
            selected: day == selectedDay,
            onSelected: (_) => onSelected(day),
          ),
        );
      },
    ),
  );
}

class _DesktopWeek extends StatelessWidget {
  const _DesktopWeek({
    super.key,
    required this.days,
    required this.grouped,
    required this.onOpenTask,
    required this.onMoveTask,
    required this.onQuickAdd,
  });

  final List<DateTime> days;
  final Map<DateTime, List<TaskItem>> grouped;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, DateTime day) onMoveTask;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < days.length; index++) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: _DesktopDayColumn(
            day: days[index],
            index: index,
            tasks: grouped[days[index]]!,
            onOpenTask: onOpenTask,
            onMoveTask: onMoveTask,
            onQuickAdd: onQuickAdd,
          ),
        ),
      ],
    ],
  );
}

class _DesktopDayColumn extends StatelessWidget {
  const _DesktopDayColumn({
    required this.day,
    required this.index,
    required this.tasks,
    required this.onOpenTask,
    required this.onMoveTask,
    required this.onQuickAdd,
  });

  final DateTime day;
  final int index;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, DateTime day) onMoveTask;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TaskItem>(
      key: ValueKey('week-drop-$index'),
      onAcceptWithDetails: (details) => onMoveTask(details.data, day),
      builder: (context, candidateData, _) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidateData.isNotEmpty
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: candidateData.isNotEmpty
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: .65),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _shortDayLabel(day),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: tasks.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: TextButton.icon(
                        onPressed: onQuickAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Dodaj'),
                      ),
                    )
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, taskIndex) =>
                          LongPressDraggable<TaskItem>(
                            data: tasks[taskIndex],
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 160,
                                child: _TaskCard(
                                  task: tasks[taskIndex],
                                  onOpen: null,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: .35,
                              child: _TaskCard(
                                task: tasks[taskIndex],
                                onOpen: null,
                              ),
                            ),
                            child: _TaskCard(
                              key: ValueKey('week-task-${tasks[taskIndex].id}'),
                              task: tasks[taskIndex],
                              onOpen: () => onOpenTask(tasks[taskIndex]),
                            ),
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDayList extends StatelessWidget {
  const _MobileDayList({
    super.key,
    required this.day,
    required this.tasks,
    required this.onOpenTask,
    required this.onMoveTask,
    required this.onQuickAdd,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, DateTime day) onMoveTask;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      Text(
        _longDayLabel(day),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (tasks.isEmpty)
        _EmptyWeekDay(onQuickAdd: onQuickAdd)
      else
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _TaskCard(
              key: ValueKey('week-task-${task.id}'),
              task: task,
              onOpen: () => onOpenTask(task),
              moveButton: OutlinedButton.icon(
                key: ValueKey('move-task-${task.id}'),
                onPressed: () => _showMoveSheet(
                  context: context,
                  task: task,
                  weekStart: day,
                  onMoveTask: onMoveTask,
                ),
                icon: const Icon(Icons.drive_file_move_outline, size: 18),
                label: const Text('Przenieś na dzień'),
              ),
            ),
          ),
        ),
    ],
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.onOpen,
    this.moveButton,
  });

  final TaskItem task;
  final VoidCallback? onOpen;
  final Widget? moveButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                task.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (moveButton != null) ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: moveButton),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWeekDay extends StatelessWidget {
  const _EmptyWeekDay({required this.onQuickAdd});

  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Spokojny dzień',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Nie ma tu jeszcze zadań z terminem.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('week-empty-add'),
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Dodaj zadanie'),
          ),
        ],
      ),
    );
  }
}

void _showMoveSheet({
  required BuildContext context,
  required TaskItem task,
  required DateTime weekStart,
  required void Function(TaskItem task, DateTime day) onMoveTask,
}) {
  final days = weekDays(weekStart);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            'Przenieś na dzień',
            style: Theme.of(sheetContext).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < days.length; index++)
            ListTile(
              key: ValueKey('move-target-day-$index'),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_longDayLabel(days[index])),
              onTap: () {
                onMoveTask(task, days[index]);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  );
}

const _shortWeekdays = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nd'];
const _longWeekdays = [
  'Poniedziałek',
  'Wtorek',
  'Środa',
  'Czwartek',
  'Piątek',
  'Sobota',
  'Niedziela',
];
const _months = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

String _shortDayLabel(DateTime day) => _shortWeekdays[day.weekday - 1];

String _longDayLabel(DateTime day) =>
    '${_longWeekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';

String _weekRangeLabel(DateTime weekStart) {
  final days = weekDays(weekStart);
  final first = days.first;
  final last = days.last;
  if (first.month == last.month && first.year == last.year) {
    return '${first.day}–${last.day} ${_months[first.month - 1]} ${first.year}';
  }
  return '${first.day} ${_months[first.month - 1]} ${first.year} – '
      '${last.day} ${_months[last.month - 1]} ${last.year}';
}
