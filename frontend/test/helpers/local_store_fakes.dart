import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_playback_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_queue_model.dart';
import 'package:sonde/features/podcast/data/models/profile_stats_model.dart';
import 'package:sonde/features/podcast/data/services/local_podcast_store.dart';

/// Scripted [LocalQueueStore] for provider tests: serves queued responses
/// and records calls, mirroring the old fake-repository style.
class ScriptedLocalQueueStore extends LocalQueueStore {
  ScriptedLocalQueueStore({
    this.addDelay = Duration.zero,
    List<PodcastQueueModel>? queuedGetQueueResponses,
    List<PodcastQueueModel>? queuedAddQueueResponses,
    PodcastQueueModel? reorderQueueResult,
    PodcastQueueModel? activateQueueResult,
    PodcastQueueModel? removeQueueResult,
  }) : _queuedGetQueueResponses = List<PodcastQueueModel>.from(
         queuedGetQueueResponses ?? const <PodcastQueueModel>[],
       ),
       _queuedAddQueueResponses = List<PodcastQueueModel>.from(
         queuedAddQueueResponses ?? const <PodcastQueueModel>[],
       ),
       _reorderQueueResult = reorderQueueResult ?? const PodcastQueueModel(),
       _activateQueueResult =
           activateQueueResult ?? const PodcastQueueModel(),
       _removeQueueResult = removeQueueResult ?? const PodcastQueueModel(),
       super(throwawayMemoryDb());

  final Duration addDelay;
  final List<PodcastQueueModel> _queuedGetQueueResponses;
  final List<PodcastQueueModel> _queuedAddQueueResponses;
  final PodcastQueueModel _reorderQueueResult;
  final PodcastQueueModel _activateQueueResult;
  final PodcastQueueModel _removeQueueResult;

  int getQueueCallCount = 0;
  int addQueueItemCallCount = 0;
  int removeQueueItemCallCount = 0;
  int activateQueueItemCallCount = 0;
  int completeQueueCurrentCallCount = 0;
  List<int> lastReorderEpisodeIds = const <int>[];
  int? lastSetCurrentEpisodeId;
  int? lastRemovedEpisodeId;

  @override
  Future<PodcastQueueModel> getQueue() async {
    getQueueCallCount++;
    if (addDelay != Duration.zero) {
      await Future<void>.delayed(addDelay);
    }
    if (_queuedGetQueueResponses.isEmpty) return const PodcastQueueModel();
    if (_queuedGetQueueResponses.length == 1) {
      return _queuedGetQueueResponses.first;
    }
    return _queuedGetQueueResponses.removeAt(0);
  }

  @override
  Future<PodcastQueueModel> addQueueItem(int episodeId) async {
    addQueueItemCallCount++;
    if (_queuedAddQueueResponses.isEmpty) return const PodcastQueueModel();
    if (_queuedAddQueueResponses.length == 1) {
      return _queuedAddQueueResponses.first;
    }
    return _queuedAddQueueResponses.removeAt(0);
  }

  @override
  Future<PodcastQueueModel> removeQueueItem(int episodeId) async {
    removeQueueItemCallCount++;
    lastRemovedEpisodeId = episodeId;
    return _removeQueueResult;
  }

  @override
  Future<PodcastQueueModel> reorderQueueItems(List<int> episodeIds) async {
    lastReorderEpisodeIds = List<int>.from(episodeIds);
    return _reorderQueueResult;
  }

  @override
  Future<PodcastQueueModel> setQueueCurrent(int episodeId) async {
    lastSetCurrentEpisodeId = episodeId;
    return PodcastQueueModel(currentEpisodeId: episodeId);
  }

  @override
  Future<PodcastQueueModel> activateQueueEpisode(int episodeId) async {
    activateQueueItemCallCount++;
    return _activateQueueResult;
  }

  @override
  Future<PodcastQueueModel> completeQueueCurrent() async {
    completeQueueCurrentCallCount++;
    return const PodcastQueueModel();
  }
}

/// Scripted [LocalPlaybackStore]: rate/history/stats responses plus a
/// position map; overlay is a passthrough by default.
class ScriptedLocalPlaybackStore extends LocalPlaybackStore {
  ScriptedLocalPlaybackStore({
    this.effectiveRateResponse,
    this.effectiveRateError,
    this.applyRateResponse,
    this.historyFullResponse,
    this.historyLiteResponse,
    this.profileStatsResponse,
    Map<int, int>? positionsById,
  })  : positionsById = positionsById ?? <int, int>{},
        super(throwawayMemoryDb());

  final PlaybackRateEffectiveResponse? effectiveRateResponse;
  final Object? effectiveRateError;
  final List<int?> effectiveRateRequests = <int?>[];
  final PlaybackRateEffectiveResponse? applyRateResponse;
  final PodcastEpisodeListResponse? historyFullResponse;
  final PlaybackHistoryLiteResponse? historyLiteResponse;
  final ProfileStatsModel? profileStatsResponse;
  final Map<int, int> positionsById;

  final savedProgress = <({int episodeId, int positionSec, bool isPlaying})>[];
  final appliedRates =
      <({double rate, bool applyToSubscription, int? subscriptionId})>[];

  @override
  Future<void> saveProgress({
    required int episodeId,
    required int positionSec,
    required bool isPlaying,
    double? playbackRate,
  }) async {
    savedProgress.add(
      (episodeId: episodeId, positionSec: positionSec, isPlaying: isPlaying),
    );
  }

  @override
  Future<PlaybackState?> stateOf(int episodeId) async {
    final position = positionsById[episodeId];
    if (position == null) return null;
    return PlaybackState(
      episodeId: episodeId,
      position: position,
      playbackRate: 1.0,
      isPlaying: false,
      playCount: 0,
      updatedAt: DateTime(2026, 8, 20),
    );
  }

  @override
  Future<List<PodcastEpisodeModel>> overlayPlaybackStates(
    List<PodcastEpisodeModel> episodes,
  ) async {
    return episodes;
  }

  @override
  Future<PodcastEpisodeListResponse> historyFull({int limit = 20}) async {
    return historyFullResponse ??
        const PodcastEpisodeListResponse(
          episodes: [],
          total: 0,
          page: 1,
          size: 0,
          pages: 1,
          subscriptionId: 0,
        );
  }

  @override
  Future<PlaybackHistoryLiteResponse> historyLite({int limit = 100}) async {
    return historyLiteResponse ??
        PlaybackHistoryLiteResponse(
          episodes: const [],
          total: 0,
          page: 1,
          size: 0,
          pages: 1,
        );
  }

  @override
  Future<ProfileStatsModel> profileStats() async {
    return profileStatsResponse ??
        const ProfileStatsModel(
          totalSubscriptions: 0,
          totalEpisodes: 0,
          summariesGenerated: 0,
          pendingSummaries: 0,
          playedEpisodes: 0,
        );
  }

  @override
  Future<PlaybackRateEffectiveResponse?> effectiveRate({
    int? subscriptionId,
  }) async {
    effectiveRateRequests.add(subscriptionId);
    final error = effectiveRateError;
    if (error != null) throw error;
    return effectiveRateResponse;
  }

  @override
  Future<PlaybackRateEffectiveResponse> applyRate({
    required double rate,
    required bool applyToSubscription,
    int? subscriptionId,
  }) async {
    appliedRates.add(
      (
        rate: rate,
        applyToSubscription: applyToSubscription,
        subscriptionId: subscriptionId,
      ),
    );
    return applyRateResponse ??
        PlaybackRateEffectiveResponse(
          globalPlaybackRate: rate,
          subscriptionPlaybackRate:
              applyToSubscription ? rate : null,
          effectivePlaybackRate: rate,
          source: applyToSubscription ? 'subscription' : 'global',
        );
  }
}

/// Opens a throwaway in-memory database (for constructing store subclasses
/// whose base constructor demands an [AppDatabase]).
AppDatabase throwawayMemoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}
