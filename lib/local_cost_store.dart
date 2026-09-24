import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cost_item.dart';

class CostSnapshot {
  const CostSnapshot({
    this.entries = const [],
    this.subscriptions = const [],
    this.categories = const [],
  });

  final List<CostEntry> entries;
  final List<CostSubscription> subscriptions;
  final List<CostCategory> categories;
}

class LocalCostStore {
  LocalCostStore(this._preferences, {this.ownerId = 'local-user'});

  final SharedPreferences _preferences;
  final String ownerId;

  String get _entriesKey => '${_entriesPrefix}_$ownerId';
  String get _subscriptionsKey => '${_subscriptionsPrefix}_$ownerId';
  String get _categoriesKey => '${_categoriesPrefix}_$ownerId';

  static const _entriesPrefix = 'cost_entries_v1';
  static const _subscriptionsPrefix = 'cost_subscriptions_v1';
  static const _categoriesPrefix = 'cost_categories_v1';

  Future<CostSnapshot> load() async => CostSnapshot(
    entries: _decodeList(_entriesKey, CostEntry.fromStorage),
    subscriptions: _decodeList(
      _subscriptionsKey,
      CostSubscription.fromStorage,
    ),
    categories: _decodeList(_categoriesKey, CostCategory.fromStorage),
  );

  Future<void> save(CostSnapshot snapshot) async {
    await _preferences.setString(
      _entriesKey,
      jsonEncode(snapshot.entries.map((entry) => entry.toStorage()).toList()),
    );
    await _preferences.setString(
      _subscriptionsKey,
      jsonEncode(
        snapshot.subscriptions.map((item) => item.toStorage()).toList(),
      ),
    );
    await _preferences.setString(
      _categoriesKey,
      jsonEncode(
        snapshot.categories.map((item) => item.toStorage()).toList(),
      ),
    );
  }

  List<T> _decodeList<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => decode(Map<String, dynamic>.from(item)))
        .toList();
  }
}
