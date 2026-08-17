import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/providers/cached_async_notifier.dart';
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
// PodcastAudioHandler lives in the podcast_playback_providers library
// (audio_handler.dart is a part of it), so this import is structural and
// intentionally cyclic with podcast_playback_providers.dart.
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
  // Single token covering both initial loads and load-more so a page-1
  // refresh discards an in-flight append (and vice versa) instead of
  // interleaving stale pages into the refreshed list.
  final RequestToken _listToken = RequestToken();

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
    if (state.isLoading) return;
    final token = _listToken.begin();

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

      if (!_listToken.isCurrent(token)) return;

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
      if (!_listToken.isCurrent(token)) return;
      state = state.copyWith(isLoading: false, error: mapErrorMessage(error));
    }
  }

  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {
    if (state.isLoadingMore || !state.hasMore) return;
    final token = _listToken.begin();

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.nextPage ?? 1;

    try {
      final response = await _repository.listSubscriptions(
        page: nextPage,
        size: 10,
        categoryId: categoryId,
        status: status,
      );

      if (!_listToken.isCurrent(token)) return;

      state = state.copyWith(
        subscriptions: [...state.subscriptions, ...response.subscriptions],
        hasMore: nextPage < response.pages,
        nextPage: nextPage < response.pages ? nextPage + 1 : null,
        currentPage: nextPage,
        total: response.total,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      if (!_listToken.isCurrent(token)) return;
      state = state.copyWith(isLoadingMore: false, error: mapErrorMessage(error));
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
    await _repository.refreshSubscription(subscriptionId);

    // Refresh the list
    await refreshSubscriptions();
  }

  Future<void> reparseSubscription(int subscriptionId, bool forceAll) async {
    await _repository.reparseSubscription(subscriptionId, forceAll);

    // Refresh the list
    await refreshSubscriptions();
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

class PodcastStatsNotifier extends CachedAsyncNotifier<PodcastStatsResponse> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  Future<PodcastStatsResponse> fetch() => _repository.getStats();

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.AppLogger.debug('Failed to load podcast stats: $error');
  }
}

final profileStatsProvider =
    AsyncNotifierProvider<ProfileStatsNotifier, ProfileStatsModel?>(
      ProfileStatsNotifier.new,
    );
class ProfileStatsNotifier extends CachedAsyncNotifier<ProfileStatsModel> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  Future<ProfileStatsModel> fetch() => _repository.getProfileStats();

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.AppLogger.debug('Failed to load profile stats: $error');
  }
}

final playbackHistoryProvider =
    AsyncNotifierProvider<PlaybackHistoryNotifier, PodcastEpisodeListResponse?>(
      PlaybackHistoryNotifier.new,
    );

class PlaybackHistoryNotifier
    extends CachedAsyncNotifier<PodcastEpisodeListResponse> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  Future<PodcastEpisodeListResponse> fetch() =>
      _repository.getPlaybackHistory(size: 100);

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.AppLogger.debug('Failed to load playback history: $error');
  }
}

final playbackHistoryLiteProvider =
    AsyncNotifierProvider<
      PlaybackHistoryLiteNotifier,
      PlaybackHistoryLiteResponse?
    >(PlaybackHistoryLiteNotifier.new);
class PlaybackHistoryLiteNotifier
    extends CachedAsyncNotifier<PlaybackHistoryLiteResponse> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  Future<PlaybackHistoryLiteResponse> fetch() =>
      _repository.getPlaybackHistoryLite();

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.AppLogger.debug('Failed to load playback history lite: $error');
  }
}
