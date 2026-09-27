import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'work_hours.dart';
import 'work_hours_editor.dart';
import 'work_hours_report.dart';
import 'work_hours_store.dart';
import 'work_hours_sync.dart';

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({
    super.key,
    required this.ownerId,
    required this.cloudMode,
  });
  final String ownerId;
  final bool cloudMode;
  @override
  State<WorkHoursScreen> createState() => WorkHoursScreenState();
}

class WorkHoursScreenState extends State<WorkHoursScreen>
    with WidgetsBindingObserver {
  WorkHoursStore? _store;
  WorkHoursSync? _remote;
  Timer? _timer;
  bool _syncing = false;
  String? _error;
  late DateTimeRange _range;
  bool _customRange = false;
  String? _workName;
  bool? _paid;
  int? _day;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _range = _month(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  DateTimeRange _month(DateTime date) => DateTimeRange(
    start: DateTime(date.year, date.month),
    end: DateTime(date.year, date.month + 1, 0),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _remote?.close();
    _store?.removeListener(_changed);
    _store?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorkHoursScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudMode != widget.cloudMode) {
      _remote?.close();
      _remote = null;
      if (widget.cloudMode) unawaited(_sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  Future<void> flush() async {
    await _store?.flushed;
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _store = WorkHoursStore(preferences, widget.ownerId)
        ..addListener(_changed);
      setState(() {});
      _timer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => unawaited(_sync()),
      );
      await _sync();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Nie udało się odczytać godzin. Nie nadpisano zapisanych danych.',
        );
      }
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      if (!_syncing) unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    if (!widget.cloudMode || _store == null || _syncing || !mounted) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      _remote ??= WorkHoursSync(Supabase.instance.client, _store!);
      await _remote!.synchronize();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Zapisano lokalnie. Synchronizacja niedostępna — sprawdź połączenie i konfigurację tabel Godzin.',
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  List<WorkEntry> get _periodEntries {
    final end = DateTime(_range.end.year, _range.end.month, _range.end.day + 1);
    return (_store?.entries ?? [])
        .where(
          (e) =>
              !e.date.isBefore(_range.start) &&
              e.date.isBefore(end) &&
              (_workName == null || e.name == _workName),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<WorkEntry> get _visible => _periodEntries
      .where(
        (e) =>
            (_paid == null || e.paid == _paid) &&
            (_day == null || e.date.day == _day),
      )
      .toList();
  String get _periodLabel => _customRange
      ? '${DateFormat('dd.MM.yyyy').format(_range.start)}–${DateFormat('dd.MM.yyyy').format(_range.end)}'
      : DateFormat('LLLL yyyy', 'pl_PL').format(_range.start);
  void _shiftMonth(int delta) => setState(() {
    _range = _month(DateTime(_range.start.year, _range.start.month + delta));
    _customRange = false;
    _day = null;
    _selected.clear();
  });

  Future<void> showAdd({WorkEntry? entry}) async {
    if (_store == null) return;
    final entries = _store!.entries
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkHoursEditor(
        entry: entry,
        previous: entries.firstOrNull,
        rateCents: _store!.rateCents,
        entries: entries,
        onSave: _store!.put,
      ),
    );
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value), duration: const Duration(seconds: 5)),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _message('Nie udało się zapisać zmiany. Spróbuj ponownie.');
    }
  }

  Future<void> _delete(WorkEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć wpis?'),
        content: Text(
          '${entry.name} · ${DateFormat('dd.MM.yyyy').format(entry.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _store!.remove(entry.id);
      if (!mounted) return;
      _selected.remove(entry.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usunięto wpis'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Cofnij',
            onPressed: () => unawaited(_run(() => _store!.restore(entry))),
          ),
        ),
      );
    });
  }

  Future<void> _rate() async {
    final controller = TextEditingController(
      text: (_store!.rateCents / 100).toStringAsFixed(2),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Domyślna stawka'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                onChanged: (_) => update(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'zł za godzinę'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dotyczy nowych wpisów. Poprzednie zachowają swoją stawkę.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: parseWorkRate(controller.text) == null
                  ? null
                  : () => Navigator.pop(ctx, parseWorkRate(controller.text)),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value != null) await _run(() => _store!.setRate(value));
  }

  Future<void> _report() async {
    final entries = List<WorkEntry>.from(_visible.reversed);
    var amounts = true;
    final action = await showDialog<(String, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Raport godzin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_periodLabel\n${entries.length} wpisów · bieżące filtry'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dołącz kwoty i status zapłaty'),
                value: amounts,
                onChanged: (v) => update(() => amounts = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ('copy', amounts)),
              child: const Text('Kopiuj tekst'),
            ),
            if (Platform.isAndroid)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ('share', amounts)),
                child: const Text('Udostępnij tekst'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ('pdf', amounts)),
              child: Text(Platform.isAndroid ? 'Udostępnij PDF' : 'Zapisz PDF'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      final text = workReportText(
        entries,
        _periodLabel,
        includeAmounts: action.$2,
      );
      if (action.$1 == 'copy') {
        await Clipboard.setData(ClipboardData(text: text));
        _message('Skopiowano raport');
      } else if (action.$1 == 'share') {
        await SharePlus.instance.share(ShareParams(text: text));
      } else {
        final bytes = await workReportPdf(
          entries,
          _periodLabel,
          includeAmounts: action.$2,
        );
        final name =
            'dniowka-godziny-${DateFormat('yyyy-MM-dd').format(_range.start)}.pdf';
        if (Platform.isAndroid) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
              fileNameOverrides: [name],
            ),
          );
        } else {
          final path = await FilePicker.saveFile(
            dialogTitle: 'Zapisz raport godzin',
            fileName: name,
            bytes: bytes,
            mimeType: 'application/pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (path != null) {
            _message('Zapisano PDF');
          }
        }
      }
    } catch (_) {
      _message('Nie udało się przygotować raportu. Spróbuj ponownie.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Text(_error!),
      );
    }
    if (_workName != null && !_store!.entries.any((e) => e.name == _workName)) {
      _workName = null;
    }
    final summary = WorkSummary(_periodEntries);
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 900 &&
            MediaQuery.textScalerOf(context).scale(16) <= 22;
        final totals = Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Do wypłaty'),
                const SizedBox(height: 8),
                Text(
                  workMoney(summary.outstandingCents),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 28,
                  runSpacing: 16,
                  children: [
                    _metric(workDuration(summary.minutes), 'Łącznie'),
                    _metric('${summary.days} dni', 'Dni pracy'),
                    _metric(workMoney(summary.totalCents), 'Należność'),
                    _metric(workMoney(summary.paidCents), 'Opłacone'),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('add-work-day'),
                      onPressed: () => showAdd(),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj dzień'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _report,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Raport'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return ListView(
          padding: EdgeInsets.all(desktop ? 28 : 16),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Godziny',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton.icon(
                  onPressed: _rate,
                  icon: const Icon(Icons.tune),
                  label: Text('Stawka: ${workMoney(_store!.rateCents)}/h'),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                IconButton(
                  tooltip: 'Poprzedni miesiąc',
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _range,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _range = picked;
                        _customRange = true;
                        _day = null;
                        _selected.clear();
                      });
                    }
                  },
                  child: Text(_periodLabel),
                ),
                IconButton(
                  tooltip: 'Następny miesiąc',
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                if (_customRange)
                  TextButton(
                    onPressed: () => _shiftMonth(0),
                    child: const Text('Cały miesiąc'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: totals),
                  if (!_customRange) ...[
                    const SizedBox(width: 16),
                    SizedBox(width: 330, child: _calendar()),
                  ],
                ],
              )
            else
              totals,
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _error != null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ??
                        (_syncing
                            ? 'Synchronizacja…'
                            : _store!.pending.isNotEmpty && widget.cloudMode
                            ? 'Zapisano lokalnie · czeka na synchronizację'
                            : widget.cloudMode
                            ? 'Zsynchronizowano'
                            : 'Zapisano lokalnie'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (widget.cloudMode)
                  IconButton(
                    tooltip: 'Ponów synchronizację',
                    onPressed: _syncing ? null : _sync,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_workName),
              initialValue: _workName == null ? '*' : 'name:$_workName',
              decoration: const InputDecoration(labelText: 'Nazwa pracy'),
              items: [
                const DropdownMenuItem(
                  value: '*',
                  child: Text('Wszystkie prace'),
                ),
                for (final name
                    in (_store!.entries.map((e) => e.name).toSet().toList()
                      ..sort()))
                  DropdownMenuItem(value: 'name:$name', child: Text(name)),
              ],
              onChanged: (value) => setState(() {
                _workName = value == '*' ? null : value?.substring(5);
                _selected.clear();
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in <(String, bool?)>[
                  ('Wszystkie', null),
                  ('Nieopłacone', false),
                  ('Opłacone', true),
                ])
                  ChoiceChip(
                    label: Text(option.$1),
                    selected: _paid == option.$2,
                    onSelected: (_) => setState(() {
                      _paid = option.$2;
                      _selected.clear();
                    }),
                  ),
              ],
            ),
            if (_day != null)
              TextButton(
                onPressed: () => setState(() => _day = null),
                child: Text('Dzień $_day · pokaż cały miesiąc'),
              ),
            const SizedBox(height: 18),
            Text(
              'Wpisy (${visible.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _run(() async {
                      for (final e in visible.where(
                        (e) => _selected.contains(e.id),
                      )) {
                        await _store!.put(e.withPaid(true));
                      }
                      if (mounted) setState(_selected.clear);
                    }),
                    child: Text('Oznacz opłacone (${_selected.length})'),
                  ),
                  TextButton(
                    onPressed: () => _run(() async {
                      for (final e in visible.where(
                        (e) => _selected.contains(e.id),
                      )) {
                        await _store!.put(e.withPaid(false));
                      }
                      if (mounted) setState(_selected.clear);
                    }),
                    child: const Text('Oznacz nieopłacone'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (desktop && visible.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('Data · praca · miejsce'),
                    ),
                    const Expanded(flex: 3, child: Text('Godziny / czas')),
                    const Expanded(flex: 2, child: Text('Kwota')),
                    const Expanded(flex: 2, child: Text('Status')),
                  ],
                ),
              ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _store!.entries.isEmpty
                      ? 'Dodaj pierwszy dzień pracy. Godziny i należność policzymy za Ciebie.'
                      : 'Brak wpisów w wybranym okresie i filtrach.',
                ),
              ),
            for (final entry in visible)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _selected.contains(entry.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(entry.id);
                          } else {
                            _selected.remove(entry.id);
                          }
                        }),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => showAdd(entry: entry),
                          child: desktop
                              ? Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${DateFormat('dd MMM', 'pl_PL').format(entry.date)} · ${entry.name}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          Text(
                                            entry.place,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${workTime(entry.startMinute)}–${workTime(entry.endMinute)}${entry.nextDay ? ' (+1)' : ''}',
                                          ),
                                          Text(
                                            workDuration(entry.workMinutes),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(workMoney(entry.amountCents)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        entry.paid ? 'Opłacone' : 'Nieopłacone',
                                        style: TextStyle(
                                          color: entry.paid
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateFormat('dd MMM', 'pl_PL').format(entry.date)} · ${entry.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    if (entry.place.isNotEmpty)
                                      Text(
                                        entry.place,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${workTime(entry.startMinute)}–${workTime(entry.endMinute)}${entry.nextDay ? ' (+1)' : ''} · ${workDuration(entry.workMinutes)} · ${workMoney(entry.amountCents)}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.paid ? 'Opłacone' : 'Nieopłacone',
                                      style: TextStyle(
                                        color: entry.paid
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Opcje wpisu',
                        onSelected: (action) {
                          if (action == 'edit') {
                            showAdd(entry: entry);
                          } else if (action == 'delete') {
                            _delete(entry);
                          } else {
                            _run(
                              () => _store!.put(entry.withPaid(!entry.paid)),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edytuj'),
                          ),
                          PopupMenuItem(
                            value: 'paid',
                            child: Text(
                              entry.paid
                                  ? 'Oznacz nieopłacone'
                                  : 'Oznacz opłacone',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Usuń'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _metric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
  Widget _calendar() {
    final month = _range.start;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday - 1;
    final days = _periodEntries.map((e) => e.date.day).toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(DateFormat('LLLL yyyy', 'pl_PL').format(month)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final name in ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'])
                  Expanded(
                    child: Center(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((length + offset + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > length) return const SizedBox.shrink();
                return Semantics(
                  button: true,
                  label:
                      '$day, ${days.contains(day) ? 'dzień pracy' : 'brak wpisów'}',
                  child: InkWell(
                    onTap: () => setState(() {
                      _day = _day == day ? null : day;
                      _selected.clear();
                    }),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: days.contains(day)
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        border: _day == day
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      child: Text('$day'),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
