import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/cost_sync_outbox.dart';

void main() {
  test('keeps only the latest offline snapshot for one cost item', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final outbox = CostSyncOutbox(preferences);

    await outbox.enqueue(
      entity: CostSyncEntity.subscription,
      id: 'sub-1',
      payload: const {'name': 'Old name'},
    );
    await outbox.enqueue(
      entity: CostSyncEntity.subscription,
      id: 'sub-1',
      payload: const {'name': 'Updated name'},
    );

    final pending = await CostSyncOutbox(preferences).load();
    expect(pending, hasLength(1));
    expect(pending.single.payload['name'], 'Updated name');
    expect(pending.single.isDelete, isFalse);
  });

  test('a pending delete replaces a pending save for the same item', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final outbox = CostSyncOutbox(preferences);

    await outbox.enqueue(
      entity: CostSyncEntity.entry,
      id: 'entry-1',
      payload: const {'title': 'Wydatek'},
    );
    await outbox.enqueueDelete(
      entity: CostSyncEntity.entry,
      id: 'entry-1',
    );

    final pending = await outbox.load();
    expect(pending, hasLength(1));
    expect(pending.single.isDelete, isTrue);
    expect(pending.single.payload, isEmpty);
  });
}
