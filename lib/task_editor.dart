import 'package:flutter/material.dart';

import 'subtask_item.dart';
import 'repeat_rule.dart';
import 'task_item.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.note,
    required this.category,
    required this.priority,
    required this.dueAt,
    required this.reminderAt,
    required this.repeatRule,
    required this.subtasks,
  });

  final String title;
  final String note;
  final String category;
  final String priority;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final RepeatRule? repeatRule;
  final List<SubtaskItem> subtasks;
}

Future<void> showTaskEditor(
  BuildContext context, {
  TaskItem? task,
  bool remastered = false,
  required Future<void> Function(TaskDraft draft) onSave,
}) {
  final form = _TaskEditorForm(
    task: task,
    onSave: onSave,
    remastered: remastered,
  );
  if (MediaQuery.sizeOf(context).width >= 720) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: remastered ? 580 : 440),
          child: form,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: remastered,
    useSafeArea: remastered,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: form,
    ),
  );
}

class _TaskEditorForm extends StatefulWidget {
  const _TaskEditorForm({
    required this.task,
    required this.onSave,
    required this.remastered,
  });
  final TaskItem? task;
  final Future<void> Function(TaskDraft draft) onSave;
  final bool remastered;

  @override
  State<_TaskEditorForm> createState() => _TaskEditorFormState();
}

class _TaskEditorFormState extends State<_TaskEditorForm> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  final _newStep = TextEditingController();
  late String _category;
  late String _priority;
  late DateTime? _dueAt;
  late DateTime? _reminderAt;
  late RepeatRule? _repeatRule;
  late List<SubtaskItem> _subtasks;
  var _showMore = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _note = TextEditingController(text: widget.task?.note ?? '');
    _category = widget.task?.category ?? 'Skrzynka';
    _priority = widget.task?.priority ?? 'medium';
    _dueAt = widget.task?.dueAt;
    _reminderAt = widget.task?.reminderAt;
    _repeatRule = widget.task?.repeatRule;
    _subtasks = List<SubtaskItem>.from(widget.task?.subtasks ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _newStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          key: widget.remastered
              ? const ValueKey('remaster-task-editor')
              : null,
          padding: EdgeInsets.fromLTRB(
            widget.remastered ? 24 : 20,
            widget.remastered ? 24 : 20,
            widget.remastered ? 24 : 20,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                if (widget.remastered) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.add_task_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task == null ? 'Nowe zadanie' : 'Edytuj zadanie',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (widget.remastered) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Następny krok',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zamknij',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ]),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('task-title-input'),
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tytuł'),
              ),
              const SizedBox(height: 14),
              Text('Termin', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDueDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_dueLabel()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    key: const ValueKey('due-today'),
                    avatar: const Icon(Icons.today_outlined, size: 17),
                    label: const Text('Na dziś'),
                    onPressed: _saving ? null : () => _setQuickDueDate(0),
                  ),
                  ActionChip(
                    key: const ValueKey('due-tomorrow'),
                    avatar: const Icon(Icons.wb_sunny_outlined, size: 17),
                    label: const Text('Jutro'),
                    onPressed: _saving ? null : () => _setQuickDueDate(1),
                  ),
                  ActionChip(
                    key: const ValueKey('due-none'),
                    avatar: const Icon(Icons.event_busy_outlined, size: 17),
                    label: const Text('Bez terminu'),
                    onPressed: _saving ? null : () => setState(() => _dueAt = null),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Małe kroki', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ..._subtasks.map(_stepRow),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('subtask-input'),
                    controller: _newStep,
                    decoration: const InputDecoration(hintText: 'Dodaj krok'),
                    onSubmitted: (_) => _addStep(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('add-subtask'),
                  tooltip: 'Dodaj krok',
                  onPressed: _saving ? null : _addStep,
                  icon: const Icon(Icons.add),
                ),
              ]),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                label: Text(_showMore ? 'Mniej opcji' : 'Więcej opcji'),
              ),
              if (_showMore) ...[
                Column(children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Kategoria'),
                    items: const [
                      DropdownMenuItem(value: 'Skrzynka', child: Text('Skrzynka')),
                      DropdownMenuItem(value: 'Praca', child: Text('Praca')),
                      DropdownMenuItem(value: 'Dom', child: Text('Dom')),
                    ],
                    onChanged: _saving ? null : (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priorytet'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Niski')),
                      DropdownMenuItem(value: 'medium', child: Text('Średni')),
                      DropdownMenuItem(value: 'high', child: Text('Wysoki')),
                    ],
                    onChanged: _saving ? null : (value) => setState(() => _priority = value!),
                  ),
                  const SizedBox(height: 14),
                  Text('Powtarzanie', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    ChoiceChip(key: const ValueKey('repeat-none'), label: const Text('Nie powtarzaj'), selected: _repeatRule == null, onSelected: _saving ? null : (_) => setState(() => _repeatRule = null)),
                    ChoiceChip(key: const ValueKey('repeat-daily'), label: const Text('Codziennie'), selected: _repeatRule?.unit == RepeatUnit.day, onSelected: _saving ? null : (_) => setState(() => _repeatRule = const RepeatRule.daily())),
                    ChoiceChip(key: const ValueKey('repeat-weekly'), label: const Text('Co tydzień'), selected: _repeatRule?.unit == RepeatUnit.week, onSelected: _saving ? null : (_) => setState(() => _repeatRule = const RepeatRule(unit: RepeatUnit.week))),
                    ChoiceChip(key: const ValueKey('repeat-monthly'), label: const Text('Co miesiąc'), selected: _repeatRule?.unit == RepeatUnit.month, onSelected: _saving ? null : (_) => setState(() => _repeatRule = const RepeatRule(unit: RepeatUnit.month))),
                  ]),
                  const SizedBox(height: 14),
                  Text('Przypomnienie', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    ChoiceChip(key: const ValueKey('reminder-none'), label: const Text('Brak'), selected: _reminderAt == null, onSelected: _saving ? null : (_) => setState(() => _reminderAt = null)),
                    ChoiceChip(key: const ValueKey('reminder-due'), label: const Text('W terminie'), selected: _reminderAt != null && _reminderAt == _dueAt, onSelected: _saving ? null : (_) => setState(() => _reminderAt = _dueAt)),
                  ]),
                ]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(widget.task == null ? Icons.add : Icons.save),
                label: Text(widget.task == null ? 'Dodaj zadanie' : 'Zapisz zmiany'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _stepRow(SubtaskItem step) => Row(children: [
        Checkbox(
          value: step.isDone,
          onChanged: _saving
              ? null
              : (isDone) => setState(() {
                    _subtasks = _subtasks
                        .map((item) => item.id == step.id
                            ? SubtaskItem(id: item.id, title: item.title, isDone: isDone ?? false, position: item.position)
                            : item)
                        .toList();
                  }),
        ),
        Expanded(child: Text(step.title)),
        IconButton(
          tooltip: 'Usuń krok',
          onPressed: _saving ? null : () => setState(() => _subtasks = _subtasks.where((item) => item.id != step.id).toList()),
          icon: const Icon(Icons.close),
        ),
      ]);

  void _addStep() {
    final title = _newStep.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks = [
        ..._subtasks,
        SubtaskItem(
          id: 'step-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          isDone: false,
          position: _subtasks.length,
        ),
      ];
      _newStep.clear();
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dueAt ?? DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (time == null || !mounted) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _setQuickDueDate(int dayOffset) {
    final now = DateTime.now();
    setState(
      () => _dueAt = DateTime(now.year, now.month, now.day + dayOffset, 9),
    );
  }

  String _dueLabel() {
    if (_dueAt == null) return 'Dodaj termin i godzinę';
    final dueAt = _dueAt!;
    return '${dueAt.day.toString().padLeft(2, '0')}.${dueAt.month.toString().padLeft(2, '0')}.${dueAt.year} · ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Podaj tytuł zadania.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(TaskDraft(
        title: _title.text.trim(),
        note: _note.text.trim(),
        category: _category,
        priority: _priority,
        dueAt: _dueAt,
        reminderAt: _reminderAt,
        repeatRule: _repeatRule,
        subtasks: _subtasks,
      ));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Nie udało się zsynchronizować. Spróbuj ponownie.';
        });
      }
    }
  }
}
