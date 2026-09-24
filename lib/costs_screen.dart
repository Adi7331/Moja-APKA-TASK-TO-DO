import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cost_dashboard.dart';
import 'cost_forecast_preferences.dart';
import 'cost_item.dart';
import 'cost_overview.dart';
import 'cost_sync_outbox.dart';
import 'cost_sync_service.dart';
import 'local_cost_store.dart';
import 'notification_service.dart';

enum _CostsSection { overview, subscriptions, history }

enum _NewCostKind { expense, income, subscription }

class CostsSectionPicker extends StatelessWidget {
  const CostsSectionPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labels = ['Przegląd', 'Subskrypcje', 'Historia'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (largeText || constraints.maxWidth < 290) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _labels.length; index++)
                ChoiceChip(
                  label: Text(_labels[index], maxLines: 1, softWrap: false),
                  selected: selectedIndex == index,
                  onSelected: (_) => onSelected(index),
                ),
            ],
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                for (var index = 0; index < _labels.length; index++)
                  Expanded(
                    child: Semantics(
                      selected: selectedIndex == index,
                      button: true,
                      child: Material(
                        color: selectedIndex == index
                            ? scheme.secondaryContainer
                            : scheme.surface,
                        child: InkWell(
                          onTap: () => onSelected(index),
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                _labels[index],
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CostsScreen extends StatefulWidget {
  const CostsScreen({
    super.key,
    required this.cloudMode,
    required this.ownerId,
    this.onSnapshotChanged,
  });

  final bool cloudMode;
  final String ownerId;
  final ValueChanged<CostSnapshot>? onSnapshotChanged;

  @override
  State<CostsScreen> createState() => CostsScreenState();
}

class CostsScreenState extends State<CostsScreen> {
  CostSnapshot _snapshot = const CostSnapshot();
  LocalCostStore? _store;
  CostSyncOutbox? _outbox;
  CostForecastPreferenceStore? _forecastPreferences;
  late final CostSyncService _sync = CostSyncService(Supabase.instance.client);
  final List<StreamSubscription<List<Map<String, dynamic>>>> _streams = [];
  _CostsSection _section = _CostsSection.overview;
  bool _loading = true;
  bool _syncAvailable = false;
  String _syncLabel = 'Lokalnie';
  CostForecastMode _forecastMode = CostForecastMode.allOccurrences;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant CostsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudMode != widget.cloudMode && widget.cloudMode) {
      unawaited(_connectCloud());
    }
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalCostStore(prefs, ownerId: widget.ownerId);
    final snapshot = await store.load();
    final forecastPreferences = CostForecastPreferenceStore(prefs);
    if (!mounted) return;
    setState(() {
      _store = store;
      _outbox = CostSyncOutbox(prefs, ownerId: widget.ownerId);
      _forecastPreferences = forecastPreferences;
      _forecastMode = forecastPreferences.load();
      _snapshot = snapshot;
      _loading = false;
    });
    widget.onSnapshotChanged?.call(snapshot);
    if (widget.cloudMode) await _connectCloud();
  }

  Future<void> _connectCloud() async {
    if (!widget.cloudMode || _outbox == null) return;
    if (mounted) setState(() => _syncLabel = 'Synchronizowanie…');
    try {
      await _flushOutbox();
      final remote = await _sync.load();
      await _applyRemotePreservingPending(remote);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('Brak konta');
      await _cancelStreams();
      for (final table in [
        'cost_entries',
        'cost_subscriptions',
        'cost_categories',
      ]) {
        _streams.add(
          Supabase.instance.client
              .from(table)
              .stream(primaryKey: ['id'])
              .eq('user_id', user.id)
              .listen((_) => unawaited(_refreshRemote())),
        );
      }
      if (!mounted) return;
      setState(() {
        _syncAvailable = true;
        _syncLabel = 'Zsynchronizowano';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncAvailable = false;
        _syncLabel = 'Lokalnie · uruchom costs.sql, aby włączyć synchronizację';
      });
    }
  }

  Future<void> _refreshRemote() async {
    try {
      final remote = await _sync.load();
      await _applyRemotePreservingPending(remote);
      if (mounted) setState(() => _syncLabel = 'Zsynchronizowano');
    } catch (_) {
      if (mounted) setState(() => _syncLabel = 'Offline · zapis lokalny');
    }
  }

  Future<void> _applyRemotePreservingPending(CostSnapshot remote) async {
    final pending = await _outbox?.load() ?? const <PendingCostSync>[];
    final entries = {for (final item in remote.entries) item.id: item};
    final subscriptions = {
      for (final item in remote.subscriptions) item.id: item,
    };
    final categories = {for (final item in remote.categories) item.id: item};
    for (final operation in pending) {
      switch (operation.entity) {
        case CostSyncEntity.entry:
          entries.remove(operation.id);
          if (!operation.isDelete) {
            entries[operation.id] = CostEntry.fromStorage(operation.payload);
          }
        case CostSyncEntity.subscription:
          subscriptions.remove(operation.id);
          if (!operation.isDelete) {
            subscriptions[operation.id] = CostSubscription.fromStorage(
              operation.payload,
            );
          }
        case CostSyncEntity.category:
          categories.remove(operation.id);
          if (!operation.isDelete) {
            categories[operation.id] = CostCategory.fromStorage(
              operation.payload,
            );
          }
      }
    }
    final snapshot = CostSnapshot(
      entries: entries.values.toList(),
      subscriptions: subscriptions.values.toList(),
      categories: categories.values.toList(),
    );
    await _store?.save(snapshot);
    if (mounted) {
      setState(() => _snapshot = snapshot);
      widget.onSnapshotChanged?.call(snapshot);
    }
  }

  Future<void> _flushOutbox() async {
    final outbox = _outbox;
    if (outbox == null) return;
    for (final operation in await outbox.load()) {
      try {
        if (operation.isDelete) {
          await _sync.delete(operation.entity, operation.id);
        } else {
          switch (operation.entity) {
            case CostSyncEntity.entry:
              await _sync.saveEntry(CostEntry.fromStorage(operation.payload));
            case CostSyncEntity.subscription:
              await _sync.saveSubscription(
                CostSubscription.fromStorage(operation.payload),
              );
            case CostSyncEntity.category:
              await _sync.saveCategory(
                CostCategory.fromStorage(operation.payload),
              );
          }
        }
        await outbox.remove(operation.entity, operation.id);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _saveSnapshot(
    CostSnapshot snapshot, {
    required CostSyncEntity entity,
    required String id,
    Map<String, dynamic>? payload,
  }) async {
    await _store?.save(snapshot);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _syncLabel = 'Zapisano lokalnie';
    });
    widget.onSnapshotChanged?.call(snapshot);
    final outbox = _outbox;
    if (outbox == null) return;
    try {
      final syncPayload = payload;
      if (syncPayload == null) {
        await outbox.enqueueDelete(entity: entity, id: id);
      } else {
        await outbox.enqueue(entity: entity, id: id, payload: syncPayload);
      }
      if (widget.cloudMode) {
        await _flushOutbox();
        final pending = await outbox.load();
        if (pending.isEmpty && _syncAvailable) {
          if (mounted) setState(() => _syncLabel = 'Zsynchronizowano');
        } else if (mounted) {
          setState(() => _syncLabel = 'Lokalnie · czeka na synchronizację');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _syncLabel = 'Offline · zapis lokalny');
    }
  }

  void showAddChooser() {
    showModalBottomSheet<_NewCostKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kindTile(
                context,
                _NewCostKind.expense,
                Icons.shopping_bag_outlined,
                'Wydatek',
                'Zakup lub rachunek',
              ),
              _kindTile(
                context,
                _NewCostKind.subscription,
                Icons.autorenew_rounded,
                'Subskrypcja',
                'Cykliczna płatność',
              ),
              _kindTile(
                context,
                _NewCostKind.income,
                Icons.south_west_rounded,
                'Wpływ',
                'Wynagrodzenie lub inny przychód',
              ),
            ],
          ),
        ),
      ),
    ).then((kind) {
      if (kind != null && mounted) unawaited(_openEditor(kind));
    });
  }

  ListTile _kindTile(
    BuildContext context,
    _NewCostKind kind,
    IconData icon,
    String title,
    String subtitle,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: () => Navigator.pop(context, kind),
  );

  Future<void> _openEditor(
    _NewCostKind kind, {
    CostSubscription? editing,
  }) async {
    final draft = await showDialog<_CostDraft>(
      context: context,
      builder: (_) => _CostEditorDialog(
        kind: kind,
        categories: _snapshot.categories,
        existing: editing,
      ),
    );
    if (draft == null) return;
    final now = DateTime.now();
    if (kind == _NewCostKind.subscription) {
      final subscription = CostSubscription(
        id: editing?.id ?? _newUuid(),
        name: draft.title,
        amountCents: draft.amountCents,
        cycle: draft.cycle,
        nextPaymentAt: draft.date,
        categoryId: draft.categoryId,
        reminderDays: draft.reminderDays,
        active: true,
        createdAt: editing?.createdAt ?? now,
        updatedAt: now,
      );
      final next = [..._snapshot.subscriptions]
        ..removeWhere((item) => item.id == subscription.id)
        ..add(subscription);
      await _saveSnapshot(
        CostSnapshot(
          entries: _snapshot.entries,
          subscriptions: next,
          categories: _snapshot.categories,
        ),
        entity: CostSyncEntity.subscription,
        id: subscription.id,
        payload: subscription.toStorage(),
      );
      await _scheduleSubscriptionReminders(subscription);
      return;
    }
    final entry = CostEntry(
      id: _newUuid(),
      title: draft.title,
      amountCents: draft.amountCents,
      type: kind == _NewCostKind.income
          ? CostEntryType.income
          : CostEntryType.expense,
      status: kind == _NewCostKind.income || draft.paid
          ? CostEntryStatus.paid
          : CostEntryStatus.planned,
      occurredAt: draft.date,
      categoryId: draft.categoryId,
      note: draft.note,
      createdAt: now,
      updatedAt: now,
    );
    await _saveSnapshot(
      CostSnapshot(
        entries: [..._snapshot.entries, entry],
        subscriptions: _snapshot.subscriptions,
        categories: _snapshot.categories,
      ),
      entity: CostSyncEntity.entry,
      id: entry.id,
      payload: entry.toStorage(),
    );
  }

  Future<void> _scheduleSubscriptionReminders(
    CostSubscription subscription,
  ) async {
    final notifications = NotificationService.instance;
    await notifications.cancelCostReminders(subscription.id);
    if (subscription.reminderDays.isEmpty) return;
    if (!await notifications.requestPermissions()) return;
    for (final days in subscription.reminderDays) {
      final date = subscription.nextPaymentAt.subtract(Duration(days: days));
      final when = DateTime(date.year, date.month, date.day, 9);
      if (when.isAfter(DateTime.now())) {
        await notifications.scheduleCostReminder(
          id: subscription.id,
          title: subscription.name,
          amountCents: subscription.amountCents,
          when: when,
          daysBefore: days,
        );
      }
    }
  }

  Future<void> _markPaid(UpcomingCostPayment payment) async {
    if (payment.isSubscription) {
      final subscription = _snapshot.subscriptions
          .where((item) => item.id == payment.id)
          .firstOrNull;
      if (subscription == null) return;
      final now = DateTime.now();
      final paid = CostEntry(
        id: _newUuid(),
        title: subscription.name,
        amountCents: subscription.amountCents,
        type: CostEntryType.expense,
        status: CostEntryStatus.paid,
        occurredAt: now,
        categoryId: subscription.categoryId,
        subscriptionId: subscription.id,
        createdAt: now,
        updatedAt: now,
      );
      final updatedSubscription = CostSubscription(
        id: subscription.id,
        name: subscription.name,
        amountCents: subscription.amountCents,
        cycle: subscription.cycle,
        nextPaymentAt: nextBillingDate(
          subscription.nextPaymentAt,
          subscription.cycle,
        ),
        categoryId: subscription.categoryId,
        reminderDays: subscription.reminderDays,
        active: subscription.active,
        createdAt: subscription.createdAt,
        updatedAt: now,
      );
      await _saveSnapshot(
        CostSnapshot(
          entries: [..._snapshot.entries, paid],
          subscriptions: [
            for (final item in _snapshot.subscriptions)
              if (item.id == subscription.id) updatedSubscription else item,
          ],
          categories: _snapshot.categories,
        ),
        entity: CostSyncEntity.entry,
        id: paid.id,
        payload: paid.toStorage(),
      );
      await _saveSnapshot(
        _snapshot,
        entity: CostSyncEntity.subscription,
        id: updatedSubscription.id,
        payload: updatedSubscription.toStorage(),
      );
      await _scheduleSubscriptionReminders(updatedSubscription);
    } else {
      final entry = _snapshot.entries
          .where((item) => item.id == payment.id)
          .firstOrNull;
      if (entry == null) return;
      final updated = CostEntry(
        id: entry.id,
        title: entry.title,
        amountCents: entry.amountCents,
        type: entry.type,
        status: CostEntryStatus.paid,
        occurredAt: entry.occurredAt,
        categoryId: entry.categoryId,
        subscriptionId: entry.subscriptionId,
        note: entry.note,
        createdAt: entry.createdAt,
        updatedAt: DateTime.now(),
      );
      await _saveSnapshot(
        CostSnapshot(
          entries: [
            for (final item in _snapshot.entries)
              if (item.id == entry.id) updated else item,
          ],
          subscriptions: _snapshot.subscriptions,
          categories: _snapshot.categories,
        ),
        entity: CostSyncEntity.entry,
        id: updated.id,
        payload: updated.toStorage(),
      );
    }
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Kategorie kosztów'),
                  trailing: IconButton.filledTonal(
                    tooltip: 'Dodaj kategorię',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_editCategory());
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                if (_snapshot.categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nie masz jeszcze własnych kategorii.'),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final category in _snapshot.categories)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(category.colorValue),
                              child: Text(category.emoji ?? '•'),
                            ),
                            title: Text(category.name),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Opcje kategorii',
                              onSelected: (action) {
                                Navigator.pop(sheetContext);
                                if (action == 'edit') {
                                  unawaited(_editCategory(category));
                                } else {
                                  unawaited(_deleteCategory(category));
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Zmień nazwę lub emoji'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Usuń kategorię'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editCategory([CostCategory? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final emoji = TextEditingController(text: existing?.emoji ?? '');
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Nowa kategoria' : 'Edytuj kategorię'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Nazwa'),
            ),
            TextField(
              controller: emoji,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Emoji (opcjonalnie)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              name.text.trim(),
              emoji.text.trim().isEmpty ? null : emoji.text.trim(),
            )),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    name.dispose();
    emoji.dispose();
    if (result == null || result.$1.isEmpty) return;
    final now = DateTime.now();
    final category = CostCategory(
      id: existing?.id ?? _newUuid(),
      name: result.$1,
      emoji: result.$2,
      colorValue: existing?.colorValue ?? 0xFF2F6FED,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final categories = [..._snapshot.categories]
      ..removeWhere((item) => item.id == category.id)
      ..add(category);
    await _saveSnapshot(
      CostSnapshot(
        entries: _snapshot.entries,
        subscriptions: _snapshot.subscriptions,
        categories: categories,
      ),
      entity: CostSyncEntity.category,
      id: category.id,
      payload: category.toStorage(),
    );
  }

  Future<void> _deleteCategory(CostCategory category) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usunąć kategorię?'),
        content: const Text(
          'Powiązane wpisy i subskrypcje zostaną zachowane jako „Bez kategorii”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Usuń kategorię'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final linkedEntries = _snapshot.entries
        .where((item) => item.categoryId == category.id)
        .toList();
    final linkedSubscriptions = _snapshot.subscriptions
        .where((item) => item.categoryId == category.id)
        .toList();
    final entries = [
      for (final item in _snapshot.entries)
        if (item.categoryId == category.id)
          CostEntry(
            id: item.id,
            title: item.title,
            amountCents: item.amountCents,
            type: item.type,
            status: item.status,
            occurredAt: item.occurredAt,
            categoryId: null,
            subscriptionId: item.subscriptionId,
            note: item.note,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          item,
    ];
    final subscriptions = [
      for (final item in _snapshot.subscriptions)
        if (item.categoryId == category.id)
          CostSubscription(
            id: item.id,
            name: item.name,
            amountCents: item.amountCents,
            cycle: item.cycle,
            nextPaymentAt: item.nextPaymentAt,
            categoryId: null,
            reminderDays: item.reminderDays,
            active: item.active,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          item,
    ];
    final categories = [..._snapshot.categories]
      ..removeWhere((item) => item.id == category.id);
    final snapshot = CostSnapshot(
      entries: entries,
      subscriptions: subscriptions,
      categories: categories,
    );
    await _saveSnapshot(
      snapshot,
      entity: CostSyncEntity.category,
      id: category.id,
    );
    for (final old in linkedEntries) {
      final item = entries.firstWhere((entry) => entry.id == old.id);
      await _saveSnapshot(
        _snapshot,
        entity: CostSyncEntity.entry,
        id: item.id,
        payload: item.toStorage(),
      );
    }
    for (final old in linkedSubscriptions) {
      final item = subscriptions.firstWhere(
        (subscription) => subscription.id == old.id,
      );
      await _saveSnapshot(
        _snapshot,
        entity: CostSyncEntity.subscription,
        id: item.id,
        payload: item.toStorage(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: CostsSectionPicker(
            selectedIndex: _section.index,
            onSelected: (index) =>
                setState(() => _section = _CostsSection.values[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _syncLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Zarządzaj kategoriami',
                onPressed: _manageCategories,
                icon: const Icon(Icons.category_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            _CostsSection.overview => CostDashboard(
              snapshot: _snapshot,
              forecastMode: _forecastMode,
              onForecastModeChanged: _setForecastMode,
              onAdd: showAddChooser,
              onMarkPaid: (payment) => unawaited(_markPaid(payment)),
              onOpenSubscription: (subscription) => unawaited(
                _openEditor(_NewCostKind.subscription, editing: subscription),
              ),
            ),
            _CostsSection.subscriptions => _SubscriptionsPage(
              snapshot: _snapshot,
              onAdd: () => unawaited(_openEditor(_NewCostKind.subscription)),
              onEdit: (item) => unawaited(
                _openEditor(_NewCostKind.subscription, editing: item),
              ),
              onDelete: (item) => unawaited(_deleteSubscription(item)),
            ),
            _CostsSection.history => _HistoryPage(
              snapshot: _snapshot,
              onAdd: showAddChooser,
              onDelete: (item) => unawaited(_deleteEntry(item)),
            ),
          },
        ),
      ],
    );
  }

  Future<void> _setForecastMode(CostForecastMode mode) async {
    if (_forecastMode == mode) return;
    setState(() => _forecastMode = mode);
    try {
      await _forecastPreferences?.save(mode);
    } catch (_) {
      if (!mounted) return;
      setState(() => _forecastMode = CostForecastMode.allOccurrences);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać ustawienia prognozy.'),
        ),
      );
    }
  }

  Future<void> _deleteSubscription(CostSubscription item) async {
    await NotificationService.instance.cancelCostReminders(item.id);
    final next = [..._snapshot.subscriptions]
      ..removeWhere((x) => x.id == item.id);
    await _saveSnapshot(
      CostSnapshot(
        entries: _snapshot.entries,
        subscriptions: next,
        categories: _snapshot.categories,
      ),
      entity: CostSyncEntity.subscription,
      id: item.id,
    );
  }

  Future<void> _deleteEntry(CostEntry item) async {
    final next = [..._snapshot.entries]..removeWhere((x) => x.id == item.id);
    await _saveSnapshot(
      CostSnapshot(
        entries: next,
        subscriptions: _snapshot.subscriptions,
        categories: _snapshot.categories,
      ),
      entity: CostSyncEntity.entry,
      id: item.id,
    );
  }

  Future<void> _cancelStreams() async {
    for (final stream in _streams) {
      await stream.cancel();
    }
    _streams.clear();
  }

  @override
  void dispose() {
    unawaited(_cancelStreams());
    super.dispose();
  }
}

class _CostDraft {
  const _CostDraft({
    required this.title,
    required this.amountCents,
    required this.date,
    this.paid = false,
    this.categoryId,
    this.note = '',
    this.cycle = BillingCycle.monthly,
    this.reminderDays = const [3, 1],
  });
  final String title;
  final int amountCents;
  final DateTime date;
  final bool paid;
  final String? categoryId;
  final String note;
  final BillingCycle cycle;
  final List<int> reminderDays;
}

class _CostEditorDialog extends StatefulWidget {
  const _CostEditorDialog({
    required this.kind,
    required this.categories,
    this.existing,
  });
  final _NewCostKind kind;
  final List<CostCategory> categories;
  final CostSubscription? existing;

  @override
  State<_CostEditorDialog> createState() => _CostEditorDialogState();
}

class _CostEditorDialogState extends State<_CostEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late BillingCycle _cycle;
  String? _categoryId;
  bool _paid = false;
  final Set<int> _reminders = {3, 1};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.name ?? '');
    _amount = TextEditingController(
      text: existing == null ? '' : _formatAmount(existing.amountCents),
    );
    _note = TextEditingController();
    _date = existing?.nextPaymentAt ?? DateTime.now();
    _cycle = existing?.cycle ?? BillingCycle.monthly;
    _categoryId = existing?.categoryId;
    if (existing != null) {
      _reminders
        ..clear()
        ..addAll(existing.reminderDays);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isSubscription => widget.kind == _NewCostKind.subscription;
  bool get _isIncome => widget.kind == _NewCostKind.income;

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      _NewCostKind.expense => 'Nowy wydatek',
      _NewCostKind.income => 'Nowy wpływ',
      _NewCostKind.subscription =>
        widget.existing == null ? 'Nowa subskrypcja' : 'Edytuj subskrypcję',
    };
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: _isSubscription ? 'Nazwa' : 'Za co?',
                ),
              ),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Kwota',
                  suffixText: 'PLN',
                ),
              ),
              if (widget.categories.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria (opcjonalnie)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Bez kategorii'),
                    ),
                    for (final category in widget.categories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          '${category.emoji ?? '•'}  ${category.name}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              if (_isSubscription)
                DropdownButtonFormField<BillingCycle>(
                  initialValue: _cycle,
                  decoration: const InputDecoration(labelText: 'Cykl'),
                  items: const [
                    DropdownMenuItem(
                      value: BillingCycle.weekly,
                      child: Text('Co tydzień'),
                    ),
                    DropdownMenuItem(
                      value: BillingCycle.monthly,
                      child: Text('Co miesiąc'),
                    ),
                    DropdownMenuItem(
                      value: BillingCycle.quarterly,
                      child: Text('Co kwartał'),
                    ),
                    DropdownMenuItem(
                      value: BillingCycle.yearly,
                      child: Text('Co rok'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _cycle = value ?? _cycle),
                ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(_isSubscription ? 'Następna płatność' : 'Data'),
                subtitle: Text(DateFormat('d MMMM y', 'pl_PL').format(_date)),
                onTap: _pickDate,
              ),
              if (_isSubscription)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final day in [3, 1])
                      FilterChip(
                        label: Text('$day ${day == 1 ? 'dzień' : 'dni'} przed'),
                        selected: _reminders.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _reminders.add(day);
                          } else {
                            _reminders.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
              if (!_isSubscription && !_isIncome)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paid,
                  title: const Text('Już opłacone'),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(() => _paid = value ?? false),
                ),
              if (!_isSubscription)
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notatka (opcjonalnie)',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pl', 'PL'),
    );
    if (date != null) setState(() => _date = date);
  }

  void _save() {
    final title = _title.text.trim();
    final normalized = _amount.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (title.isEmpty || amount == null || amount <= 0 || !amount.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj nazwę i prawidłową kwotę większą od 0.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _CostDraft(
        title: title,
        amountCents: (amount * 100).round(),
        date: _date,
        paid: _paid,
        categoryId: _categoryId,
        note: _note.text.trim(),
        cycle: _cycle,
        reminderDays: _reminders.toList()..sort((a, b) => b.compareTo(a)),
      ),
    );
  }
}

class _SubscriptionsPage extends StatelessWidget {
  const _SubscriptionsPage({
    required this.snapshot,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final CostSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<CostSubscription> onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.subscriptions.where((item) => item.active).toList()
      ..sort((a, b) => a.nextPaymentAt.compareTo(b.nextPaymentAt));
    final format = NumberFormat.currency(locale: 'pl_PL', symbol: 'zł');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subskrypcje',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nie masz jeszcze subskrypcji.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.autorenew_rounded),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${_cycleLabel(item.cycle)} · następna ${DateFormat('d MMM y', 'pl_PL').format(item.nextPaymentAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      format.format(item.amountCents / 100),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Więcej opcji',
                      onSelected: (value) =>
                          value == 'edit' ? onEdit(item) : onDelete(item),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edytuj')),
                        PopupMenuItem(value: 'delete', child: Text('Usuń')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({
    required this.snapshot,
    required this.onAdd,
    required this.onDelete,
  });
  final CostSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<CostEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final entries = [...snapshot.entries]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final format = NumberFormat.currency(locale: 'pl_PL', symbol: 'zł');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historia',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Tutaj pojawią się wydatki i wpływy.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          for (final entry in entries)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    entry.type == CostEntryType.income
                        ? Icons.south_west_rounded
                        : Icons.receipt_long_rounded,
                  ),
                ),
                title: Text(entry.title),
                subtitle: Text(
                  '${DateFormat('d MMM y', 'pl_PL').format(entry.occurredAt)} · ${entry.status == CostEntryStatus.paid ? 'Opłacone' : 'Planowane'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.type == CostEntryType.income ? '+' : '−'}${format.format(entry.amountCents / 100)}',
                    ),
                    IconButton(
                      tooltip: 'Usuń',
                      onPressed: () => onDelete(entry),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

String _cycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.weekly => 'co tydzień',
  BillingCycle.monthly => 'co miesiąc',
  BillingCycle.quarterly => 'co kwartał',
  BillingCycle.yearly => 'co rok',
};

String _formatAmount(int cents) =>
    '${(cents ~/ 100)},${(cents % 100).toString().padLeft(2, '0')}';

String _newUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  String bytes(int from, int until) => values
      .sublist(from, until)
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${bytes(0, 4)}-${bytes(4, 6)}-${bytes(6, 8)}-${bytes(8, 10)}-${bytes(10, 16)}';
}
