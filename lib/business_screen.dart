import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_models.dart';
import 'business_store.dart';
import 'business_sync.dart';
import 'notification_service.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({
    super.key,
    required this.ownerId,
    required this.cloudMode,
    this.onChanged,
    this.onConvertIdeaToTask,
    this.isTaskCompleted,
  });
  final String ownerId;
  final bool cloudMode;
  final VoidCallback? onChanged;
  final Future<String?> Function(BusinessIdea idea)? onConvertIdeaToTask;
  final bool Function(String taskId)? isTaskCompleted;
  @override
  State<BusinessScreen> createState() => BusinessScreenState();
}

class BusinessScreenState extends State<BusinessScreen>
    with WidgetsBindingObserver {
  BusinessStore? _store;
  BusinessSync? _sync;
  Timer? _syncTimer, _ticker;
  bool _loading = true, _grid = true, _syncing = false;
  final Set<String> _expiredSessionIds = {};
  int _tab = 0;
  String _query = '', _categoryFilter = '';
  BusinessProductStatus? _statusFilter;
  final _signedUrls = <String, String>{};
  final _signedUrlExpiry = <String, DateTime>{};
  final _search = TextEditingController();
  final _tabs = const ['Przegląd', 'Produkty', 'Testy', 'Focus', 'Parking'];
  BusinessSnapshot get _data => _store?.snapshot ?? const BusinessSnapshot();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(
      () => setState(() => _query = _search.text.trim().toLowerCase()),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = BusinessStore(prefs, widget.ownerId)..addListener(_changed);
      _store = store;
      final presetsSeeded =
          prefs.getBool('business_workflows_seeded_v1_${widget.ownerId}') ??
          false;
      if (!presetsSeeded) {
        await store.seedWorkflowsIfMissing(businessPresetWorkflows);
        await prefs.setBool(
          'business_workflows_seeded_v1_${widget.ownerId}',
          true,
        );
      }
      final activeSession = store.snapshot.sessions
          .where((session) => session.state == BusinessFocusState.running)
          .firstOrNull;
      if (activeSession != null &&
          activeSession.steps.isNotEmpty &&
          activeSession.stepIndex < activeSession.steps.length) {
        final remaining = activeSession.remainingAt(DateTime.now().toUtc());
        if (remaining.inSeconds > 0) {
          await _scheduleFocusNotification(
            id: activeSession.id,
            title: activeSession.steps[activeSession.stepIndex].title,
            when: DateTime.now().add(remaining),
          );
        }
      }
      if (widget.cloudMode) {
        _sync = BusinessSync(Supabase.instance.client, store);
        unawaited(_synchronize());
        _syncTimer = Timer.periodic(
          const Duration(seconds: 25),
          (_) => unawaited(_synchronize()),
        );
      }
      _refreshSignedUrls();
    } catch (error) {
      if (mounted) _toast('Nie udało się otworzyć Biznesu: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
    _refreshSignedUrls();
    if (widget.cloudMode) unawaited(_synchronize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronize());
      unawaited(_refreshSignedUrls());
      setState(() {});
    }
  }

  Future<void> _synchronize() async {
    if (_sync == null || _syncing) return;
    _syncing = true;
    try {
      await _sync!.synchronize();
      if (mounted && _store?.snapshot.pending.isNotEmpty == true) {
        _toast('Biznes zapisany lokalnie · czeka na synchronizację');
      }
    } catch (_) {
      // Local outbox remains durable. A later timer/resume retries it.
    } finally {
      _syncing = false;
      _refreshSignedUrls();
    }
  }

  Future<void> _refreshSignedUrls() async {
    if (!widget.cloudMode) return;
    final refreshBefore = DateTime.now().toUtc().add(
      const Duration(minutes: 2),
    );
    final paths = _data.products
        .map((p) => p.imageStoragePath)
        .whereType<String>()
        .where(
          (p) =>
              p.isNotEmpty &&
              (!_signedUrls.containsKey(p) ||
                  !(_signedUrlExpiry[p]?.isAfter(refreshBefore) ?? false)),
        )
        .toSet();
    if (paths.isEmpty) return;
    try {
      for (final path in paths) {
        final url = await Supabase.instance.client.storage
            .from('business-assets')
            .createSignedUrl(path, 3600);
        if (mounted) {
          setState(() {
            _signedUrls[path] = url;
            _signedUrlExpiry[path] = DateTime.now().toUtc().add(
              const Duration(minutes: 55),
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _ticker?.cancel();
    _search.dispose();
    _sync?.close();
    _store?.removeListener(_changed);
    _store?.dispose();
    super.dispose();
  }

  void showQuickAdd() => unawaited(_editProduct());
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 700;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28,
                12,
                compact ? 16 : 28,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pomysły, produkty i testy',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_data.pending.isNotEmpty)
                    Tooltip(
                      message: 'Oczekuje na synchronizację',
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (!compact)
                    FilledButton.icon(
                      onPressed: showQuickAdd,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nowy produkt'),
                    ),
                  if (compact)
                    IconButton.filledTonal(
                      onPressed: showQuickAdd,
                      tooltip: 'Nowy produkt',
                      icon: const Icon(Icons.add_rounded),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                key: const ValueKey('business-tabs'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_tabs[i]),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _overview(compact),
                  _products(compact),
                  _tests(compact),
                  _focus(compact),
                  _ideas(compact),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _page(Widget child, {bool compact = false}) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 14, compact ? 16 : 28, 96),
    child: child,
  );

  Widget _sectionHeading(
    String title, {
    required bool compact,
    required Widget action,
    TextStyle? style,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
      final heading = Text(title, style: style);
      if (compact || largeText || constraints.maxWidth < 440) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, action],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          action,
        ],
      );
    },
  );

  Widget _responsiveFields(
    List<Widget> fields, {
    int maxColumns = 2,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = min(
        maxColumns,
        max(1, (constraints.maxWidth / 240).floor()),
      );
      final fieldWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final field in fields) SizedBox(width: fieldWidth, child: field),
        ],
      );
    },
  );

  Widget _overview(bool compact) {
    final stats = <(String, String, IconData)>[
      ('Produkty', '${_data.products.length}', Icons.inventory_2_outlined),
      ('Aktywne testy', '${_data.activeTests}', Icons.science_outlined),
      (
        'Opublikowane filmy',
        '${_data.publishedVideos}',
        Icons.play_circle_outline_rounded,
      ),
      ('Sesje Focus', '${_data.completedSessions}', Icons.timer_outlined),
      (
        'Ukończone zadania z Biznesu',
        '${_data.ideas.where((idea) => idea.taskId != null && widget.isTaskCompleted?.call(idea.taskId!) == true).length}',
        Icons.task_alt_rounded,
      ),
    ];
    return _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biznes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Zapisz pomysł. Sprawdź go. Zrób test.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in stats)
                  SizedBox(
                    width: compact
                        ? (c.maxWidth - 12) / 2
                        : min(210, (c.maxWidth - 36) / 4),
                    child: _statCard(stat.$1, stat.$2, stat.$3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeading(
            'Ostatnio dodane',
            compact: compact,
            style: Theme.of(context).textTheme.titleLarge,
            action: TextButton(
              onPressed: () => setState(() => _tab = 1),
              child: const Text('Wszystkie'),
            ),
          ),
          if (_data.products.isEmpty)
            _empty(
              'Jeszcze nie masz produktów',
              'Zapisz pomysł, gdy trafisz na coś wartego sprawdzenia.',
              onTap: showQuickAdd,
              action: 'Dodaj pierwszy produkt',
            )
          else
            ..._data.products.take(3).map((product) => _productTile(product)),
          const SizedBox(height: 16),
          _empty(
            'Pomysł wpadł Ci do głowy?',
            'Odłóż go tutaj i wróć do bieżącego zadania.',
            onTap: () => _editIdea(),
            action: 'Dodaj do parkingu',
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  Widget _products(bool compact) {
    final products =
        _data.products
            .where(
              (p) =>
                  (_query.isEmpty ||
                      '${p.name} ${p.category} ${p.problem} ${p.notes}'
                          .toLowerCase()
                          .contains(_query)) &&
                  (_statusFilter == null || p.status == _statusFilter) &&
                  (_categoryFilter.isEmpty || p.category == _categoryFilter),
            )
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final categories =
        _data.products
            .map((p) => p.category)
            .where((c) => c.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return _page(
      Column(
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Szukaj produktów',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  compact ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25 ||
                  constraints.maxWidth < 520;
              final statusFilter = DropdownButton<BusinessProductStatus?>(
                isExpanded: stacked,
                value: _statusFilter,
                hint: const Text('Wszystkie statusy'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Wszystkie statusy'),
                  ),
                  for (final s in BusinessProductStatus.values)
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              );
              final categoryFilter = DropdownButton<String>(
                isExpanded: stacked,
                value: _categoryFilter,
                hint: const Text('Wszystkie kategorie'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Wszystkie kategorie'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _categoryFilter = v ?? ''),
              );
              final gridToggle = IconButton(
                tooltip: _grid ? 'Widok listy' : 'Widok kafelków',
                onPressed: () => setState(() => _grid = !_grid),
                icon: Icon(
                  _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    statusFilter,
                    categoryFilter,
                    Align(alignment: Alignment.centerRight, child: gridToggle),
                  ],
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [statusFilter, categoryFilter, gridToggle],
              );
            },
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            _empty(
              'Brak pasujących produktów',
              'Zmień filtr albo zapisz pierwszy pomysł.',
              onTap: showQuickAdd,
              action: 'Dodaj produkt',
            )
          else if (_grid)
            LayoutBuilder(
              builder: (context, c) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) > 1.25;
                final n = compact
                    ? (largeText || c.maxWidth < 360 ? 1 : 2)
                    : (c.maxWidth > 1100 ? 4 : 3);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: n,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: n == 1 ? 1.2 : .78,
                  ),
                  itemBuilder: (_, i) => _productCard(products[i]),
                );
              },
            )
          else
            ...products.map(_productTile),
        ],
      ),
    );
  }

  Widget _productCard(BusinessProduct product) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _editProduct(original: product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _productImage(product)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _statusLabel(product.status),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Ocena ${product.qualificationScore}/5 · ${product.checkedCriteria} sprawdzone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _productTile(BusinessProduct p) => Card(
    child: ListTile(
      onTap: () => _editProduct(original: p),
      leading: SizedBox(
        width: 52,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _productImage(p),
        ),
      ),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_statusLabel(p.status)} · ocena ${p.qualificationScore}/5',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );

  Widget _productImage(BusinessProduct product) {
    final local = product.imageLocalPath;
    if (local != null && File(local).existsSync()) {
      return Image.file(File(local), fit: BoxFit.cover);
    }
    final remote =
        product.imageUrl ??
        (product.imageStoragePath == null
            ? null
            : _signedUrls[product.imageStoragePath]);
    if (remote != null && Uri.tryParse(remote)?.hasScheme == true) {
      return Image.network(
        remote,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.photo_outlined)),
  );

  Future<BusinessProduct?> _editProduct({
    BusinessProduct? original,
    String? presetName,
    String? presetNotes,
    String? presetUrl,
  }) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(
      text: original?.name ?? presetName ?? '',
    );
    final category = TextEditingController(text: original?.category ?? '');
    final inspiration = TextEditingController(
      text: original?.inspirationUrl ?? presetUrl ?? '',
    );
    final supplier = TextEditingController(text: original?.supplierUrl ?? '');
    final problem = TextEditingController(text: original?.problem ?? '');
    final angles = TextEditingController(
      text: original?.angles.join('\n') ?? '',
    );
    final notes = TextEditingController(
      text: original?.notes ?? presetNotes ?? '',
    );
    final priceBuy = TextEditingController(
      text: _moneyInput(original?.purchasePriceCents),
    );
    final priceSell = TextEditingController(
      text: _moneyInput(original?.sellingPriceCents),
    );
    final shipping = TextEditingController(
      text: _moneyInput(original?.shippingCostCents ?? 0),
    );
    final ads = TextEditingController(
      text: _moneyInput(original?.adCostCents ?? 0),
    );
    final other = TextEditingController(
      text: _moneyInput(original?.otherCostCents ?? 0),
    );
    var status = original?.status ?? BusinessProductStatus.saved;
    var criteria = List<bool?>.from(
      original?.criteria ?? const [null, null, null, null, null],
    );
    var imagePath = original?.imageLocalPath;
    var imageUrl = original?.imageUrl;
    var imageStorage = original?.imageStoragePath;
    final result = await showDialog<BusinessProduct>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(original == null ? 'Nowy produkt' : 'Produkt'),
          content: SizedBox(
            key: const ValueKey('business-product-editor-content'),
            width: min(
              920.0,
              (MediaQuery.sizeOf(dialog).width - 64).clamp(240.0, 920.0),
            ),
            height: min(
              680.0,
              (MediaQuery.sizeOf(dialog).height * .68).clamp(300.0, 680.0),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Produkt',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa produktu *',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Wpisz nazwę produktu'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final urlField = TextFormField(
                          initialValue: imageUrl,
                          decoration: const InputDecoration(
                            labelText: 'Zdjęcie z adresu URL',
                          ),
                          onChanged: (v) {
                            imageUrl = v.trim().isEmpty ? null : v.trim();
                            imagePath = null;
                          },
                        );
                        final imagePicker = IconButton(
                          tooltip: 'Wybierz zdjęcie z urządzenia',
                          onPressed: () async {
                            final picked = await FilePicker.pickFile(
                              type: FileType.image,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            if (bytes.isEmpty) {
                              _toast(
                                'Nie udało się odczytać wybranego zdjęcia.',
                              );
                              return;
                            }
                            if (bytes.length > 20 * 1024 * 1024) {
                              _toast('Zdjęcie może mieć maksymalnie 20 MB.');
                              return;
                            }
                            final root = await getApplicationSupportDirectory();
                            final dir = Directory(
                              '${root.path}${Platform.pathSeparator}business_assets',
                            )..createSync(recursive: true);
                            final file = File(
                              '${dir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_${picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}',
                            );
                            await file.writeAsBytes(bytes, flush: true);
                            refresh(() {
                              imagePath = file.path;
                              imageUrl = null;
                              imageStorage = null;
                            });
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        );
                        final largeText =
                            MediaQuery.textScalerOf(dialog).scale(1) > 1.25;
                        if (constraints.maxWidth < 440 || largeText) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              urlField,
                              Align(
                                alignment: Alignment.centerRight,
                                child: imagePicker,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: urlField),
                            imagePicker,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BusinessProductStatus>(
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in BusinessProductStatus.values)
                          DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) refresh(() => status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Kategoria'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: inspiration,
                      decoration: const InputDecoration(
                        labelText: 'Link do inspiracji',
                      ),
                      validator: _urlValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: supplier,
                      decoration: const InputDecoration(
                        labelText: 'Link do dostawcy',
                      ),
                      validator: _urlValidator,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Cena i koszty',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    _responsiveFields([
                      TextFormField(
                        controller: priceBuy,
                        decoration: const InputDecoration(
                          labelText: 'Zakup (zł)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _moneyValidator,
                      ),
                      TextFormField(
                        controller: priceSell,
                        decoration: const InputDecoration(
                          labelText: 'Sprzedaż (zł)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _moneyValidator,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _responsiveFields([
                      TextFormField(
                        controller: shipping,
                        decoration: const InputDecoration(
                          labelText: 'Dostawa (zł)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _moneyValidator,
                      ),
                      TextFormField(
                        controller: ads,
                        decoration: const InputDecoration(
                          labelText: 'Reklama (zł)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _moneyValidator,
                      ),
                      TextFormField(
                        controller: other,
                        decoration: const InputDecoration(
                          labelText: 'Inne (zł)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _moneyValidator,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Opis i marketing',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: problem,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Problem, potrzeba lub emocja',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: angles,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Angles marketingowe (każdy w nowej linii)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Notatki'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Wstępna ocena',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (var i = 0; i < _criteriaLabels.length; i++) ...[
                      DropdownButtonFormField<bool?>(
                        initialValue: criteria[i],
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _criteriaLabels[i],
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Nie sprawdzono'),
                          ),
                          DropdownMenuItem(value: true, child: Text('Tak')),
                          DropdownMenuItem(value: false, child: Text('Nie')),
                        ],
                        onChanged: (v) => refresh(() => criteria[i] = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (original != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Wynik: ${criteria.where((e) => e == true).length}/5 · sprawdzono ${criteria.where((e) => e != null).length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (original != null)
              TextButton(
                onPressed: () async {
                  final yes = await _confirm(
                    'Usunąć produkt i powiązane testy?',
                  );
                  if (yes && dialog.mounted) {
                    await _store!.remove('product', original.id);
                    for (final test in _data.tests.where(
                      (t) => t.productId == original.id,
                    )) {
                      await _store!.remove('test', test.id);
                    }
                    if (dialog.mounted) Navigator.pop(dialog);
                  }
                },
                child: const Text('Usuń'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final now = DateTime.now().toUtc();
                final product = BusinessProduct(
                  id: original?.id ?? _id(),
                  name: name.text.trim(),
                  status: status,
                  addedAt: original?.addedAt ?? now,
                  imageLocalPath: imagePath,
                  imageStoragePath: imageStorage,
                  imageUrl: imageUrl,
                  inspirationUrl: _nullable(inspiration.text),
                  supplierUrl: _nullable(supplier.text),
                  purchasePriceCents: _parseCents(priceBuy.text),
                  sellingPriceCents: _parseCents(priceSell.text),
                  shippingCostCents: _parseCents(shipping.text) ?? 0,
                  adCostCents: _parseCents(ads.text) ?? 0,
                  otherCostCents: _parseCents(other.text) ?? 0,
                  category: category.text.trim(),
                  problem: problem.text.trim(),
                  angles: angles.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  notes: notes.text.trim(),
                  criteria: criteria,
                  updatedAt: now,
                );
                Navigator.pop(dialog, product);
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final controller in [
      name,
      category,
      inspiration,
      supplier,
      problem,
      angles,
      notes,
      priceBuy,
      priceSell,
      shipping,
      ads,
      other,
    ]) {
      controller.dispose();
    }
    if (result != null) await _store!.saveProduct(result);
    return result;
  }

  Widget _tests(bool compact) {
    final active = _data.tests
        .where((t) => t.status == BusinessTestStatus.active)
        .length;
    return _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Laboratorium testów',
            compact: compact,
            style: Theme.of(context).textTheme.titleLarge,
            action: FilledButton.icon(
              onPressed: _createTest,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nowy test'),
            ),
          ),
          const SizedBox(height: 4),
          Text('$active aktywnych · ${_data.tests.length} łącznie'),
          const SizedBox(height: 12),
          if (_data.tests.isEmpty)
            _empty(
              'Jeszcze nie ma testów',
              'Utwórz test z karty produktu i dodawaj wyniki ręcznie.',
              onTap: () => setState(() => _tab = 1),
              action: 'Wybierz produkt',
            )
          else
            for (final test in _data.tests.reversed) _testCard(test),
        ],
      ),
      compact: compact,
    );
  }

  Widget _testCard(BusinessTest test) {
    final product = _data.products
        .where((p) => p.id == test.productId)
        .firstOrNull;
    return Card(
      child: ExpansionTile(
        title: Text(test.name),
        subtitle: Text(
          '${product?.name ?? 'Produkt usunięty'} · ${_testStatus(test.status)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (test.startAt != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Start: ${DateFormat('dd.MM.yyyy').format(test.startAt!.toLocal())}',
              ),
            ),
          Text(
            'Plan kreacji: ${test.plannedCreatives} · Filmy: ${test.videos.length}',
          ),
          if (test.angles.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Angles: ${test.angles.join(', ')}'),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (test.orders != null)
                Chip(label: Text('Zamówienia: ${test.orders}')),
              if (test.revenueCents != null)
                Chip(
                  label: Text('Przychód: ${_formatMoney(test.revenueCents!)}'),
                ),
            ],
          ),
          if (test.notes.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text(test.notes)),
          if (test.conclusion.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Wniosek: ${test.conclusion}'),
            ),
          for (final video in test.videos)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text(
                video.title.isEmpty
                    ? _platformLabel(video.platform)
                    : video.title,
              ),
              subtitle: Text(
                [
                  if (video.views != null) 'wyświetlenia ${video.views}',
                  if (video.retentionPercent != null)
                    'retencja ${video.retentionPercent}%',
                  if (video.clicks != null) 'kliknięcia ${video.clicks}',
                ].join(' · ').ifEmpty('Brak wprowadzonych statystyk'),
              ),
              trailing: video.url != null
                  ? const Icon(Icons.link_rounded)
                  : null,
            ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: () => _addVideo(test),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Dodaj film'),
              ),
              TextButton.icon(
                onPressed: () => _editTest(test),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edytuj'),
              ),
              TextButton(
                onPressed: () => _store!.remove('test', test.id),
                child: const Text('Usuń'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createTest() async {
    if (_data.products.isEmpty) {
      _toast('Najpierw zapisz produkt.');
      setState(() => _tab = 1);
      return;
    }
    final product = await showDialog<BusinessProduct>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Wybierz produkt'),
        content: DropdownButtonFormField<BusinessProduct>(
          items: [
            for (final p in _data.products)
              DropdownMenuItem(value: p, child: Text(p.name)),
          ],
          onChanged: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
    if (product == null) return;
    final test = BusinessTest(
      id: _id(),
      productId: product.id,
      name: 'Test ${product.name}',
      status: BusinessTestStatus.planned,
      createdAt: DateTime.now().toUtc(),
      startAt: DateTime.now(),
    );
    await _editTest(test, isNew: true);
  }

  Future<void> _editTest(BusinessTest original, {bool isNew = false}) async {
    final name = TextEditingController(text: original.name);
    final planned = TextEditingController(text: '${original.plannedCreatives}');
    final angles = TextEditingController(text: original.angles.join('\n'));
    final notes = TextEditingController(text: original.notes);
    final conclusion = TextEditingController(text: original.conclusion);
    final orders = TextEditingController(
      text: original.orders?.toString() ?? '',
    );
    final revenue = TextEditingController(
      text: _moneyInput(original.revenueCents),
    );
    var status = original.status;
    var decision = original.decision;
    DateTime? start = original.startAt;
    DateTime? end = original.endAt;
    final saved = await showDialog<BusinessTest>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(isNew ? 'Nowy test' : 'Edytuj test'),
          content: SizedBox(
            width: min(
              500.0,
              (MediaQuery.sizeOf(dialog).width - 64).clamp(240.0, 500.0),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nazwa testu'),
                  ),
                  DropdownButtonFormField<BusinessTestStatus>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final value in BusinessTestStatus.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_testStatus(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) refresh(() => status = value);
                    },
                  ),
                  TextField(
                    controller: planned,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Planowana liczba kreacji',
                    ),
                  ),
                  _responsiveFields([
                    TextButton(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: dialog,
                          initialDate: start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (value != null) refresh(() => start = value);
                      },
                      child: Text(
                        start == null
                            ? 'Data startu'
                            : DateFormat('dd.MM.yyyy').format(start!),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: dialog,
                          initialDate: end ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (value != null) refresh(() => end = value);
                      },
                      child: Text(
                        end == null
                            ? 'Data końca'
                            : DateFormat('dd.MM.yyyy').format(end!),
                      ),
                    ),
                  ]),
                  TextField(
                    controller: angles,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Angles — każda w osobnej linii',
                    ),
                  ),
                  TextField(
                    controller: orders,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Zamówienia — puste, jeśli nieznane',
                    ),
                  ),
                  TextField(
                    controller: revenue,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Przychód (zł) — puste, jeśli nieznany',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notatki'),
                  ),
                  TextField(
                    controller: conclusion,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Wnioski'),
                  ),
                  DropdownButtonFormField<BusinessTestDecision?>(
                    initialValue: decision,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Decyzja końcowa',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Brak decyzji'),
                      ),
                      DropdownMenuItem(
                        value: BusinessTestDecision.continueTesting,
                        child: Text('Kontynuuj'),
                      ),
                      DropdownMenuItem(
                        value: BusinessTestDecision.changeApproach,
                        child: Text('Zmień podejście'),
                      ),
                      DropdownMenuItem(
                        value: BusinessTestDecision.reject,
                        child: Text('Odrzuć produkt'),
                      ),
                    ],
                    onChanged: (value) => refresh(() => decision = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialog,
                BusinessTest(
                  id: original.id,
                  productId: original.productId,
                  name: name.text.trim().isEmpty ? 'Test' : name.text.trim(),
                  status: status,
                  createdAt: original.createdAt,
                  startAt: start,
                  endAt: end,
                  plannedCreatives: int.tryParse(planned.text) ?? 0,
                  angles: angles.text
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  videos: original.videos,
                  orders: int.tryParse(orders.text),
                  revenueCents: _parseCents(revenue.text),
                  notes: notes.text,
                  conclusion: conclusion.text,
                  decision: decision,
                ),
              ),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final controller in [
      name,
      planned,
      angles,
      notes,
      conclusion,
      orders,
      revenue,
    ]) {
      controller.dispose();
    }
    if (saved != null) await _store!.saveTest(saved);
  }

  Future<void> _addVideo(BusinessTest test) async {
    final title = TextEditingController();
    final url = TextEditingController();
    final views = TextEditingController();
    final retention = TextEditingController();
    final clicks = TextEditingController();
    var platform = BusinessPlatform.tiktok;
    final video = await showDialog<BusinessVideo>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: const Text('Dodaj film'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa lub opis filmu',
                  ),
                ),
                DropdownButtonFormField<BusinessPlatform>(
                  initialValue: platform,
                  isExpanded: true,
                  items: [
                    for (final value in BusinessPlatform.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_platformLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) refresh(() => platform = value);
                  },
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Link do filmu'),
                  keyboardType: TextInputType.url,
                ),
                TextField(
                  controller: views,
                  decoration: const InputDecoration(labelText: 'Wyświetlenia'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: retention,
                  decoration: const InputDecoration(labelText: 'Retencja %'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: clicks,
                  decoration: const InputDecoration(labelText: 'Kliknięcia'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialog,
                BusinessVideo(
                  id: _id(),
                  platform: platform,
                  title: title.text,
                  url: _nullable(url.text),
                  publishedAt: DateTime.now(),
                  views: int.tryParse(views.text),
                  retentionPercent: double.tryParse(
                    retention.text.replaceAll(',', '.'),
                  ),
                  clicks: int.tryParse(clicks.text),
                ),
              ),
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final controller in [title, url, views, retention, clicks]) {
      controller.dispose();
    }
    if (video != null) {
      await _store!.saveTest(
        BusinessTest(
          id: test.id,
          productId: test.productId,
          name: test.name,
          status: test.status,
          createdAt: test.createdAt,
          startAt: test.startAt,
          endAt: test.endAt,
          plannedCreatives: test.plannedCreatives,
          angles: test.angles,
          videos: [...test.videos, video],
          orders: test.orders,
          revenueCents: test.revenueCents,
          notes: test.notes,
          conclusion: test.conclusion,
          decision: test.decision,
        ),
      );
    }
  }

  Widget _focus(bool compact) {
    final session = _data.sessions
        .where(
          (s) =>
              s.state == BusinessFocusState.running ||
              s.state == BusinessFocusState.paused,
        )
        .firstOrNull;
    if (session != null && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    if (session == null) _ticker?.cancel();
    final workflows = _data.workflows;
    return _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Focus', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Ustaw czas i przejdź do działania.'),
          const SizedBox(height: 12),
          if (session != null)
            _activeSession(session)
          else ...[
            for (final workflow in workflows)
              Card(
                child: ListTile(
                  title: Text(workflow.name),
                  subtitle: Text(
                    '${workflow.steps.length} kroków · ${workflow.totalMinutes} min',
                  ),
                  trailing: IconButton(
                    tooltip: 'Rozpocznij',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => _startSession(workflow),
                  ),
                  onTap: () => _editWorkflow(workflow),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _editWorkflow(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Własny workflow'),
            ),
            const SizedBox(height: 20),
            Text(
              'Ostatnie sesje',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final item
                in _data.sessions
                    .where((s) => s.state == BusinessFocusState.completed)
                    .take(10))
              ListTile(
                dense: true,
                leading: const Icon(Icons.task_alt_rounded),
                title: Text(item.workflowName),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy HH:mm')
                      .format(item.startedAt.toLocal()),
                ),
              ),
          ],
        ],
      ),
      compact: compact,
    );
  }

  Widget _activeSession(BusinessFocusSession session) {
    if (session.steps.isEmpty ||
        session.stepIndex < 0 ||
        session.stepIndex >= session.steps.length) {
      return Card(
        child: ListTile(
          title: const Text('Nieprawidłowa sesja Focus'),
          subtitle: const Text('Możesz bezpiecznie zakończyć tę sesję.'),
          trailing: TextButton(
            onPressed: () => _finishSession(session, false),
            child: const Text('Zakończ'),
          ),
        ),
      );
    }
    final remaining = session.remainingAt(DateTime.now().toUtc());
    if (remaining.inSeconds <= 0 &&
        session.state == BusinessFocusState.running &&
        _expiredSessionIds.add(session.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_expireStep(session));
      });
    }
    final total = session.steps.fold<int>(0, (s, x) => s + x.minutes);
    final done = session.steps
        .take(session.stepIndex)
        .fold<int>(0, (s, x) => s + x.minutes);
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.workflowName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text('Krok ${session.stepIndex + 1} z ${session.steps.length}'),
            Text(
              session.steps[session.stepIndex].title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _time(remaining),
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (session.state == BusinessFocusState.running)
                  OutlinedButton.icon(
                    onPressed: () => _pauseSession(session),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Pauza'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _resumeSession(session),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Wznów'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _extendSession(session, 5),
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('+5 min'),
                ),
                FilledButton.icon(
                  onPressed: () => _nextStep(session),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Wystarczy, idę dalej'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _finishSession(session, false),
              child: const Text('Zakończ sesję'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession(BusinessWorkflow workflow) async {
    if (workflow.steps.isEmpty) {
      _toast('Ten workflow nie ma jeszcze żadnych kroków.');
      return;
    }
    final current = _data.sessions
        .where(
          (s) =>
              s.state == BusinessFocusState.running ||
              s.state == BusinessFocusState.paused,
        )
        .firstOrNull;
    if (current != null && !await _confirm('Zakończyć poprzednią sesję?')) {
      return;
    }
    if (current != null) await _finishSession(current, false);
    final session = BusinessFocusSession.start(
      id: _id(),
      workflow: workflow,
      startedAt: DateTime.now().toUtc(),
    );
    await _store!.saveSession(session);
    await _scheduleFocusNotification(
      id: session.id,
      title: session.steps.first.title,
      when: DateTime.now().add(Duration(minutes: session.steps.first.minutes)),
    );
  }

  Future<void> _scheduleFocusNotification({
    required String id,
    required String title,
    required DateTime when,
  }) async {
    if (!Platform.isAndroid) return;
    await NotificationService.instance.scheduleFocusSessionEnd(
      taskId: id,
      title: title,
      when: when,
    );
  }

  Future<void> _pauseSession(BusinessFocusSession s) async {
    final remain = max(0, s.remainingAt(DateTime.now().toUtc()).inSeconds);
    await NotificationService.instance.cancelFocusSession(s.id);
    await _store!.saveSession(
      s.copyWith(remainingSeconds: remain, state: BusinessFocusState.paused),
    );
  }

  Future<void> _expireStep(BusinessFocusSession session) async {
    final current = _data.sessions
        .where((item) => item.id == session.id)
        .firstOrNull;
    if (current == null ||
        current.state != BusinessFocusState.running ||
        current.stepIndex != session.stepIndex ||
        current.remainingAt(DateTime.now().toUtc()).inSeconds > 0) {
      return;
    }
    await NotificationService.instance.cancelFocusSession(session.id);
    await _store!.saveSession(
      current.copyWith(remainingSeconds: 0, state: BusinessFocusState.paused),
    );
    _toast('Czas kroku minął. Możesz go przedłużyć albo przejść dalej.');
  }

  Future<void> _resumeSession(BusinessFocusSession s) async {
    _expiredSessionIds.remove(s.id);
    final now = DateTime.now().toUtc();
    await _store!.saveSession(
      s.copyWith(state: BusinessFocusState.running, lastResumedAt: now),
    );
    await _scheduleFocusNotification(
      id: s.id,
      title: s.steps[s.stepIndex].title,
      when: now.add(s.remainingAt(now)),
    );
  }

  Future<void> _extendSession(BusinessFocusSession s, int minutes) async {
    _expiredSessionIds.remove(s.id);
    final now = DateTime.now().toUtc();
    final remain = max(0, s.remainingAt(now).inSeconds) + minutes * 60;
    await NotificationService.instance.cancelFocusSession(s.id);
    await _store!.saveSession(
      s.copyWith(
        remainingSeconds: remain,
        state: BusinessFocusState.running,
        lastResumedAt: now,
      ),
    );
    await _scheduleFocusNotification(
      id: s.id,
      title: s.steps[s.stepIndex].title,
      when: now.add(Duration(seconds: remain)),
    );
  }

  Future<void> _nextStep(BusinessFocusSession s) async {
    _expiredSessionIds.remove(s.id);
    await NotificationService.instance.cancelFocusSession(s.id);
    if (s.stepIndex + 1 >= s.steps.length) {
      await _finishSession(s, true);
      return;
    }
    final now = DateTime.now().toUtc();
    final next = s.stepIndex + 1;
    await _store!.saveSession(
      s.copyWith(
        stepIndex: next,
        remainingSeconds: s.steps[next].minutes * 60,
        state: BusinessFocusState.running,
        lastResumedAt: now,
      ),
    );
    await _scheduleFocusNotification(
      id: s.id,
      title: s.steps[next].title,
      when: now.add(Duration(minutes: s.steps[next].minutes)),
    );
  }

  Future<void> _finishSession(BusinessFocusSession s, bool completed) async {
    await NotificationService.instance.cancelFocusSession(s.id);
    _ticker?.cancel();
    await _store!.saveSession(
      s.copyWith(
        state: completed
            ? BusinessFocusState.completed
            : BusinessFocusState.abandoned,
        endedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _editWorkflow([BusinessWorkflow? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final steps =
        <({TextEditingController title, TextEditingController minutes})>[];
    for (final step in old?.steps ?? const <BusinessWorkflowStep>[]) {
      steps.add((
        title: TextEditingController(text: step.title),
        minutes: TextEditingController(text: '${step.minutes}'),
      ));
    }
    if (steps.isEmpty) {
      steps.add((
        title: TextEditingController(),
        minutes: TextEditingController(text: '10'),
      ));
    }
    final saved = await showDialog<BusinessWorkflow>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(old == null ? 'Nowy workflow' : 'Edytuj workflow'),
          content: SizedBox(
            width: min(
              480.0,
              (MediaQuery.sizeOf(dialog).width - 64).clamp(240.0, 480.0),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nazwa'),
                  ),
                  for (var i = 0; i < steps.length; i++)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final titleField = TextField(
                          controller: steps[i].title,
                          decoration: InputDecoration(
                            labelText: 'Krok ${i + 1}',
                          ),
                        );
                        final minutesField = SizedBox(
                          width: 88,
                          child: TextField(
                            controller: steps[i].minutes,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min'),
                          ),
                        );
                        final removeButton = IconButton(
                          onPressed: steps.length <= 1
                              ? null
                              : () => refresh(() => steps.removeAt(i)),
                          icon: const Icon(Icons.close_rounded),
                        );
                        final largeText =
                            MediaQuery.textScalerOf(dialog).scale(1) > 1.25;
                        if (constraints.maxWidth < 420 || largeText) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleField,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [minutesField, removeButton],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: titleField),
                            minutesField,
                            removeButton,
                          ],
                        );
                      },
                    ),
                  TextButton.icon(
                    onPressed: () => refresh(
                      () => steps.add((
                        title: TextEditingController(),
                        minutes: TextEditingController(text: '5'),
                      )),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Dodaj krok'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (old != null)
              TextButton(
                onPressed: () async {
                  if (await _confirm('Usunąć workflow?')) {
                    await _store!.remove('workflow', old.id);
                    if (dialog.mounted) Navigator.pop(dialog);
                  }
                },
                child: const Text('Usuń'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = steps
                    .map(
                      (step) => BusinessWorkflowStep(
                        title: step.title.text.trim(),
                        minutes: max(1, int.tryParse(step.minutes.text) ?? 1),
                      ),
                    )
                    .where((step) => step.title.isNotEmpty)
                    .toList();
                if (name.text.trim().isEmpty || parsed.isEmpty) {
                  _toast('Dodaj nazwę i przynajmniej jeden krok.');
                  return;
                }
                Navigator.pop(
                  dialog,
                  BusinessWorkflow(
                    id: old?.id ?? _id(),
                    name: name.text.trim(),
                    steps: parsed,
                    isPreset: old?.isPreset ?? false,
                  ),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    for (final step in steps) {
      step.title.dispose();
      step.minutes.dispose();
    }
    if (saved != null) await _store!.saveWorkflow(saved);
  }

  Widget _ideas(bool compact) => _page(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Parking pomysłów',
          compact: compact,
          style: Theme.of(context).textTheme.titleLarge,
          action: FilledButton.icon(
            onPressed: () => _editIdea(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nowy pomysł'),
          ),
        ),
        const SizedBox(height: 8),
        if (_data.ideas.isEmpty)
          _empty(
            'Odłóż pomysł na później',
            'Zapisz go, żeby nie przerywać bieżącej pracy.',
            onTap: () => _editIdea(),
            action: 'Dodaj pomysł',
          )
        else
          for (final idea in _data.ideas.reversed) _ideaCard(idea),
      ],
    ),
    compact: compact,
  );
  Widget _ideaCard(BusinessIdea idea) => Card(
    child: ExpansionTile(
      title: Text(idea.title),
      subtitle: Text(_ideaStatus(idea.status)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (idea.description.isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: Text(idea.description)),
        if (idea.url != null)
          Align(alignment: Alignment.centerLeft, child: Text(idea.url!)),
        Wrap(
          children: [
            DropdownButton<BusinessIdeaStatus>(
              value: idea.status,
              items: [
                for (final s in BusinessIdeaStatus.values)
                  DropdownMenuItem(value: s, child: Text(_ideaStatus(s))),
              ],
              onChanged: (v) {
                if (v != null) {
                  _store!.saveIdea(
                    BusinessIdea(
                      id: idea.id,
                      title: idea.title,
                      description: idea.description,
                      url: idea.url,
                      status: v,
                      createdAt: idea.createdAt,
                      productId: idea.productId,
                      taskId: idea.taskId,
                    ),
                  );
                }
              },
            ),
            TextButton(
              onPressed: () async {
                final product = await _editProduct(
                  presetName: idea.title,
                  presetNotes: idea.description,
                  presetUrl: idea.url,
                );
                if (product != null) {
                  await _store!.saveIdea(
                    BusinessIdea(
                      id: idea.id,
                      title: idea.title,
                      description: idea.description,
                      url: idea.url,
                      status: BusinessIdeaStatus.done,
                      createdAt: idea.createdAt,
                      productId: product.id,
                      taskId: idea.taskId,
                    ),
                  );
                }
              },
              child: const Text('Zamień w produkt'),
            ),
            if (idea.taskId == null && widget.onConvertIdeaToTask != null)
              TextButton(
                onPressed: () async {
                  final id = await widget.onConvertIdeaToTask!(idea);
                  if (id != null) {
                    await _store!.saveIdea(
                      BusinessIdea(
                        id: idea.id,
                        title: idea.title,
                        description: idea.description,
                        url: idea.url,
                        status: BusinessIdeaStatus.done,
                        createdAt: idea.createdAt,
                        productId: idea.productId,
                        taskId: id,
                      ),
                    );
                  }
                },
                child: const Text('Utwórz zadanie'),
              ),
            TextButton(
              onPressed: () => _editIdea(idea),
              child: const Text('Edytuj'),
            ),
            TextButton(
              onPressed: () => _store!.remove('idea', idea.id),
              child: const Text('Usuń'),
            ),
          ],
        ),
      ],
    ),
  );
  Future<void> _editIdea([BusinessIdea? old]) async {
    final title = TextEditingController(text: old?.title ?? ''),
        description = TextEditingController(text: old?.description ?? ''),
        url = TextEditingController(text: old?.url ?? '');
    final saved = await showDialog<BusinessIdea>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(old == null ? 'Szybki pomysł' : 'Edytuj pomysł'),
        content: SizedBox(
          width: min(
            480.0,
            (MediaQuery.sizeOf(d).width - 64).clamp(240.0, 480.0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tytuł'),
                ),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Opis'),
                ),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Link'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) {
                _toast('Wpisz tytuł.');
                return;
              }
              final urlError = _validateUrl(url.text);
              if (urlError != null) {
                _toast(urlError);
                return;
              }
              Navigator.pop(
                d,
                BusinessIdea(
                  id: old?.id ?? _id(),
                  title: title.text.trim(),
                  description: description.text.trim(),
                  url: _nullable(url.text),
                  status: old?.status ?? BusinessIdeaStatus.fresh,
                  createdAt: old?.createdAt ?? DateTime.now().toUtc(),
                  productId: old?.productId,
                  taskId: old?.taskId,
                ),
              );
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in [title, description, url]) {
      c.dispose();
    }
    if (saved != null) await _store!.saveIdea(saved);
  }

  Widget _empty(
    String title,
    String subtitle, {
    required VoidCallback onTap,
    required String action,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Potwierdź'),
            ),
          ],
        ),
      ) ??
      false;
}

const _criteriaLabels = [
  'Problem lub emocja',
  'Potencjał filmu',
  'Marża',
  'Dostawca i dostawa',
  'Wyróżnik',
];
String _id() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';
String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
int? _parseCents(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final number = double.tryParse(normalized);
  if (number == null || !number.isFinite || number < 0 || number > 100000000) {
    return null;
  }
  return (number * 100).round();
}

String _moneyInput(int? value) =>
    value == null ? '' : (value / 100).toStringAsFixed(2).replaceAll('.', ',');
String _formatMoney(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} zł';
String? _moneyValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _parseCents(value) == null ? 'Wpisz prawidłową kwotę od 0 zł' : null;
}

String? _urlValidator(String? value) => _validateUrl(value);
String? _validateUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.contains('.')
      ? null
      : 'Wpisz pełny adres https:// lub http://';
}

String _statusLabel(BusinessProductStatus status) => switch (status) {
  BusinessProductStatus.saved => 'Zapisany',
  BusinessProductStatus.toAnalyze => 'Do analizy',
  BusinessProductStatus.readyToTest => 'Gotowy do testu',
  BusinessProductStatus.testing => 'W trakcie testu',
  BusinessProductStatus.potential => 'Potencjał',
  BusinessProductStatus.rejected => 'Odrzucony',
};
String _testStatus(BusinessTestStatus status) => switch (status) {
  BusinessTestStatus.planned => 'Planowany',
  BusinessTestStatus.active => 'Aktywny',
  BusinessTestStatus.completed => 'Zakończony',
};
String _ideaStatus(BusinessIdeaStatus status) => switch (status) {
  BusinessIdeaStatus.fresh => 'Nowy',
  BusinessIdeaStatus.toCheck => 'Do sprawdzenia',
  BusinessIdeaStatus.done => 'Zrealizowany',
};
String _platformLabel(BusinessPlatform p) => switch (p) {
  BusinessPlatform.tiktok => 'TikTok',
  BusinessPlatform.instagram => 'Instagram',
  BusinessPlatform.facebook => 'Facebook',
  BusinessPlatform.other => 'Inna platforma',
};
String _time(Duration d) {
  final seconds = max(0, d.inSeconds);
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
