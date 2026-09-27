import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'work_hours.dart';

/// One durable snapshot includes data AND pending operations. A failed disk
/// write never publishes an in-memory success. Writes are serialized.
class WorkHoursStore extends ChangeNotifier {
  WorkHoursStore(this.preferences, this.ownerId) {
    final raw = preferences.getString(_key);
    _data = raw == null
        ? {'entries': <dynamic>[], 'pending': <dynamic>[], 'rate': 0}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }
  final SharedPreferences preferences;
  final String ownerId;
  late Map<String, dynamic> _data;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  String get _key => 'work_hours_v1_$ownerId';
  List<WorkEntry> get entries => (_data['entries'] as List)
      .map((r) => WorkEntry.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
  List<Map<String, dynamic>> get pending => (_data['pending'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  int get rateCents => (_data['rate'] as num).toInt();
  Future<void> get flushed => _tail;

  Future<void> _write(void Function(Map<String, dynamic>) mutate) {
    final result = _tail.then((_) async {
      final next = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(_data)) as Map,
      );
      mutate(next);
      if (!await preferences.setString(_key, jsonEncode(next))) {
        throw StateError('Nie udało się zapisać danych na urządzeniu.');
      }
      _data = next;
      if (!_disposed) notifyListeners();
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  void _enqueue(
    Map<String, dynamic> data,
    String id,
    Map<String, dynamic> payload, {
    bool deleted = false,
    bool settings = false,
  }) {
    final pending = data['pending'] as List;
    pending.removeWhere((p) => p['id'] == id && p['settings'] == settings);
    pending.add({
      'id': id,
      'payload': payload,
      'deleted': deleted,
      'settings': settings,
      'revision': DateTime.now().microsecondsSinceEpoch.toString(),
    });
  }

  Future<void> put(WorkEntry item) => _put(item, false);
  Future<void> restore(WorkEntry item) => _put(item, true);
  Future<void> _put(WorkEntry item, bool restoring) {
    if (item.validationError != null) {
      return Future.error(ArgumentError(item.validationError));
    }
    return _write((data) {
      final payload = item.toJson()
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String()
        ..['restore_requested'] = restoring;
      final entries = data['entries'] as List;
      entries.removeWhere((row) => row['id'] == item.id);
      entries.add(payload);
      _enqueue(data, item.id, payload);
    });
  }

  Future<void> remove(String id) => _write((data) {
    final entries = data['entries'] as List;
    final row = entries.where((r) => r['id'] == id).firstOrNull;
    if (row == null) return;
    final payload = Map<String, dynamic>.from(row as Map);
    payload['deleted_at'] = DateTime.now().toUtc().toIso8601String();
    payload['updated_at'] = payload['deleted_at'];
    entries.removeWhere((r) => r['id'] == id);
    _enqueue(data, id, payload, deleted: true);
  });
  Future<void> setRate(int cents) {
    if (cents < 0 || cents > 100000000) {
      return Future.error(ArgumentError('Niepoprawna stawka.'));
    }
    return _write((data) {
      data['rate'] = cents;
      _enqueue(data, ownerId, {
        'rate_cents': cents,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, settings: true);
    });
  }

  Future<void> acknowledge(Map<String, dynamic> operation) => _write((data) {
    (data['pending'] as List).removeWhere(
      (p) => jsonEncode(p) == jsonEncode(operation),
    );
  });
  Future<void> mergeRemote(List<Map<String, dynamic>> rows, int? remoteRate) =>
      _write((data) {
        final operations = (data['pending'] as List);
        final byId = {
          for (final row in data['entries'] as List)
            row['id'] as String: Map<String, dynamic>.from(row as Map),
        };
        for (final row in rows) {
          if (operations.any(
            (op) => op['id'] == row['id'] && op['settings'] != true,
          )) {
            continue;
          }
          if (row['deleted_at'] != null) {
            byId.remove(row['id']);
          } else {
            byId[row['id'] as String] = WorkEntry.fromJson(row).toJson();
          }
        }
        data['entries'] = byId.values.toList();
        if (remoteRate != null &&
            !operations.any((p) => p['settings'] == true)) {
          data['rate'] = remoteRate;
        }
      });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
