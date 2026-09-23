import 'package:supabase_flutter/supabase_flutter.dart';

import 'focus_session.dart';

/// Syncs focus history only after the private `focus_sessions` schema has
/// been deployed. It never reads or stores Google Calendar credentials.
class FocusSessionSyncService {
  FocusSessionSyncService(this._client);

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw StateError('Zaloguj się, aby synchronizować historię skupienia.'));

  Future<List<FocusSession>> load() async {
    final rows = await _client
        .from('focus_sessions')
        .select()
        .eq('user_id', _userId)
        .order('started_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .map(FocusSession.fromSupabaseRow)
        .toList();
  }

  Future<void> save(FocusSession session) => _client
      .from('focus_sessions')
      .upsert(session.toSupabasePayload(_userId), onConflict: 'id');

  Future<void> importLocal(Iterable<FocusSession> sessions) async {
    for (final session in sessions) {
      await save(session);
    }
  }
}
