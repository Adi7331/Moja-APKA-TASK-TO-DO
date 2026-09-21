import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/task_category.dart';
import 'package:dzien_po_dniu/task_category_sync_outbox.dart';

void main() {
  test('category outbox keeps only the newest operation per category', () async {
    SharedPreferences.setMockInitialValues({});
    final store = TaskCategorySyncOutbox(
      await SharedPreferences.getInstance(),
    );
    final category = TaskCategory(
      id: 'category-1',
      userId: 'user-1',
      name: 'Finanse',
      color: '#2F6FED',
      createdAt: DateTime.utc(2026, 9, 20),
      updatedAt: DateTime.utc(2026, 9, 20),
    );

    await store.enqueueUpsert(category);
    await store.enqueueDelete(category);

    final pending = await store.load();
    expect(pending, hasLength(1));
    expect(pending.single.kind, TaskCategorySyncOperationKind.delete);
  });
}
