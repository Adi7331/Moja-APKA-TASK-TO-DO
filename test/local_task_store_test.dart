import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dzien_po_dniu/local_task_store.dart';
import 'package:dzien_po_dniu/task_item.dart';

void main() {
  test('saves and reloads local tasks', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalTaskStore(await SharedPreferences.getInstance());
    const task = TaskItem(id: 'local-8', title: 'Kupić mleko', status: 'todo');

    await store.save([task]);
    final restored = await store.load();

    expect(restored.single.title, 'Kupić mleko');
    expect(restored.single.id, 'local-8');
  });

  test('remembers that local tasks were migrated to the cloud', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalTaskStore(await SharedPreferences.getInstance());

    expect(store.cloudMigrationCompleted, isFalse);
    await store.markCloudMigrationCompleted();

    expect(store.cloudMigrationCompleted, isTrue);
  });
}
