import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum CostSyncEntity { entry, subscription, category }

class PendingCostSync {
  const PendingCostSync({
    required this.entity,
    required this.id,
    required this.payload,
    this.isDelete = false,
  });

  final CostSyncEntity entity;
  final String id;
  final Map<String, dynamic> payload;
  final bool isDelete;

  Map<String, dynamic> toJson() => {
    'entity': entity.name,
    'id': id,
    'payload': payload,
    'isDelete': isDelete,
  };

  factory PendingCostSync.fromJson(Map<String, dynamic> json) =>
      PendingCostSync(
        entity: CostSyncEntity.values.byName(json['entity'] as String),
        id: json['id'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
        isDelete: json['isDelete'] as bool? ?? false,
      );
}

class CostSyncOutbox {
  CostSyncOutbox(this._preferences, {this.ownerId = 'local-user'});

  static const _keyPrefix = 'cost_sync_outbox_v1';
  final SharedPreferences _preferences;
  final String ownerId;
  String get _key => '${_keyPrefix}_$ownerId';

  Future<List<PendingCostSync>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => PendingCostSync.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> enqueue({
    required CostSyncEntity entity,
    required String id,
    required Map<String, dynamic> payload,
  }) => _put(
    PendingCostSync(
      entity: entity,
      id: id,
      payload: Map<String, dynamic>.from(payload),
    ),
  );

  Future<void> enqueueDelete({
    required CostSyncEntity entity,
    required String id,
  }) => _put(
    PendingCostSync(
      entity: entity,
      id: id,
      payload: const {},
      isDelete: true,
    ),
  );

  Future<void> remove(CostSyncEntity entity, String id) async {
    final items = await load()
      ..removeWhere((item) => item.entity == entity && item.id == id);
    await _save(items);
  }

  Future<void> _put(PendingCostSync operation) async {
    final items = await load()
      ..removeWhere(
        (item) => item.entity == operation.entity && item.id == operation.id,
      )
      ..add(operation);
    await _save(items);
  }

  Future<void> _save(List<PendingCostSync> operations) =>
      _preferences.setString(
        _key,
        jsonEncode(operations.map((item) => item.toJson()).toList()),
      );
}
