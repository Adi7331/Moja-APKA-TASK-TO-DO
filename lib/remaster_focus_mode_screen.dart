import 'dart:async';

import 'package:flutter/material.dart';

import 'focus_session.dart';
import 'notification_service.dart';
import 'task_item.dart';

class RemasterFocusModeScreen extends StatefulWidget {
  const RemasterFocusModeScreen({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onPostpone,
    this.onSessionSaved,
    this.recentSessions = const [],
  });

  final TaskItem task;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;
  final ValueChanged<FocusSession>? onSessionSaved;
  final List<FocusSession> recentSessions;

  @override
  State<RemasterFocusModeScreen> createState() =>
      _RemasterFocusModeScreenState();
}

class _RemasterFocusModeScreenState extends State<RemasterFocusModeScreen> {
  FocusPlan _plan = const FocusPlan.pomodoro();
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _endsAt;
  Duration _remaining = const Duration(minutes: 25);
  var _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _selectPomodoro() => setState(() {
    _ticker?.cancel();
    _plan = const FocusPlan.pomodoro();
    _remaining = _plan.workDuration;
    _running = false;
    _startedAt = null;
    _endsAt = null;
  });

  Future<void> _selectCustom() async {
    final controller = TextEditingController(
      text: _plan.workDuration.inMinutes.toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Własny czas skupienia'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minuty pracy',
            helperText: 'Od 1 do 180 minut',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value?.clamp(1, 180));
            },
            child: const Text('Ustaw'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || !mounted) return;
    setState(() {
      _ticker?.cancel();
      _plan = FocusPlan(
        workDuration: Duration(minutes: minutes),
        breakDuration: const Duration(minutes: 5),
        label: 'Własny czas',
      );
      _remaining = _plan.workDuration;
      _running = false;
      _startedAt = null;
      _endsAt = null;
    });
  }

  void _start() {
    final now = DateTime.now();
    setState(() {
      _startedAt = now;
      _endsAt = now.add(_remaining);
      _running = true;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(
      NotificationService.instance.scheduleFocusSessionEnd(
        taskId: widget.task.id,
        title: widget.task.title,
        when: now.add(_remaining),
      ),
    );
  }

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final remaining = endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _finish(completed: true);
      return;
    }
    if (mounted) setState(() => _remaining = remaining);
  }

  void _finish({required bool completed}) {
    _ticker?.cancel();
    unawaited(NotificationService.instance.cancelFocusSession(widget.task.id));
    final startedAt = _startedAt;
    if (startedAt != null) {
      widget.onSessionSaved?.call(
        FocusSession(
          id: '${widget.task.id}-${startedAt.microsecondsSinceEpoch}',
          taskId: widget.task.id,
          startedAt: startedAt.toUtc(),
          endedAt: DateTime.now().toUtc(),
          plannedWorkSeconds: _plan.workDuration.inSeconds,
          completed: completed,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _startedAt = null;
      _endsAt = null;
      _remaining = _plan.workDuration;
    });
  }

  String get _clock {
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = _remaining.inHours;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final taskSessions = widget.recentSessions
        .where((session) => session.taskId == widget.task.id)
        .toList();
    final latestSession = taskSessions.isEmpty ? null : taskSessions.first;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 600 ? 24 : 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Zamknij skupienie',
                                onPressed: () {
                                  if (_running) _finish(completed: false);
                                  Navigator.of(context).maybePop();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Skupienie',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
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
                                      Icon(
                                        Icons.center_focus_strong_rounded,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'JEDNA RZECZ TERAZ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: scheme.onPrimaryContainer,
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    widget.task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                          height: 1.1,
                                        ),
                                  ),
                                  if (widget.task.note.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.task.note,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: scheme.onPrimaryContainer
                                                .withValues(alpha: .82),
                                            height: 1.5,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  Center(
                                    child: Text(
                                      _clock,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: scheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                key: const ValueKey('focus-pomodoro'),
                                label: const Text('Pomodoro 25 / 5'),
                                selected: _plan.label == 'Pomodoro 25 / 5',
                                onSelected: _running
                                    ? null
                                    : (_) => _selectPomodoro(),
                              ),
                              ChoiceChip(
                                key: const ValueKey('focus-custom'),
                                label: const Text('Własny czas'),
                                selected: _plan.label == 'Własny czas',
                                onSelected: _running
                                    ? null
                                    : (_) => _selectCustom(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const ValueKey('focus-start'),
                            onPressed: _running ? null : _start,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _running
                                  ? 'Sesja trwa'
                                  : 'Rozpocznij ${_plan.label.toLowerCase()}',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                          if (_running) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _finish(completed: false),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Zakończ sesję'),
                            ),
                          ],
                          if (latestSession != null) ...[
                            const SizedBox(height: 20),
                            _FocusHistoryCard(session: latestSession),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('remaster-focus-complete'),
                            onPressed: () {
                              if (_running) _finish(completed: true);
                              widget.onComplete();
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: const Text('Oznacz jako zrobione'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const ValueKey('remaster-focus-postpone'),
                            onPressed: () {
                              if (_running) _finish(completed: false);
                              widget.onPostpone();
                            },
                            icon: const Icon(Icons.snooze_rounded),
                            label: const Text('Odłóż na później'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusHistoryCard extends StatelessWidget {
  const _FocusHistoryCard({required this.session});
  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = (session.actualWorkSeconds / 60).round();
    final label = session.completed ? 'Ukończona' : 'Przerwana';
    return Semantics(
      label: 'Ostatnia sesja: $label, $minutes minut',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                session.completed
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ostatnia sesja',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text('$label · $minutes min'),
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
