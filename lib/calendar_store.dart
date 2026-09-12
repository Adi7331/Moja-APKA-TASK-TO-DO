import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_event.dart';

class CalendarCache {
  const CalendarCache({required this.events, this.lastSyncedAt});

  final List<CalendarEvent> events;
  final DateTime? lastSyncedAt;
}

class CalendarStore {
  CalendarStore(this._preferences);

  static const _selectionKey = 'calendar_selected_ids_v1';
  static const _cacheKey = 'calendar_events_cache_v1';
  static const _syncedAtKey = 'calendar_events_synced_at_v1';
  final SharedPreferences _preferences;

  Future<List<String>> loadSelection() async =>
      _preferences.getStringList(_selectionKey) ?? const [];

  Future<void> saveSelection(List<String> ids) async {
    await _preferences.setStringList(_selectionKey, ids);
  }

  Future<CalendarCache> loadCache() async {
    final raw = _preferences.getString(_cacheKey);
    final syncedAt = _preferences.getString(_syncedAtKey);
    if (raw == null || raw.isEmpty) {
      return CalendarCache(
        events: const [],
        lastSyncedAt: syncedAt == null
            ? null
            : DateTime.tryParse(syncedAt)?.toUtc(),
      );
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return CalendarCache(
      events: decoded
          .map(
            (item) => CalendarEvent.fromStorage(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((event) => !event.cancelled)
          .toList(),
      lastSyncedAt: syncedAt == null
          ? null
          : DateTime.tryParse(syncedAt)?.toUtc(),
    );
  }

  Future<void> saveCache(List<CalendarEvent> events, DateTime syncedAt) async {
    await Future.wait([
      _preferences.setString(
        _cacheKey,
        jsonEncode(events.map((event) => event.toStorage()).toList()),
      ),
      _preferences.setString(_syncedAtKey, syncedAt.toUtc().toIso8601String()),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _preferences.remove(_selectionKey),
      _preferences.remove(_cacheKey),
      _preferences.remove(_syncedAtKey),
    ]);
  }
}
