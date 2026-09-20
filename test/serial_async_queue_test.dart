import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/serial_async_queue.dart';

void main() {
  test('runs a later save only after the active save completes', () async {
    final queue = SerialAsyncQueue();
    final first = Completer<void>();
    final events = <String>[];

    final firstSave = queue.run(() async {
      events.add('first-start');
      await first.future;
      events.add('first-end');
    });
    final secondSave = queue.run(() async {
      events.add('second');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);

    first.complete();
    await Future.wait([firstSave, secondSave]);

    expect(events, ['first-start', 'first-end', 'second']);
  });

  test('continues with a later save after an earlier save fails', () async {
    final queue = SerialAsyncQueue();
    final events = <String>[];

    await expectLater(queue.run<void>(() async => throw StateError('offline')), throwsStateError);
    await queue.run(() async => events.add('retried'));

    expect(events, ['retried']);
  });
}
