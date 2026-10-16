import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'business_models.dart';

class BusinessStore extends ChangeNotifier {
  BusinessStore(this.preferences, this.ownerId) {
    _snapshot = _read();
  }

  final SharedPreferences preferences;
  final String ownerId;
  late BusinessSnapshot _snapshot;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  String get _key => 'business_workspace_v1_$ownerId';
  BusinessSnapshot get snapshot => _snapshot;
  Future<void> get flushed => _writes;

  BusinessSnapshot _read() {
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const BusinessSnapshot();
    try {
      return BusinessSnapshot.decode(raw);
    } on Object {
      return const BusinessSnapshot();
    }
  }

  Future<void> _commit(
    BusinessSnapshot Function(BusinessSnapshot current) update,
  ) {
    final operation = _writes.then((_) async {
      final next = update(_snapshot);
      if (!await preferences.setString(_key, next.encode())) {
        throw StateError('Nie udało się zapisać modułu Biznes na urządzeniu.');
      }
      _snapshot = next;
      if (!_disposed) notifyListeners();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _upsert(String kind, String id, Map<String, dynamic> data) =>
      _commit((current) {
        final pending =
            current.pending
                .where((op) => !(op['kind'] == kind && op['id'] == id))
                .toList()
              ..add({
                'kind': kind,
                'id': id,
                'data': data,
                'deleted': false,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              });
        return _replace(current, kind, id, data, pending);
      });

  Future<void> saveProduct(BusinessProduct value) =>
      _upsert('product', value.id, value.toJson());
  Future<void> saveTest(BusinessTest value) =>
      _upsert('test', value.id, value.toJson());
  Future<void> saveWorkflow(BusinessWorkflow value) =>
      _upsert('workflow', value.id, value.toJson());
  Future<void> saveSession(BusinessFocusSession value) =>
      _upsert('session', value.id, value.toJson());
  Future<void> saveIdea(BusinessIdea value) =>
      _upsert('idea', value.id, value.toJson());

  Future<void> remove(String kind, String id) => _commit((current) {
    final pending =
        current.pending
            .where((op) => !(op['kind'] == kind && op['id'] == id))
            .toList()
          ..add({
            'kind': kind,
            'id': id,
            'data': <String, dynamic>{},
            'deleted': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
    return _replace(current, kind, id, null, pending);
  });

  Future<void> acknowledge(Map<String, dynamic> operation) => _commit(
    (current) => BusinessSnapshot(
      products: current.products,
      tests: current.tests,
      workflows: current.workflows,
      sessions: current.sessions,
      ideas: current.ideas,
      pending: current.pending
          .where((item) => jsonEncode(item) != jsonEncode(operation))
          .toList(),
    ),
  );

  Future<void> mergeRemote(List<Map<String, dynamic>> rows) =>
      _commit((current) {
        final pending = current.pending;
        var next = current;
        for (final row in rows) {
          final kind = row['kind'] as String?;
          final id = row['id'] as String?;
          if (kind == null ||
              id == null ||
              pending.any((op) => op['kind'] == kind && op['id'] == id)) {
            continue;
          }
          next = _replace(
            next,
            kind,
            id,
            row['deleted_at'] == null
                ? Map<String, dynamic>.from(row['payload'] as Map? ?? const {})
                : null,
            pending,
          );
        }
        return next;
      });

  Future<void> patchProductPhoto(String id, String storagePath) => _commit((
    current,
  ) {
    final product = current.products.where((item) => item.id == id).firstOrNull;
    if (product == null) return current;
    final patched = product.copyWith(imageStoragePath: storagePath);
    final pending =
        current.pending
            .where((op) => !(op['kind'] == 'product' && op['id'] == id))
            .toList()
          ..add({
            'kind': 'product',
            'id': id,
            'data': patched.toJson(),
            'deleted': false,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
    return _replace(current, 'product', id, patched.toJson(), pending);
  });

  BusinessSnapshot _replace(
    BusinessSnapshot source,
    String kind,
    String id,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>> pending,
  ) {
    List<T> update<T>(
      List<T> list,
      String itemId,
      T Function(Map<String, dynamic>) decode,
      Map<String, dynamic>? payload,
    ) {
      final result = list
          .where((item) => (item as dynamic).id != itemId)
          .toList();
      if (payload != null) result.add(decode(payload));
      return result;
    }

    return BusinessSnapshot(
      products: kind == 'product'
          ? update(source.products, id, BusinessProduct.fromJson, data)
          : source.products,
      tests: kind == 'test'
          ? update(source.tests, id, BusinessTest.fromJson, data)
          : source.tests,
      workflows: kind == 'workflow'
          ? update(source.workflows, id, BusinessWorkflow.fromJson, data)
          : source.workflows,
      sessions: kind == 'session'
          ? update(source.sessions, id, BusinessFocusSession.fromJson, data)
          : source.sessions,
      ideas: kind == 'idea'
          ? update(source.ideas, id, BusinessIdea.fromJson, data)
          : source.ideas,
      pending: pending,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<BusinessWorkflow> get businessPresetWorkflows => const [
  BusinessWorkflow(
    id: 'preset-video',
    name: 'Tworzenie filmu',
    isPreset: true,
    steps: [
      BusinessWorkflowStep(title: 'Wybór angle', minutes: 5),
      BusinessWorkflowStep(title: 'Przygotowanie materiałów', minutes: 10),
      BusinessWorkflowStep(title: 'Montaż', minutes: 20),
      BusinessWorkflowStep(title: 'Publikacja', minutes: 5),
    ],
  ),
  BusinessWorkflow(
    id: 'preset-analysis',
    name: 'Analiza produktu',
    isPreset: true,
    steps: [
      BusinessWorkflowStep(title: 'Problem i odbiorca', minutes: 5),
      BusinessWorkflowStep(title: 'Dostawca i koszty', minutes: 10),
      BusinessWorkflowStep(title: 'Wyróżnik i kreacje', minutes: 10),
      BusinessWorkflowStep(title: 'Decyzja', minutes: 5),
    ],
  ),
  BusinessWorkflow(
    id: 'preset-learning',
    name: 'Nauka i wdrożenie',
    isPreset: true,
    steps: [
      BusinessWorkflowStep(title: 'Wybierz konkretny efekt', minutes: 5),
      BusinessWorkflowStep(title: 'Nauka', minutes: 15),
      BusinessWorkflowStep(title: 'Wdrożenie', minutes: 10),
    ],
  ),
];
