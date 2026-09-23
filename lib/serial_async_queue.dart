import 'dart:async';

/// Keeps writes for one record in order while allowing the next write to run
/// even when a preceding network attempt fails.
class SerialAsyncQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}
