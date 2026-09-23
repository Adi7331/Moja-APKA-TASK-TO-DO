import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dzien_po_dniu/local_task_category_store.dart';
import 'package:dzien_po_dniu/task_category.dart';

void main() {
  test('keeps categories on the device while cloud sync is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalTaskCategoryStore(await SharedPreferences.getInstance());
    final category = TaskCategory(
      id: 'ca62b3c5-b874-46de-8c7b-8373ed0b017d',
      userId: 'local-user',
      name: 'Finanse',
      color: '#2F6FED',
      createdAt: DateTime.utc(2026, 9, 20),
      updatedAt: DateTime.utc(2026, 9, 20),
    );

    await store.save([category]);

    expect((await store.load()).single, category);
  });
}
