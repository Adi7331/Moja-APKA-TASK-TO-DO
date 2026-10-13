import 'dart:async';

/// Repeats pending sync while the app is open, without overlapping attempts.
class SyncRetryScheduler {
  SyncRetryScheduler({required this.interval, required this.synchronize});

  final Duration interval;
  final Future<void> Function() synchronize;
  Timer? _timer;
  bool _running = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(retryNow()));
  }

  Future<void> retryNow() async {
    if (_running) return;
    _running = true;
    try {
      await synchronize();
    } catch (_) {
      // The next pulse or app resume retries the durable queue.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
