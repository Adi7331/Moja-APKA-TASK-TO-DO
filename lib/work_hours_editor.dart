import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'work_hours.dart';
import 'work_hours_report.dart';

class WorkHoursEditor extends StatefulWidget {
  const WorkHoursEditor({
    super.key,
    this.entry,
    this.previous,
    required this.rateCents,
    required this.entries,
    required this.onSave,
  });
  final WorkEntry? entry, previous;
  final int rateCents;
  final List<WorkEntry> entries;
  final Future<void> Function(WorkEntry) onSave;
  @override
  State<WorkHoursEditor> createState() => _WorkHoursEditorState();
}

class _WorkHoursEditorState extends State<WorkHoursEditor> {
  late final TextEditingController _name, _place, _break, _rate;
  late DateTime _date;
  late int _start, _end;
  bool _nextDay = false, _paid = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final source = widget.entry ?? widget.previous;
    _name = TextEditingController(text: source?.name ?? '');
    _place = TextEditingController(text: source?.place ?? '');
    _break = TextEditingController(text: '${widget.entry?.breakMinutes ?? 0}');
    _rate = TextEditingController(
      text: ((widget.entry?.rateCents ?? widget.rateCents) / 100)
          .toStringAsFixed(2),
    );
    _date = widget.entry?.date ?? DateTime.now();
    _start = source?.startMinute ?? 480;
    _end = source?.endMinute ?? 1020;
    _nextDay = widget.entry?.nextDay ?? false;
    _paid = widget.entry?.paid ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _place, _break, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  String _id() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  WorkEntry _draft() => WorkEntry(
    id: widget.entry?.id ?? _id(),
    date: DateTime(_date.year, _date.month, _date.day),
    name: _name.text.trim(),
    place: _place.text.trim(),
    startMinute: _start,
    endMinute: _end,
    breakMinutes: int.tryParse(_break.text) ?? -1,
    nextDay: _nextDay,
    rateCents: parseWorkRate(_rate.text) ?? -1,
    paid: _paid,
    updatedAt: DateTime.now().toUtc(),
  );
  Future<void> _save() async {
    final draft = _draft();
    final error = draft.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Nie udało się zapisać na urządzeniu. Spróbuj ponownie.';
        });
      }
    }
  }

  Future<void> _pickTime(bool start) async {
    final minute = start ? _start : _end;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (value != null && mounted) {
      setState(() {
        if (start) {
          _start = value.hour * 60 + value.minute;
        } else {
          _end = value.hour * 60 + value.minute;
        }
      });
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
    Set<String>? suggestions,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    maxLength: number ? 10 : 200,
    onChanged: (_) => setState(() {}),
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      suffixIcon: suggestions == null || suggestions.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Poprzednie wpisy',
              icon: const Icon(Icons.history),
              itemBuilder: (_) => suggestions
                  .map((s) => PopupMenuItem(value: s, child: Text(s)))
                  .toList(),
              onSelected: (s) => setState(() => controller.text = s),
            ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.entry == null ? 'Dodaj dzień' : 'Edytuj dzień',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('dd.MM.yyyy').format(_date)),
                onPressed: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) {
                          setState(() => _date = picked);
                        }
                      },
              ),
              const SizedBox(height: 12),
              _field(
                'Nazwa pracy',
                _name,
                suggestions: widget.entries.map((e) => e.name).toSet(),
              ),
              const SizedBox(height: 12),
              _field(
                'Miejscowość (opcjonalnie)',
                _place,
                suggestions: widget.entries
                    .map((e) => e.place)
                    .where((p) => p.isNotEmpty)
                    .toSet(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _pickTime(true),
                    icon: const Icon(Icons.schedule),
                    label: Text('Od ${workTime(_start)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _pickTime(false),
                    icon: const Icon(Icons.schedule),
                    label: Text('Do ${workTime(_end)}'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Koniec następnego dnia'),
                value: _nextDay,
                onChanged: _saving ? null : (v) => setState(() => _nextDay = v),
              ),
              _field('Przerwa bezpłatna (min)', _break, number: true),
              const SizedBox(height: 12),
              _field('Stawka (zł/h)', _rate, number: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opłacone'),
                value: _paid,
                onChanged: _saving ? null : (v) => setState(() => _paid = v),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    draft.validationError == null
                        ? '${workDuration(draft.workMinutes)} · ${workMoney(draft.amountCents)}'
                        : 'Uzupełnij dane — wyliczymy czas i kwotę',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Zapisywanie…' : 'Zapisz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
