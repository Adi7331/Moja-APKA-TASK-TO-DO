import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'focus_session.dart';

class FocusSessionStore {
  FocusSessionStore(this._preferences);

  static const _key = 'focus_sessions_v1';
  final SharedPreferences _preferences;

  Future<List<FocusSession>> load() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final sessions = decoded
        .map(
          (item) =>
              FocusSession.fromStorage(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> add(FocusSession session) async {
    final sessions = [...await load()];
    sessions.removeWhere((item) => item.id == session.id);
    sessions.add(session);
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _preferences.setString(
      _key,
      jsonEncode(sessions.map((item) => item.toStorage()).toList()),
    );
  }
}
