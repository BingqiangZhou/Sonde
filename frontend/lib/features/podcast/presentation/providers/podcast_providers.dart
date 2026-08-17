import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/request_dedup.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_playback_providers.dart';

// =============================================================================
// Core Providers (from podcast_core_providers.dart)
// =============================================================================

final podcastApiServiceProvider = Provider<PodcastApiService>((ref) {
  final dio = ref.read(dioClientProvider).dio;
  return PodcastApiService(dio);
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  final apiService = ref.read(podcastApiServiceProvider);
  return PodcastRepository(apiService);
});

/// Provides the singleton [PodcastAudioHandler] managed by Riverpod.
///
/// The handler is created once and shared across all features that need
/// audio playback. It is disposed when the provider scope is disposed.
final audioHandlerProvider = Provider<PodcastAudioHandler>((ref) {
  final handler = PodcastAudioHandler();
  ref.onDispose(handler.stopService);
  return handler;
});

// =============================================================================
// Subscription Providers (from podcast_subscription_providers.dart)
// =============================================================================

final podcastSubscriptionProvider =
    NotifierProvider<PodcastSubscriptionNotifier, PodcastSubscriptionState>(
      PodcastSubscriptionNotifier.new,
    );

class PodcastSubscriptionNotifier extends Notifier<PodcastSubscriptionState> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  bool _isLoadingSubscriptions = false;
  bool _isLoadingMoreSubscriptions = false;

  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState();
  }

  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {
    // Guard against concurrent invocation
    if (_isLoadingSubscriptions) return;
    _isLoadingSubscriptions = true;

    try {
      // Check if data is fresh and skip refresh if not forced
      if (!forceRefresh && page == 1 && state.isDataFresh()) {
        logger.AppLogger.debug(
          '[Playback] Using cached subscription data (fresh within 5 min)',
        );
        return;
      }

      state = state.copyWith(isLoading: true, clearError: true);

      final response = await _repository.listSubscriptions(
        page: page,
        size: size,
        categoryId: categoryId,
        status: status,
      );

      state = state.copyWith(
        subscriptions: response.subscriptions,
        hasMore: page < response.pages,
        nextPage: page < response.pages ? page + 1 : null,
        currentPage: page,
        total: response.total,
        isLoading: false,
        clearError: true,
        lastRefreshTime: DateTime.now(), // Record refresh time
      );
      logger.AppLogger.debug(
        '[OK] Subscription data loaded at ${DateTime.now()} (total=${response.total}, count=${response.subscriptions.length})',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: mapErrorMessage(error));
    } finally {
      _isLoadingSubscriptions = false;
    }
  }

  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {
    if (state.isLoadingMore || !state.hasMore) return;

    // Guard against concurrent invocation
    if (_isLoadingMoreSubscriptions) return;
    _isLoadingMoreSubscriptions = true;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.listSubscriptions(
        page: state.nextPage ?? 1,
        size: 10,
        categoryId: categoryId,
        status: status,
      );

      state = state.copyWith(
        subscriptions: [...state.subscriptions, ...response.subscriptions],
        hasMore: (state.nextPage ?? 1) < response.pages,
        nextPage: (state.nextPage ?? 1) < response.pages
            ? (state.nextPage ?? 1) + 1
            : null,
        currentPage: state.nextPage ?? 1,
        total: response.total,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: mapErrorMessage(error));
    } finally {
      _isLoadingMoreSubscriptions = false;
    }
  }

  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {
    state = const PodcastSubscriptionState();
    await loadSubscriptions(
      categoryId: categoryId,
      status: status,
    );
  }

  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) async {
    // Mark as subscribing
    state = state.copyWith(
      subscribingFeedUrls: {...state.subscribingFeedUrls, feedUrl},
    );

    try {
      final subscription = await _repository.addSubscription(
        feedUrl: feedUrl,
        categoryIds: categoryIds,
      );

      // Optimistic update: add new subscription to local list
      state = state.copyWith(
        subscriptions: [subscription, ...state.subscriptions],
        total: state.total + 1,
        subscribingFeedUrls: state.subscribingFeedUrls
            .where((url) => url != feedUrl)
            .toSet(),
      );

      return subscription;
    } catch (error) {
      // Remove from subscribing set
      state = state.copyWith(
        subscribingFeedUrls: state.subscribingFeedUrls
            .where((url) => url != feedUrl)
            .toSet(),
      );
      rethrow;
    }
  }

  Future<void> deleteSubscription(int subscriptionId) async {
    // Optimistic update: remove from local list immediately
    final updatedSubscriptions = state.subscriptions
        .where((s) => s.id != subscriptionId)
        .toList();

    try {
      await _repository.deleteSubscription(subscriptionId);

      state = state.copyWith(
        subscriptions: updatedSubscriptions,
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } catch (error) {
      // Revert: reload from server on failure (fire-and-forget to avoid nested throw)
      state = state.copyWith(error: mapErrorMessage(error));
      unawaited(refreshSubscriptions());
    }
  }

  Future<PodcastSubscriptionBulkDeleteResponse> bulkDeleteSubscriptions({
    required List<int> subscriptionIds,
  }) async {
    // Optimistic update: remove from local list immediately
    final idSet = subscriptionIds.toSet();
    final updatedSubscriptions = state.subscriptions
        .where((s) => !idSet.contains(s.id))
        .toList();

    try {
      logger.AppLogger.debug(
        '[Playback] Bulk delete request: subscriptionIds=$subscriptionIds',
      );

      final response = await _repository.bulkDeleteSubscriptions(
        subscriptionIds: subscriptionIds,
      );

      logger.AppLogger.debug(
        '[OK] Bulk delete success: ${response.successCount} deleted, ${response.failedCount} failed',
      );

      state = state.copyWith(
        subscriptions: updatedSubscriptions,
        total: state.total > response.successCount
            ? state.total - response.successCount
            : 0,
      );

      return response;
    } catch (error) {
      logger.AppLogger.debug('[Error] Bulk delete failed: $error');
      // Revert: reload from server on failure (fire-and-forget to avoid nested throw)
      state = state.copyWith(error: mapErrorMessage(error));
      unawaited(refreshSubscriptions());
      rethrow;
    }
  }

  Future<void> refreshSubscription(int subscriptionId) async {
    try {
      await _repository.refreshSubscription(subscriptionId);

      // Refresh the list
      await refreshSubscriptions();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> reparseSubscription(int subscriptionId, bool forceAll) async {
    try {
      await _repository.reparseSubscription(subscriptionId, forceAll);

      // Refresh the list
      await refreshSubscriptions();
    } catch (error) {
      rethrow;
    }
  }
}

// Derived selectors (moved from podcast_subscription_selectors.dart)

final subscribedNormalizedFeedUrlsProvider = Provider<Set<String>>((ref) {
  final subscriptions = ref.watch(
    podcastSubscriptionProvider.select((state) => state.subscriptions),
  );
  return UnmodifiableSetView(
    subscriptions
        .map((sub) => PodcastUrlUtils.normalizeFeedUrl(sub.sourceUrl))
        .toSet(),
  );
});

final subscribingNormalizedFeedUrlsProvider = Provider<Set<String>>((ref) {
  final subscribingFeedUrls = ref.watch(
    podcastSubscriptionProvider.select((state) => state.subscribingFeedUrls),
  );
  return UnmodifiableSetView(
    subscribingFeedUrls.map(PodcastUrlUtils.normalizeFeedUrl).toSet(),
  );
});

// =============================================================================
// Stats Providers (from podcast_stats_providers.dart)
// =============================================================================

// === Stats Provider ===
final podcastStatsProvider =
    AsyncNotifierProvider<PodcastStatsNotifier, PodcastStatsResponse?>(
      PodcastStatsNotifier.new,
    );

class PodcastStatsNotifier extends AsyncNotifier<PodcastStatsResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final InFlightSlot<PodcastStatsResponse?> _loadSlot =
      InFlightSlot<PodcastStatsResponse?>();
  final FreshnessTracker _freshness = FreshnessTracker();
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PodcastStatsResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh => _freshness.isFresh;

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PodcastStatsResponse?> runWithCache({
    required Future<PodcastStatsResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await fetcher();
        _freshness.markSuccess();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (!_isDisposed) {
          state = AsyncValue.error(error, stackTrace);
          if (previousData != null) {
            Future.microtask(() {
              if (!_isDisposed) {
                state = AsyncValue.data(previousData);
              }
            });
          }
        }
        return previousData;
      }
    });
  }

  /// Resets the cache state.
  void resetCache() {
    _freshness.reset();
    _loadSlot.reset();
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  Future<PodcastStatsResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load podcast stats: $error');
      },
    );
  }

  /// Reset the notifier state completely.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }
}

final profileStatsProvider =
    AsyncNotifierProvider<ProfileStatsNotifier, ProfileStatsModel?>(
      ProfileStatsNotifier.new,
    );
class ProfileStatsNotifier extends AsyncNotifier<ProfileStatsModel?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final InFlightSlot<ProfileStatsModel?> _loadSlot = InFlightSlot<ProfileStatsModel?>();
  final FreshnessTracker _freshness = FreshnessTracker();
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<ProfileStatsModel?> build() async {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh => _freshness.isFresh;

  /// Executes [fetcher] with cache-aware deduplication.
  Future<ProfileStatsModel?> runWithCache({
    required Future<ProfileStatsModel> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await fetcher();
        _freshness.markSuccess();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      }
    });
  }

  /// Resets the cache state.
  void resetCache() {
    _freshness.reset();
    _loadSlot.reset();
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }

  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    // If has error or loading, skip cache check and continue to fetch
    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getProfileStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load profile stats: $error');
      },
    );
  }
}

final playbackHistoryProvider =
    AsyncNotifierProvider<PlaybackHistoryNotifier, PodcastEpisodeListResponse?>(
      PlaybackHistoryNotifier.new,
    );

class PlaybackHistoryNotifier
    extends AsyncNotifier<PodcastEpisodeListResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final InFlightSlot<PodcastEpisodeListResponse?> _loadSlot = InFlightSlot<PodcastEpisodeListResponse?>();
  final FreshnessTracker _freshness = FreshnessTracker();
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PodcastEpisodeListResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh => _freshness.isFresh;

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PodcastEpisodeListResponse?> runWithCache({
    required Future<PodcastEpisodeListResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await fetcher();
        _freshness.markSuccess();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      }
    });
  }

  /// Resets the cache state.
  void resetCache() {
    _freshness.reset();
    _loadSlot.reset();
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  Future<PodcastEpisodeListResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getPlaybackHistory(size: 100),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load playback history: $error');
      },
    );
  }

  /// Reset the notifier state completely.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }
}

final playbackHistoryLiteProvider =
    AsyncNotifierProvider<
      PlaybackHistoryLiteNotifier,
      PlaybackHistoryLiteResponse?
    >(PlaybackHistoryLiteNotifier.new);
class PlaybackHistoryLiteNotifier
    extends AsyncNotifier<PlaybackHistoryLiteResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final InFlightSlot<PlaybackHistoryLiteResponse?> _loadSlot = InFlightSlot<PlaybackHistoryLiteResponse?>();
  final FreshnessTracker _freshness = FreshnessTracker();
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh => _freshness.isFresh;

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PlaybackHistoryLiteResponse?> runWithCache({
    required Future<PlaybackHistoryLiteResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _loadSlot.inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    return _loadSlot(() async {
      try {
        final data = await fetcher();
        _freshness.markSuccess();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      }
    });
  }

  /// Resets the cache state.
  void resetCache() {
    _freshness.reset();
    _loadSlot.reset();
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }

  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    // If has error or loading, skip cache check and continue to fetch
    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getPlaybackHistoryLite(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load playback history lite: $error');
      },
    );
  }
}
