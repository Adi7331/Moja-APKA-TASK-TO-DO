import 'package:flutter/material.dart';

import 'remaster_theme.dart';
import 'calendar_event.dart';
import 'task_item.dart';
import 'weekly_calendar.dart' show tasksByDay, weekDays;

class RemasterWeeklyCalendarScreen extends StatefulWidget {
  const RemasterWeeklyCalendarScreen({
    super.key,
    required this.tasks,
    this.calendarEvents = const [],
    required this.initialWeek,
    required this.onOpenTask,
    required this.onMoveTask,
    required this.onQuickAdd,
  });

  final List<TaskItem> tasks;
  final List<CalendarEvent> calendarEvents;
  final DateTime initialWeek;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, DateTime day) onMoveTask;
  final VoidCallback onQuickAdd;

  @override
  State<RemasterWeeklyCalendarScreen> createState() =>
      _RemasterWeeklyCalendarScreenState();
}

class _RemasterWeeklyCalendarScreenState
    extends State<RemasterWeeklyCalendarScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(widget.initialWeek);
    _selectedDay = _weekStart;
  }

  void _changeWeek(int offset) => setState(() {
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + offset * 7,
    );
    _selectedDay = _weekStart;
  });

  @override
  Widget build(BuildContext context) {
    final days = weekDays(_weekStart);
    final grouped = tasksByDay(widget.tasks, _weekStart);
    final calendarByDay = _calendarEventsByDay(widget.calendarEvents, days);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 760;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? 28 : 16,
                20,
                desktop ? 28 : 16,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    weekStart: _weekStart,
                    onPrevious: () => _changeWeek(-1),
                    onNext: () => _changeWeek(1),
                  ),
                  const SizedBox(height: 20),
                  if (!desktop) ...[
                    _DayPicker(
                      days: days,
                      selected: _selectedDay,
                      onSelected: (day) => setState(() => _selectedDay = day),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: remasterMotion(context, 180),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: desktop
                          ? _DesktopWeek(
                              key: ValueKey(_weekStart),
                              days: days,
                              grouped: grouped,
                              calendarByDay: calendarByDay,
                              onOpen: widget.onOpenTask,
                              onMove: widget.onMoveTask,
                              onAdd: widget.onQuickAdd,
                            )
                          : _MobileDay(
                              key: ValueKey(_selectedDay),
                              day: _selectedDay,
                              tasks: grouped[_selectedDay] ?? const [],
                              calendarEvents:
                                  calendarByDay[_selectedDay] ?? const [],
                              allDays: days,
                              onOpen: widget.onOpenTask,
                              onMove: widget.onMoveTask,
                              onAdd: widget.onQuickAdd,
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
}

class _Header extends StatelessWidget {
  const _Header({
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
      IconButton(
        tooltip: 'Wróć',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tydzień', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              _range(weekStart),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Poprzedni tydzień',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      IconButton(
        tooltip: 'Następny tydzień',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.days,
    required this.selected,
    required this.onSelected,
  });
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) => Row(
    children: days.map((day) {
      final active = _sameDay(day, selected);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Semantics(
            selected: active,
            button: true,
            label: _dayFull(day),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(day),
              child: AnimatedContainer(
                duration: remasterMotion(context, 120),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekday(day),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _DesktopWeek extends StatelessWidget {
  const _DesktopWeek({
    super.key,
    required this.days,
    required this.grouped,
    required this.calendarByDay,
    required this.onOpen,
    required this.onMove,
    required this.onAdd,
  });
  final List<DateTime> days;
  final Map<DateTime, List<TaskItem>> grouped;
  final Map<DateTime, List<CalendarEvent>> calendarByDay;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem, DateTime) onMove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: days
        .map(
          (day) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DayColumn(
                day: day,
                tasks: grouped[day] ?? const [],
                calendarEvents: calendarByDay[day] ?? const [],
                allDays: days,
                onOpen: onOpen,
                onMove: onMove,
                onAdd: onAdd,
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _MobileDay extends StatelessWidget {
  const _MobileDay({
    super.key,
    required this.day,
    required this.tasks,
    required this.calendarEvents,
    required this.allDays,
    required this.onOpen,
    required this.onMove,
    required this.onAdd,
  });
  final DateTime day;
  final List<TaskItem> tasks;
  final List<CalendarEvent> calendarEvents;
  final List<DateTime> allDays;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem, DateTime) onMove;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => _DayColumn(
    day: day,
    tasks: tasks,
    calendarEvents: calendarEvents,
    allDays: allDays,
    onOpen: onOpen,
    onMove: onMove,
    onAdd: onAdd,
  );
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.tasks,
    required this.calendarEvents,
    required this.allDays,
    required this.onOpen,
    required this.onMove,
    required this.onAdd,
  });
  final DateTime day;
  final List<TaskItem> tasks;
  final List<CalendarEvent> calendarEvents;
  final List<DateTime> allDays;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem, DateTime) onMove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dayFull(day), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Expanded(
              child: tasks.isEmpty && calendarEvents.isEmpty
                  ? Center(
                      child: Text(
                        'Bez planów',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final event in calendarEvents) ...[
                          _CalendarBlock(event: event),
                          const SizedBox(height: 8),
                        ],
                        for (final task in tasks) ...[
                          _WeekTask(
                            task: task,
                            days: allDays,
                            onOpen: onOpen,
                            onMove: onMove,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekTask extends StatelessWidget {
  const _WeekTask({
    required this.task,
    required this.days,
    required this.onOpen,
    required this.onMove,
  });
  final TaskItem task;
  final List<DateTime> days;
  final ValueChanged<TaskItem> onOpen;
  final void Function(TaskItem, DateTime) onMove;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onOpen(task),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              task.isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<DateTime>(
              tooltip: 'Przenieś zadanie',
              onSelected: (day) => onMove(task, day),
              itemBuilder: (context) => days
                  .map(
                    (day) =>
                        PopupMenuItem(value: day, child: Text(_dayFull(day))),
                  )
                  .toList(),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CalendarBlock extends StatelessWidget {
  const _CalendarBlock({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Wydarzenie z Google Calendar: ${event.title}, ${_eventTime(event)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.secondary.withValues(alpha: .45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: scheme.onSecondaryContainer,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eventTime(event),
                      style: TextStyle(
                        color: scheme.onSecondaryContainer.withValues(
                          alpha: .8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _monday(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _weekday(DateTime day) =>
    const ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'][day.weekday - 1];
String _dayFull(DateTime day) =>
    '${_weekday(day)}, ${day.day}.${day.month.toString().padLeft(2, '0')}';
String _range(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  return '${monday.day}.${monday.month.toString().padLeft(2, '0')} – ${sunday.day}.${sunday.month.toString().padLeft(2, '0')}';
}

Map<DateTime, List<CalendarEvent>> _calendarEventsByDay(
  List<CalendarEvent> events,
  List<DateTime> days,
) {
  final result = <DateTime, List<CalendarEvent>>{
    for (final day in days) day: [],
  };
  for (final event in events) {
    for (final day in days) {
      if (_sameDay(event.startsAt, day)) result[day]!.add(event);
    }
  }
  for (final eventsForDay in result.values) {
    eventsForDay.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }
  return result;
}

String _eventTime(CalendarEvent event) {
  if (event.isAllDay) return 'Cały dzień';
  String format(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '${format(event.startsAt)}–${format(event.endsAt)}';
}
