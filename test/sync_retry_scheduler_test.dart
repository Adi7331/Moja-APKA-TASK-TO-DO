import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/sync_retry_scheduler.dart';

void main() {
  testWidgets('retries after network recovery while app remains open', (
    tester,
  ) async {
    var attempts = 0;
    final scheduler = SyncRetryScheduler(
      interval: const Duration(seconds: 30),
      synchronize: () async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      },
    );
    scheduler.start();

    await tester.pump(const Duration(seconds: 30));
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(attempts, 2);
    scheduler.dispose();
  });

  testWidgets('does not run two overlapping sync attempts', (tester) async {
    final pending = Completer<void>();
    var attempts = 0;
    final scheduler = SyncRetryScheduler(
      interval: const Duration(seconds: 30),
      synchronize: () {
        attempts++;
        return pending.future;
      },
    );
    scheduler.start();

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(attempts, 1);
    pending.complete();
    await tester.pump();
    scheduler.dispose();
  });
}
