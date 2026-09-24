import 'package:supabase_flutter/supabase_flutter.dart';

import 'cost_item.dart';
import 'cost_sync_outbox.dart';
import 'local_cost_store.dart';

/// Supabase adapter for the private Costs tables. The client never supplies a
/// user id from local data: every write is stamped with the active account.
class CostSyncService {
  CostSyncService(this._client);

  final SupabaseClient _client;

  Future<CostSnapshot> load() async {
    if (_client.auth.currentUser == null) return const CostSnapshot();
    final results = await Future.wait([
      _client.from('cost_entries').select().order('occurred_at', ascending: false),
      _client.from('cost_subscriptions').select().order('next_payment_at'),
      _client.from('cost_categories').select().order('name'),
    ]);
    return CostSnapshot(
      entries: (results[0] as List)
          .map((row) => CostEntry.fromSupabaseRow(Map<String, dynamic>.from(row)))
          .toList(),
      subscriptions: (results[1] as List)
          .map((row) => CostSubscription.fromSupabaseRow(Map<String, dynamic>.from(row)))
          .toList(),
      categories: (results[2] as List)
          .map((row) => CostCategory.fromSupabaseRow(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  Future<void> saveEntry(CostEntry entry) async {
    final userId = _requireUserId();
    await _client.from('cost_entries').upsert(entry.toSupabasePayload(userId));
  }

  Future<void> saveSubscription(CostSubscription subscription) async {
    final userId = _requireUserId();
    await _client.from('cost_subscriptions').upsert(
      subscription.toSupabasePayload(userId),
    );
  }

  Future<void> saveCategory(CostCategory category) async {
    final userId = _requireUserId();
    await _client.from('cost_categories').upsert(
      category.toSupabasePayload(userId),
    );
  }

  Future<void> delete(CostSyncEntity entity, String id) async {
    final table = switch (entity) {
      CostSyncEntity.entry => 'cost_entries',
      CostSyncEntity.subscription => 'cost_subscriptions',
      CostSyncEntity.category => 'cost_categories',
    };
    await _client.from(table).delete().eq('id', id).eq(
      'user_id',
      _requireUserId(),
    );
  }

  String _requireUserId() => _client.auth.currentUser?.id ??
      (throw StateError('Brak aktywnego konta do synchronizacji kosztów.'));
}
