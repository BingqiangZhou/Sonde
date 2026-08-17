import 'dart:async';

import 'package:clock/clock.dart';
import 'package:sonde/core/constants/cache_constants.dart';

/// Coalesces concurrent calls behind a single in-flight future so rapid
/// triggers share one request instead of starting duplicates.
///
/// Notifiers keep one slot per logical request pipeline (e.g. initial load
/// vs. load-more) and [reset] it when their provider rebuilds or the
/// underlying data source is switched.
final class InFlightSlot<T> {
  Future<T>? _inFlight;

  /// The request currently in flight, if any.
  Future<T>? get inFlight => _inFlight;

  /// Runs [fetch], or joins the request already in flight.
  Future<T> call(Future<T> Function() fetch) {
    final running = _inFlight;
    if (running != null) return running;

    final future = fetch();
    _inFlight = future;
    unawaited(
      future.then(
        (_) => _clear(future),
        onError: (_) => _clear(future),
      ),
    );
    return future;
  }

  void _clear(Future<T> future) {
    if (identical(_inFlight, future)) _inFlight = null;
  }

  /// Drops bookkeeping without cancelling anything in flight.
  void reset() => _inFlight = null;
}

/// Tracks how long ago data was last fetched successfully so notifiers can
/// decide whether their cache window is still valid.
final class FreshnessTracker {
  FreshnessTracker({this.maxAge = CacheConstants.defaultListCacheDuration});

  /// How long a successful fetch stays considered fresh.
  final Duration maxAge;
  DateTime? _lastSuccessAt;

  bool get isFresh {
    final lastSuccessAt = _lastSuccessAt;
    if (lastSuccessAt == null) return false;
    return clock.now().difference(lastSuccessAt) < maxAge;
  }

  /// Records a successful fetch at the current time.
  void markSuccess() => _lastSuccessAt = clock.now();

  /// Makes the tracked data stale so the next load refetches.
  void reset() => _lastSuccessAt = null;
}

/// Monotonically increasing token to discard async responses that complete
/// after a newer request has started.
final class RequestToken {
  int _current = 0;

  /// The most recently issued token.
  int get current => _current;

  /// Starts a new request and returns its token.
  int begin() => ++_current;

  /// Whether [token] still refers to the most recent request.
  bool isCurrent(int token) => token == _current;

  /// Invalidates all outstanding tokens.
  void cancel() => ++_current;
}
