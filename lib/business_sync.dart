import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_store.dart';

class BusinessSync {
  BusinessSync(this.client, this.store);
  final SupabaseClient client;
  final BusinessStore store;
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
      for (final operation in store.snapshot.pending) {
        if (!_authorized) return;
        final kind = operation['kind'] as String;
        final id = operation['id'] as String;
        final payload = Map<String, dynamic>.from(operation['data'] as Map);
        if (kind == 'product' &&
            payload['imageLocalPath'] != null &&
            payload['imageStoragePath'] == null) {
          final file = File(payload['imageLocalPath'] as String);
          if (await file.exists()) {
            final fileName = file.uri.pathSegments.isEmpty
                ? 'image'
                : file.uri.pathSegments.last;
            final path = '${store.ownerId}/products/$id/$fileName';
            await client.storage
                .from('business-assets')
                .upload(
                  path,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            payload['imageStoragePath'] = path;
            await store.patchProductPhoto(id, path);
            await store.flushed;
          }
        }
        if (!_authorized) return;
        await client.from('business_records').upsert({
          'id': id,
          'user_id': store.ownerId,
          'kind': kind,
          'payload': payload,
          'deleted_at': operation['deleted'] == true
              ? operation['updatedAt']
              : null,
          'updated_at': operation['updatedAt'],
        }, onConflict: 'user_id,id');
        if (!_authorized) return;
        await store.acknowledge(operation);
      }
      if (!_authorized) return;
      final rows = await client
          .from('business_records')
          .select()
          .eq('user_id', store.ownerId);
      if (_authorized) {
        await store.mergeRemote(
          rows.map((row) => Map<String, dynamic>.from(row)).toList(),
        );
      }
    } finally {
      _running = false;
    }
  }
}
