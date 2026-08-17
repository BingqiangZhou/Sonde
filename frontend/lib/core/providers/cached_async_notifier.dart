import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/core/utils/request_dedup.dart';

/// [AsyncNotifier] skeleton for "fetch once, keep fresh, dedupe in-flight"
/// providers.
///
/// [load] provides the shared lifecycle the stats/history notifiers used to
/// copy-paste:
/// - skip the fetch while the previous data is inside the freshness window
///   (unless [forceRefresh] or the last attempt errored)
/// - coalesce concurrent loads behind the request already in flight
/// - surface [AsyncValue.loading] only when there is no data to show yet
/// - on failure keep the previous data (an error state is only set when
///   nothing was loaded before) and hand the error to [onError]
abstract class CachedAsyncNotifier<T> extends AsyncNotifier<T?> {
  CachedAsyncNotifier({
    Duration maxAge = CacheConstants.defaultListCacheDuration,
  }) : _freshness = FreshnessTracker(maxAge: maxAge);

  final FreshnessTracker _freshness;
  final InFlightSlot<T?> _loadSlot = InFlightSlot<T?>();
  bool _isDisposed = false;

  /// Fetches a fresh value from the data source.
  Future<T> fetch();

  /// Error hook for logging / auth re-checks. Must not throw.
  void onError(Object error, StackTrace stackTrace) {}

  @override
  FutureOr<T?> build() {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh => _freshness.isFresh;

  Future<T?> load({bool forceRefresh = false}) {
    // A previous error should always be retried, cache window or not.
    final effectiveForce = forceRefresh || state.hasError;
    final previousData = state.value;

    if (!effectiveForce && previousData != null && _freshness.isFresh) {
      return Future<T?>.value(previousData);
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null) return inFlight;

    if (previousData == null && !_isDisposed) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await fetch();
        _freshness.markSuccess();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        onError(error, stackTrace);
        if (!_isDisposed && previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        }
        // With previous data available, keep showing it — a failed refresh
        // must not blank a working list.
        return previousData;
      }
    });
  }

  /// Resets the cache bookkeeping.
  void resetCache() {
    _freshness.reset();
    _loadSlot.reset();
  }

  /// Resets cache and state (server switch, logout).
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }
}
