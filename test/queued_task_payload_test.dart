import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/task_item.dart';
import 'package:dzien_po_dniu/task_sync_service.dart';

void main() {
  test('retrying an offline creation retains status and appearance', () {
    final completed = TaskItem(
      id: 'task-id',
      title: 'Zrobione offline',
      status: 'done',
      completedAt: DateTime(2026, 10, 13, 9),
      emoji: '✅',
      colorKey: 'mint',
    );

    final payload = queuedTaskPayload(completed, 'owner-id');
    expect(payload['id'], 'task-id');
    expect(payload['user_id'], 'owner-id');
    expect(payload['status'], 'done');
    expect(payload['emoji'], '✅');
    expect(payload['color_key'], 'mint');
    expect(payload['completed_at'], isNotNull);
  });
}
