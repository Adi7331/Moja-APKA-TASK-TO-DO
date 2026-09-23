import 'package:dzien_po_dniu/focus_session.dart';
import 'package:dzien_po_dniu/focus_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('focus session store returns saved sessions newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FocusSessionStore(await SharedPreferences.getInstance());
    final older = FocusSession(
      id: 'older',
      taskId: 'task',
      startedAt: DateTime.utc(2026, 9, 11, 9),
      endedAt: DateTime.utc(2026, 9, 11, 9, 25),
      plannedWorkSeconds: 1500,
      completed: true,
    );
    final newer = FocusSession(
      id: 'newer',
      taskId: 'task',
      startedAt: DateTime.utc(2026, 9, 11, 10),
      endedAt: DateTime.utc(2026, 9, 11, 10, 10),
      plannedWorkSeconds: 1500,
      completed: false,
    );

    await store.add(older);
    await store.add(newer);

    expect((await store.load()).map((item) => item.id), ['newer', 'older']);
  });
}
