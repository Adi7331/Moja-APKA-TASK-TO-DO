import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/android_widget_snapshot.dart';

void main() {
  test('today widget keeps only the first three pending tasks', () {
    final snapshot = AndroidWidgetSnapshot.fromData(
      tasks: const [
        WidgetTaskData(id: '1', title: 'Pierwsze', isDone: false),
        WidgetTaskData(id: '2', title: 'Drugie', isDone: false),
        WidgetTaskData(id: '3', title: 'Trzecie', isDone: false),
        WidgetTaskData(id: '4', title: 'Czwarte', isDone: false),
        WidgetTaskData(id: 'done', title: 'Gotowe', isDone: true),
      ],
      selectedNote: const WidgetNoteData(
        id: 'note-1',
        title: 'Lista',
        preview: 'Mleko i chleb',
      ),
    );

    expect(snapshot.todayTasks.map((task) => task.id), ['1', '2', '3']);
    expect(snapshot.remainingTaskCount, 4);
    expect(snapshot.selectedNote?.title, 'Lista');
  });

  test('snapshot payload is JSON-safe for the native bridge', () {
    final snapshot = AndroidWidgetSnapshot.fromData(
      tasks: const [WidgetTaskData(id: '1', title: 'Zadanie', isDone: false)],
      selectedNote: null,
    );

    expect(snapshot.toChannelPayload(), {
      'remainingTaskCount': 1,
      'tasks': [
        {'id': '1', 'title': 'Zadanie'},
      ],
      'selectedNote': null,
    });
  });
}
