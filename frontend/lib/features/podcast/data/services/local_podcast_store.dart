import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/database/database_provider.dart';
import 'package:sonde/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_playback_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_queue_model.dart';
import 'package:sonde/features/podcast/data/models/profile_stats_model.dart';

/// On-device playback + queue source of truth (server-pipeline phase 2c).
///
/// Playback/queue/history/stats live exclusively in Drift; the backend
/// counterparts are retired in phase 3. Episodes metadata comes from the
/// server-hydrated [EpisodesCache].
class LocalPlaybackStore {
  LocalPlaybackStore(this._db);

  final AppDatabase _db;

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Persist a playback snapshot. Mirrors the server semantics: play_count
  /// increments only on the not-playing → playing transition.
  Future<void> saveProgress({
    required int episodeId,
    required int positionSec,
    required bool isPlaying,
    double? playbackRate,
  }) async {
    final existing = await _db.playbackDao.getByEpisodeId(episodeId);
    final playCount = (existing?.playCount ?? 0) +
        ((isPlaying && !(existing?.isPlaying ?? false)) ? 1 : 0);
    await _db.playbackDao.upsertState(
      PlaybackStatesCompanion(
        episodeId: Value(episodeId),
        position: Value(positionSec),
        isPlaying: Value(isPlaying),
        playbackRate: Value(playbackRate ?? existing?.playbackRate ?? 1.0),
        playCount: Value(playCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Episodes with local playback state, most recently touched first
  /// (one row per episode — the local playback history).
  Future<List<PodcastEpisodeModel>> recentEpisodes({int limit = 20}) async {
    final states = await _db.playbackDao.recent(limit: limit);
    return _joinCache(states);
  }

  /// The stored state of one episode, if any.
  Future<PlaybackState?> stateOf(int episodeId) =>
      _db.playbackDao.getByEpisodeId(episodeId);

  /// Batch overlay for server-fetched episode lists: replaces the stale
  /// server playback fields with the local truth.
  Future<List<PodcastEpisodeModel>> overlayPlaybackStates(
    List<PodcastEpisodeModel> episodes,
  ) async {
    final states = await _db.playbackDao
        .getByEpisodeIds(episodes.map((e) => e.id).toList());
    if (states.isEmpty) return episodes;
    return [
      for (final episode in episodes)
        states[episode.id] == null
            ? episode
            : _applyState(episode, states[episode.id]!),
    ];
  }

  // ── Playback rate preference (per subscription, global fallback) ─────────

  static const String _ratePrefix = 'playback_rate:';
  static const String _globalRateKey = 'playback_rate:global';

  Future<double?> rateForSubscription(int subscriptionId) async {
    final raw = await _db.settingsDao.get('$_ratePrefix$subscriptionId');
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> setRateForSubscription(int subscriptionId, double rate) {
    return _db.settingsDao.set('$_ratePrefix$subscriptionId', '$rate');
  }

  Future<double?> globalRate() async {
    final raw = await _db.settingsDao.get(_globalRateKey);
    return raw == null ? null : double.tryParse(raw);
  }

  /// Subscription rate wins over the global fallback; null when neither
  /// has ever been set.
  Future<PlaybackRateEffectiveResponse?> effectiveRate({
    int? subscriptionId,
  }) async {
    final subscription = subscriptionId == null
        ? null
        : await rateForSubscription(subscriptionId);
    if (subscription != null) {
      return _rateResponse(subscription, global: await globalRate());
    }
    final global = await globalRate();
    if (global != null) return _rateResponse(global, global: global);
    return null;
  }

  Future<PlaybackRateEffectiveResponse> applyRate({
    required double rate,
    required bool applyToSubscription,
    int? subscriptionId,
  }) async {
    if (applyToSubscription && subscriptionId != null) {
      await setRateForSubscription(subscriptionId, rate);
    } else {
      await _db.settingsDao.set(_globalRateKey, '$rate');
    }
    return _rateResponse(
      rate,
      global: await globalRate(),
      subscription: applyToSubscription ? rate : null,
    );
  }

  PlaybackRateEffectiveResponse _rateResponse(
    double effective, {
    required double? global,
    double? subscription,
  }) {
    final source = subscription != null ? 'subscription' : 'global';
    return PlaybackRateEffectiveResponse(
      globalPlaybackRate: global ?? 1.0,
      subscriptionPlaybackRate: subscription,
      effectivePlaybackRate: effective,
      source: source,
    );
  }

  // ── History (lite shape for the profile history page) ────────────────────

  /// Local playback history in the full list-response shape (player
  /// bootstrap / restore path).
  Future<PodcastEpisodeListResponse> historyFull({int limit = 20}) async {
    final episodes = await recentEpisodes(limit: limit);
    return PodcastEpisodeListResponse(
      episodes: episodes,
      total: episodes.length,
      page: 1,
      size: episodes.length,
      pages: 1,
      subscriptionId: 0,
    );
  }

  /// Local playback history in the lite response shape.
  Future<PlaybackHistoryLiteResponse> historyLite({int limit = 100}) async {
    final items = await recentEpisodes(limit: limit);
    return PlaybackHistoryLiteResponse(
      episodes: [
        for (final episode in items)
          PlaybackHistoryLiteItem(
            id: episode.id,
            subscriptionId: episode.subscriptionId,
            subscriptionTitle: episode.subscriptionTitle,
            subscriptionImageUrl: episode.subscriptionImageUrl,
            title: episode.title,
            imageUrl: episode.imageUrl,
            audioDuration: episode.audioDuration,
            playbackPosition: episode.playbackPosition,
            lastPlayedAt: episode.lastPlayedAt,
            publishedAt: episode.publishedAt,
          ),
      ],
      total: items.length,
      page: 1,
      size: items.length,
      pages: 1,
    );
  }

  // ── Profile stats (computed over the local cache + playback states) ──────

  Future<ProfileStatsModel> profileStats() async {
    final cache = _db.episodeCacheDao.episodesCache;
    final totalExpr = cache.id.count();
    final summariesExpr = cache.aiSummary.count(
      filter: cache.aiSummary.isNotNull(),
    );
    final subsExpr = cache.subscriptionId.count(distinct: true);
    final row = await (_db.selectOnly(cache)
          ..addColumns([totalExpr, summariesExpr, subsExpr]))
        .getSingle();

    final total = row.read(totalExpr) ?? 0;
    final summaries = row.read(summariesExpr) ?? 0;
    return ProfileStatsModel(
      totalSubscriptions: row.read(subsExpr) ?? 0,
      totalEpisodes: total,
      summariesGenerated: summaries,
      pendingSummaries: total - summaries,
      playedEpisodes: await _countPlayedEpisodes(),
    );
  }

  Future<int> _countPlayedEpisodes() async {
    final playback = _db.playbackStates;
    final cache = _db.episodeCacheDao.episodesCache;
    final playedExpr = playback.episodeId.count();
    final query = _db.selectOnly(playback)
      ..addColumns([playedExpr])
      ..join([innerJoin(cache, cache.id.equalsExp(playback.episodeId))])
      // Server semantics: played at >= 90% duration; rows with a null
      // duration never qualify (comparison yields null). Integer math
      // (pos * 10 >= dur * 9) avoids float column typing.
      ..where((playback.position * const Constant(10)).isBiggerOrEqual(
        cache.audioDuration * const Constant(9),
      ));
    final row = await query.getSingle();
    return row.read(playedExpr) ?? 0;
  }

  // ── Cache joins ──────────────────────────────────────────────────────────

  Future<List<PodcastEpisodeModel>> _joinCache(
    List<PlaybackState> states,
  ) async {
    final models = <PodcastEpisodeModel>[];
    for (final state in states) {
      final row = await _db.episodeCacheDao.getById(state.episodeId);
      if (row == null) continue; // not yet synced — skip, not fatal
      models.add(_fromCacheRow(row, state));
    }
    return models;
  }

  PodcastEpisodeModel _applyState(
    PodcastEpisodeModel episode,
    PlaybackState state,
  ) {
    final duration = episode.audioDuration;
    return episode.copyWith(
      playbackPosition: state.position,
      isPlaying: state.isPlaying,
      playbackRate: state.playbackRate,
      playCount: state.playCount,
      lastPlayedAt: state.updatedAt,
      isPlayed: duration != null &&
          duration > 0 &&
          state.position >= duration * 0.9,
    );
  }

  PodcastEpisodeModel _fromCacheRow(
    EpisodesCacheData row,
    PlaybackState state,
  ) {
    return PodcastEpisodeModel(
      id: row.id,
      subscriptionId: row.subscriptionId,
      title: row.title,
      audioUrl: row.audioUrl,
      publishedAt: row.publishedAt,
      createdAt: row.updatedAt,
      subscriptionTitle: row.subscriptionTitle,
      subscriptionImageUrl: row.subscriptionImageUrl,
      description: row.description,
      audioDuration: row.audioDuration,
      imageUrl: row.imageUrl,
      aiSummary: row.aiSummary,
      playbackPosition: state.position,
      isPlaying: state.isPlaying,
      playbackRate: state.playbackRate,
      playCount: state.playCount,
      lastPlayedAt: state.updatedAt,
      isPlayed: row.audioDuration != null &&
          row.audioDuration! > 0 &&
          state.position >= row.audioDuration! * 0.9,
    );
  }
}

/// On-device play queue backed by [QueueDao] + the episodes cache; the
/// "current" pointer and revision live in the settings table.
class LocalQueueStore {
  LocalQueueStore(this._db);

  final AppDatabase _db;

  static const String _currentKey = 'queue_current_episode';
  static const String _revisionKey = 'queue_revision';

  Future<PodcastQueueModel> getQueue() => _build();

  Future<PodcastQueueModel> addQueueItem(int episodeId) async {
    await _db.queueDao.append(episodeId);
    return _build();
  }

  Future<PodcastQueueModel> removeQueueItem(int episodeId) async {
    await _db.queueDao.remove(episodeId);
    final current = await _currentId();
    if (current == episodeId) {
      await _setCurrentId(await _firstEpisodeId());
    }
    return _build();
  }

  Future<PodcastQueueModel> reorderQueueItems(List<int> episodeIds) async {
    await _db.queueDao.reorder(episodeIds);
    return _build();
  }

  Future<PodcastQueueModel> setQueueCurrent(int episodeId) async {
    await _setCurrentId(episodeId);
    return _build();
  }

  /// Activate = ensure membership, then make current.
  Future<PodcastQueueModel> activateQueueEpisode(int episodeId) async {
    if (!await _db.queueDao.contains(episodeId)) {
      await _db.queueDao.append(episodeId);
    }
    await _setCurrentId(episodeId);
    return _build();
  }

  /// Complete the current episode: drop it and advance to the head.
  Future<PodcastQueueModel> completeQueueCurrent() async {
    final current = await _currentId();
    if (current != null) {
      await _db.queueDao.remove(current);
    }
    await _setCurrentId(await _firstEpisodeId());
    return _build();
  }

  Future<PodcastQueueModel> clearQueue() async {
    await _db.queueDao.clear();
    await _setCurrentId(null);
    return _build();
  }

  // ── Internals ────────────────────────────────────────────────────────────

  Future<int?> _currentId() async {
    final raw = await _db.settingsDao.get(_currentKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> _setCurrentId(int? episodeId) {
    return _db.settingsDao.set(
      _currentKey,
      episodeId?.toString() ?? '',
    );
  }

  Future<int?> _firstEpisodeId() async {
    final queue = await _db.queueDao.ordered();
    return queue.isEmpty ? null : queue.first.episodeId;
  }

  Future<PodcastQueueModel> _build() async {
    final entries = await _db.queueDao.ordered();
    final states = await _db.playbackDao
        .getByEpisodeIds(entries.map((e) => e.episodeId).toList());

    final items = <PodcastQueueItemModel>[];
    for (final entry in entries) {
      final row = await _db.episodeCacheDao.getById(entry.episodeId);
      if (row == null) continue;
      items.add(
        PodcastQueueItemModel(
          episodeId: row.id,
          position: entry.position,
          title: row.title,
          podcastId: row.subscriptionId,
          audioUrl: row.audioUrl,
          playbackPosition: states[row.id]?.position,
          duration: row.audioDuration,
          publishedAt: row.publishedAt,
          imageUrl: row.imageUrl,
          subscriptionTitle: row.subscriptionTitle,
          subscriptionImageUrl: row.subscriptionImageUrl,
        ),
      );
    }

    final rawRevision = await _db.settingsDao.get(_revisionKey);
    final revision = (int.tryParse(rawRevision ?? '') ?? 0) + 1;
    await _db.settingsDao.set(_revisionKey, '$revision');

    return PodcastQueueModel(
      currentEpisodeId: await _currentId(),
      revision: revision,
      updatedAt: DateTime.now(),
      items: items,
    );
  }
}

final localPlaybackStoreProvider = Provider<LocalPlaybackStore>((ref) {
  return LocalPlaybackStore(ref.read(appDatabaseProvider));
});

final localQueueStoreProvider = Provider<LocalQueueStore>((ref) {
  return LocalQueueStore(ref.read(appDatabaseProvider));
});
