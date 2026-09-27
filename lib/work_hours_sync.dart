import 'package:supabase_flutter/supabase_flutter.dart';

import 'work_hours_store.dart';

class WorkHoursSync {
  WorkHoursSync(this.client, this.store);
  final SupabaseClient client;
  final WorkHoursStore store;
  bool _running = false;
  bool _closed = false;
  bool get _authorized =>
      !_closed && client.auth.currentUser?.id == store.ownerId;
  void close() => _closed = true;

  Future<void> synchronize() async {
    if (_running || !_authorized) return;
    _running = true;
    try {
      await store.flushed;
      for (final op in store.pending) {
        if (!_authorized) return;
        final payload = Map<String, dynamic>.from(op['payload'] as Map)
          ..['user_id'] = store.ownerId;
        await client
            .from(
              op['settings'] == true
                  ? 'work_hour_settings'
                  : 'work_hour_entries',
            )
            .upsert(payload);
        if (!_authorized) return;
        await store.acknowledge(op);
      }
      if (!_authorized) return;
      final rows = await client
          .from('work_hour_entries')
          .select()
          .eq('user_id', store.ownerId);
      final settings = await client
          .from('work_hour_settings')
          .select()
          .eq('user_id', store.ownerId)
          .maybeSingle();
      if (!_authorized) return;
      await store.mergeRemote(
        rows.map((r) => Map<String, dynamic>.from(r)).toList(),
        (settings?['rate_cents'] as num?)?.toInt(),
      );
    } finally {
      _running = false;
    }
  }
}
