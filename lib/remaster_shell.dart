import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'note_item.dart';
import 'task_item.dart';
import 'remaster_theme.dart';
import 'remaster_settings_screen.dart';
import 'suggestion_engine.dart';
import 'calendar_event.dart';
import 'calendar_store.dart';
import 'organizer_settings.dart';

enum AppSpace { start, tasks, notes, costs }

/// Shared shell. Data and mutations remain owned by the existing application.
class RemasterShell extends StatefulWidget {
  static void select(BuildContext context, AppSpace space) =>
      context.findAncestorStateOfType<_RemasterShellState>()?._select(space);
  const RemasterShell({
    super.key,
    required this.tasks,
    required this.notes,
    this.calendarEvents = const [],
    required this.tasksContent,
    required this.notesContent,
    this.costsContent = const SizedBox.shrink(),
    required this.onAddTask,
    required this.onAddNote,
    this.onAddCost,
    required this.onOpenTask,
    required this.onOpenNote,
    required this.onCompleteTask,
    required this.onOpenFocus,
    required this.onLegacy,
    required this.themeMode,
    required this.onThemeMode,
    required this.syncStatus,
    this.appVersion = '1.0.0',
    this.name,
    this.avatarUrl,
    this.onSignOut,
    this.onCheckForUpdate,
    this.updateCheckStatus,
    this.calendarConnected = false,
    this.calendarConnecting = false,
    this.calendarStatus = CalendarConnectionStatus.disconnected,
    this.calendarCachedEventCount = 0,
    this.calendarLastSyncedAt,
    this.onConnectCalendar,
    this.onChooseCalendars,
    this.onRefreshCalendar,
    this.onDisconnectCalendar,
    this.onManageTaskCategories,
    this.organizerSettings = const OrganizerSettings(),
    this.onOrganizerSettings,
    this.onTestReminder,
    this.notificationPermissionGranted,
    this.onOpenNotificationSettings,
    this.onRetrySync,
  });
  final List<TaskItem> tasks;
  final List<NoteItem> notes;
  final List<CalendarEvent> calendarEvents;
  final Widget tasksContent;
  final Widget notesContent;
  final Widget costsContent;
  final VoidCallback onAddTask, onAddNote, onLegacy;
  final VoidCallback? onAddCost;
  final ValueChanged<TaskItem> onOpenTask, onCompleteTask;
  final ValueChanged<TaskItem> onOpenFocus;
  final ValueChanged<NoteItem> onOpenNote;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final String syncStatus;
  final String appVersion;
  final String? name, avatarUrl;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onCheckForUpdate;
  final ValueListenable<String>? updateCheckStatus;
  final bool calendarConnected;
  final bool calendarConnecting;
  final CalendarConnectionStatus calendarStatus;
  final int calendarCachedEventCount;
  final DateTime? calendarLastSyncedAt;
  final VoidCallback? onConnectCalendar,
      onChooseCalendars,
      onRefreshCalendar,
      onDisconnectCalendar;
  final VoidCallback? onManageTaskCategories;
  final OrganizerSettings organizerSettings;
  final ValueChanged<OrganizerSettings>? onOrganizerSettings;
  final VoidCallback? onTestReminder;
  final bool? notificationPermissionGranted;
  final Future<void> Function()? onOpenNotificationSettings;
  final Future<void> Function()? onRetrySync;
  @override
  State<RemasterShell> createState() => _RemasterShellState();
}

class _RemasterShellState extends State<RemasterShell> {
  AppSpace _space = AppSpace.start;
  bool _railExpanded = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(AppSpace space) => setState(() => _space = space);

  void _add() {
    if (_space == AppSpace.tasks) {
      widget.onAddTask();
      return;
    }
    if (_space == AppSpace.notes) {
      widget.onAddNote();
      return;
    }
    if (_space == AppSpace.costs) {
      widget.onAddCost?.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_task_rounded),
                title: const Text('Nowe zadanie'),
                subtitle: const Text('Zapisz kolejny krok'),
                onTap: () {
                  Navigator.pop(sheet);
                  widget.onAddTask();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Nowa notatka'),
                subtitle: const Text('Zachowaj pomysł lub listę'),
                onTap: () {
                  Navigator.pop(sheet);
                  widget.onAddNote();
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Nowy koszt'),
                subtitle: const Text('Dodaj wydatek, wpływ lub subskrypcję'),
                onTap: () {
                  Navigator.pop(sheet);
                  widget.onAddCost?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _account() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RemasterSettingsScreen(
        name: widget.name,
        avatarUrl: widget.avatarUrl,
        appVersion: widget.appVersion,
        syncStatus: widget.syncStatus,
        themeMode: widget.themeMode,
        onThemeMode: widget.onThemeMode,
        onLegacy: widget.onLegacy,
        onSignOut: widget.onSignOut,
        onCheckForUpdate: widget.onCheckForUpdate,
        updateCheckStatus: widget.updateCheckStatus,
        calendarConnected: widget.calendarConnected,
        calendarConnecting: widget.calendarConnecting,
        calendarStatus: widget.calendarStatus,
        calendarCachedEventCount: widget.calendarCachedEventCount,
        calendarLastSyncedAt: widget.calendarLastSyncedAt,
        onConnectCalendar: widget.onConnectCalendar,
        onChooseCalendars: widget.onChooseCalendars,
        onRefreshCalendar: widget.onRefreshCalendar,
        onDisconnectCalendar: widget.onDisconnectCalendar,
        onManageTaskCategories: widget.onManageTaskCategories,
        organizerSettings: widget.organizerSettings,
        onOrganizerSettings: widget.onOrganizerSettings,
        onTestReminder: widget.onTestReminder,
        notificationPermissionGranted: widget.notificationPermissionGranted,
        onOpenNotificationSettings: widget.onOpenNotificationSettings,
      ),
    ),
  );

  void _showSuggestions() {
    final suggestions = const SuggestionEngine().build(
      widget.tasks,
      DateTime.now(),
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Podpowiedzi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'To są lokalne wskazówki — nic nie jest wysyłane do AI.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (suggestions.isEmpty)
                const ListTile(
                  leading: Icon(Icons.check_circle_outline_rounded),
                  title: Text('Plan wygląda spokojnie'),
                  subtitle: Text('Nie widzę teraz żadnej ważnej podpowiedzi.'),
                )
              else
                for (final suggestion in suggestions)
                  ListTile(
                    leading: const Icon(Icons.lightbulb_outline_rounded),
                    title: Text(suggestion.title),
                    subtitle: Text(suggestion.description),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _select(AppSpace.start);
          _searchFocus.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _add,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _search.clear();
          setState(() {});
          FocusManager.instance.primaryFocus?.unfocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final expanded = constraints.maxWidth >= 1100 || _railExpanded;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    if (!compact)
                      Container(
                        width: expanded ? 208 : 88,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          border: Border(
                            right: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                24,
                                16,
                                24,
                              ),
                              child: expanded
                                  ? Row(
                                      children: [
                                        const Icon(
                                          Icons.radio_button_checked_rounded,
                                          size: 25,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Dzień po dniu',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Icon(
                                      Icons.radio_button_checked_rounded,
                                      size: 25,
                                    ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    for (final space in AppSpace.values)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        child: _NavItem(
                                          label: _label(space),
                                          icon: _icon(space),
                                          expanded: expanded,
                                          selected: _space == space,
                                          onTap: () => _select(space),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (constraints.maxWidth < 1100)
                              IconButton(
                                tooltip: expanded
                                    ? 'Zwiń nawigację'
                                    : 'Rozwiń nawigację',
                                onPressed: () => setState(
                                  () => _railExpanded = !_railExpanded,
                                ),
                                icon: Icon(
                                  expanded
                                      ? Icons.chevron_left_rounded
                                      : Icons.chevron_right_rounded,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: _NavItem(
                                label: 'Konto i wygląd',
                                icon: Icons.tune_rounded,
                                expanded: expanded,
                                selected: false,
                                onTap: _account,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 20 : 32,
                              12,
                              compact ? 12 : 24,
                              4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _label(_space).toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          letterSpacing: 1.6,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                if (widget.onRetrySync != null &&
                                    (widget.syncStatus.contains('Błąd') ||
                                        widget.syncStatus.contains('czeka') ||
                                        widget.syncStatus.contains('Czeka')))
                                  IconButton(
                                    tooltip: 'Ponów synchronizację',
                                    onPressed: widget.onRetrySync,
                                    icon: const Icon(Icons.sync_rounded),
                                  )
                                else
                                  Tooltip(
                                    message: widget.syncStatus,
                                    child: Icon(
                                      widget.syncStatus.contains('Błąd')
                                          ? Icons.cloud_off_rounded
                                          : widget.syncStatus == 'Lokalnie'
                                          ? Icons.offline_pin_outlined
                                          : Icons.cloud_done_outlined,
                                      size: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Podpowiedzi',
                                  onPressed: _showSuggestions,
                                  icon: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Konto i wygląd',
                                  onPressed: _account,
                                  icon: _Avatar(
                                    name: widget.name,
                                    url: widget.avatarUrl,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: _space.index,
                              children: [
                                _home(context),
                                widget.tasksContent,
                                widget.notesContent,
                                widget.costsContent,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: compact
                  ? NavigationBar(
                      selectedIndex: _space.index,
                      onDestinationSelected: (value) =>
                          _select(AppSpace.values[value]),
                      destinations: [
                        for (final space in AppSpace.values)
                          NavigationDestination(
                            icon: Icon(_icon(space)),
                            label: _label(space),
                          ),
                      ],
                    )
                  : null,
              floatingActionButton: FloatingActionButton(
                tooltip: 'Dodaj',
                onPressed: _add,
                child: const Icon(Icons.add_rounded),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _home(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final query = _search.text.trim().toLowerCase();
    final active =
        widget.tasks
            .where(
              (t) => !t.isDone && (t.dueAt == null || t.dueAt!.isBefore(end)),
            )
            .toList()
          ..sort((a, b) {
            if (a.pinnedToday != b.pinnedToday) return a.pinnedToday ? -1 : 1;
            if (a.dueAt == null) return b.dueAt == null ? 0 : 1;
            if (b.dueAt == null) return -1;
            return a.dueAt!.compareTo(b.dueAt!);
          });
    final done = widget.tasks
        .where(
          (t) =>
              t.isDone &&
              t.completedAt != null &&
              DateUtils.isSameDay(t.completedAt, now),
        )
        .length;
    final visible =
        (query.isEmpty
                ? active
                : widget.tasks.where(
                    (t) => t.title.toLowerCase().contains(query),
                  ))
            .take(query.isEmpty ? 5 : 20)
            .toList();
    final recent =
        widget.notes
            .where(
              (n) =>
                  !n.isDeleted &&
                  !n.isArchived &&
                  (query.isEmpty ||
                      n.title.toLowerCase().contains(query) ||
                      n.previewText.toLowerCase().contains(query)),
            )
            .toList()
          ..sort(
            (a, b) => a.pinned != b.pinned
                ? (a.pinned ? -1 : 1)
                : b.updatedAt.compareTo(a.updatedAt),
          );
    final focus = active.firstOrNull;
    final upcomingCalendarEvents =
        widget.calendarEvents
            .where((event) => !event.cancelled && event.endsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final nextCalendarEvent = upcomingCalendarEvents.firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final columns =
            box.maxWidth >= 900 &&
            MediaQuery.textScalerOf(context).scale(16) <= 24;
        final plan = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: query.isEmpty ? 'Plan na dziś' : 'Zadania',
              action: 'Wszystkie',
              onTap: () => _select(AppSpace.tasks),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              _EmptyCard(
                title: query.isEmpty
                    ? 'Miejsce na Twój pierwszy krok'
                    : 'Brak pasujących zadań',
                subtitle: query.isEmpty
                    ? 'Dodaj jedną rzecz, którą chcesz zrobić.'
                    : 'Spróbuj innego hasła.',
                action: query.isEmpty
                    ? 'Dodaj zadanie'
                    : 'Wyczyść wyszukiwanie',
                onTap: query.isEmpty
                    ? widget.onAddTask
                    : () {
                        _search.clear();
                        setState(() {});
                      },
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(color: scheme.outlineVariant),
                        ),
                      _StartTask(
                        task: visible[i],
                        onOpen: () => widget.onOpenTask(visible[i]),
                        onComplete: () => widget.onCompleteTask(visible[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
        final noteCards = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Pod ręką',
              action: 'Notatki',
              onTap: () => _select(AppSpace.notes),
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              _EmptyCard(
                title: query.isEmpty
                    ? 'Pomysły mają tu swoje miejsce'
                    : 'Brak pasujących notatek',
                subtitle: query.isEmpty
                    ? 'Zapisz myśl, listę albo coś na później.'
                    : 'Zmień hasło wyszukiwania.',
                action: 'Utwórz notatkę',
                onTap: widget.onAddNote,
              )
            else
              for (var i = 0; i < recent.take(3).length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: remasterNoteColor(context, i),
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => widget.onOpenNote(recent[i]),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    recent[i].title.isEmpty
                                        ? 'Bez tytułu'
                                        : recent[i].title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                if (recent[i].pinned)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.push_pin_outlined,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                            if (recent[i].previewText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _noteExcerpt(recent[i]),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
        return SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            box.maxWidth < 600 ? 20 : 32,
            16,
            box.maxWidth < 600 ? 20 : 32,
            104,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(now, widget.name),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dzisiaj',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _date(now),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Znajdź zadanie lub notatkę',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Wyczyść wyszukiwanie',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (query.isEmpty) ...[
                    Material(
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                Theme.of(context).brightness == Brightness.dark
                                ? const [Color(0xff263c60), Color(0xff27384d)]
                                : const [Color(0xffdbe9ff), Color(0xffe3edf6)],
                          ),
                        ),
                        child: InkWell(
                          key: const ValueKey('remaster-now'),
                          onTap: focus == null
                              ? widget.onAddTask
                              : () => widget.onOpenFocus(focus),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.center_focus_strong_rounded,
                                            size: 18,
                                            color: scheme.onSurface,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'TERAZ',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(letterSpacing: 1.5),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        focus?.title ??
                                            'Zacznij od jednej rzeczy.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        focus == null
                                            ? 'Dodaj zadanie i nadaj kierunek swojemu dniu.'
                                            : focus.category,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Text(
                          '${active.length} do zrobienia',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          '$done ukończonych dzisiaj',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (nextCalendarEvent != null) ...[
                      const SizedBox(height: 16),
                      _NextCalendarEvent(event: nextCalendarEvent),
                    ],
                    const SizedBox(height: 32),
                  ],
                  if (columns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: plan),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: noteCards),
                      ],
                    )
                  else ...[
                    plan,
                    const SizedBox(height: 24),
                    noteCards,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NextCalendarEvent extends StatelessWidget {
  const _NextCalendarEvent({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = event.isAllDay
        ? 'Cały dzień'
        : '${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}–${event.endsAt.hour.toString().padLeft(2, '0')}:${event.endsAt.minute.toString().padLeft(2, '0')}';
    return Semantics(
      label: 'Następne wydarzenie: ${event.title}, $time',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.event_rounded, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Następne wydarzenie',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(time, style: TextStyle(color: scheme.onSecondaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool expanded, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          animationDuration: remasterMotion(context, 140),
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: expanded
                  ? Row(
                      children: [
                        Icon(
                          icon,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      icon,
                      semanticLabel: label,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartTask extends StatelessWidget {
  const _StartTask({
    required this.task,
    required this.onOpen,
    required this.onComplete,
  });
  final TaskItem task;
  final VoidCallback onOpen, onComplete;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: task.isDone ? 'Przywróć zadanie' : 'Ukończ zadanie',
            onPressed: onComplete,
            icon: Icon(
              task.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      const SizedBox(width: 8),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
  final String title, subtitle, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.url});
  final String? name, url;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: 30,
      height: 30,
      child: url != null && Uri.tryParse(url!)?.scheme == 'https'
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(context),
            )
          : _fallback(context),
    ),
  );
  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(
      child: Text(
        name?.trim().isNotEmpty == true
            ? name!.trim().characters.first.toUpperCase()
            : 'D',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    ),
  );
}

String _noteExcerpt(NoteItem note) {
  final preview = note.previewText;
  return note.title.isNotEmpty && preview.startsWith(note.title)
      ? preview.substring(note.title.length).trimLeft()
      : preview;
}

String _label(AppSpace space) => switch (space) {
  AppSpace.start => 'Start',
  AppSpace.tasks => 'Zadania',
  AppSpace.notes => 'Notatki',
  AppSpace.costs => 'Koszty',
};
IconData _icon(AppSpace space) => switch (space) {
  AppSpace.start => Icons.space_dashboard_outlined,
  AppSpace.tasks => Icons.check_circle_outline_rounded,
  AppSpace.notes => Icons.notes_rounded,
  AppSpace.costs => Icons.payments_outlined,
};
String _greeting(DateTime now, String? name) {
  final greeting = now.hour >= 18 ? 'Dobry wieczór' : 'Dzień dobry';
  return name == null || name.trim().isEmpty
      ? greeting
      : '$greeting, ${name.trim().split(' ').first}';
}

String _date(DateTime now) {
  const days = [
    'Poniedziałek',
    'Wtorek',
    'Środa',
    'Czwartek',
    'Piątek',
    'Sobota',
    'Niedziela',
  ];
  const months = [
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
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
}
