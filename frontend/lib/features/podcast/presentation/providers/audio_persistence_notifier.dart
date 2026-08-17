// riverpod 3.4 将 state/ref 标记为 @protected；本文件用 extension 组织 Notifier 功能，
// 访问不属于"子类实例成员"，两条告警均为误报。
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'podcast_playback_providers.dart';

/// Local snapshot persistence extension for AudioPlayerNotifier.
///
/// Handles saving and restoring playback state to/from local storage
/// so the user can resume where they left off after app restart.
extension AudioPersistenceNotifier on AudioPlayerNotifier {
  String? _lastPlaybackSnapshotStorageKey() {
    final userId = _currentUserId();
    if (userId == null) {
      return null;
    }
    return playbackSnapshotStorageKeyForUser(userId);
  }

  void _schedulePersistLastPlaybackSnapshot({bool immediate = false}) {
    if (_isDisposed || !ref.mounted) return;
    if (state.currentEpisode == null) return;

    if (immediate) {
      _timers.cancel(AudioPlayerNotifier._kSnapshotPersist);
      unawaited(_persistLastPlaybackSnapshot());
      return;
    }

    if (_timers.isActive(AudioPlayerNotifier._kSnapshotPersist)) return;
    _timers.create(AudioPlayerNotifier._kSnapshotPersist, AudioPlayerNotifier._lastPlaybackSnapshotDebounce, () {
      unawaited(_persistLastPlaybackSnapshot());
    });
  }

  Future<void> _persistLastPlaybackSnapshot() async {
    if (_isDisposed || !ref.mounted) return;
    final episode = state.currentEpisode;
    if (episode == null) return;
    final snapshotKey = _lastPlaybackSnapshotStorageKey();
    if (snapshotKey == null) return;

    final payload = <String, dynamic>{
      'episode': <String, dynamic>{
        'id': episode.id,
        'subscription_id': episode.subscriptionId,
        'subscription_image_url': episode.subscriptionImageUrl,
        'title': episode.title,
        'subscription_title': episode.subscriptionTitle,
        'description': null,
        'audio_url': episode.audioUrl,
        'audio_duration': episode.audioDuration,
        'audio_file_size': episode.audioFileSize,
        'published_at': episode.publishedAt.toIso8601String(),
        'image_url': episode.imageUrl,
        'item_link': episode.itemLink,
        'transcript_url': null,
        'transcript_content': null,
        'ai_summary': null,
        'summary_version': null,
        'ai_confidence_score': null,
        'play_count': episode.playCount,
        'last_played_at': episode.lastPlayedAt?.toIso8601String(),
        'season': episode.season,
        'episode_number': episode.episodeNumber,
        'explicit': episode.explicit,
        'status': episode.status,
        'metadata': episode.metadata,
        'playback_position': (state.position / 1000).round(),
        'is_playing': false,
        'playback_rate': state.playbackRate,
        'is_played': episode.isPlayed,
        'created_at': episode.createdAt.toIso8601String(),
        'updated_at': episode.updatedAt?.toIso8601String(),
      },
      'position_ms': state.position,
      'duration_ms': state.duration,
      'playback_rate': state.playbackRate,
      'saved_at': DateTime.now().toIso8601String(),
    };

    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.saveString(snapshotKey, jsonEncode(payload));
    } catch (e) {
      logger.AppLogger.debug('[Playback] Failed to persist playback snapshot: $e');
    }
  }

  Future<_LastPlaybackSnapshot?> _loadLastPlaybackSnapshot() async {
    try {
      final snapshotKey = _lastPlaybackSnapshotStorageKey();
      if (snapshotKey == null) return null;
      final storage = ref.read(localStorageServiceProvider);
      final raw = await storage.getString(snapshotKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final episodeJson = decoded['episode'];
      if (episodeJson is! Map) return null;
      final episode = PodcastEpisodeModel.fromJson(
        Map<String, dynamic>.from(episodeJson),
      );
      final positionMs = (decoded['position_ms'] as num?)?.toInt() ?? 0;
      final durationMs =
          (decoded['duration_ms'] as num?)?.toInt() ??
          (episode.audioDuration ?? 0) * 1000;
      final playbackRate =
          (decoded['playback_rate'] as num?)?.toDouble() ??
          episode.playbackRate;
      final savedAtRaw = decoded['saved_at'];
      final savedAt = savedAtRaw is String
          ? DateTime.tryParse(savedAtRaw)
          : null;
      return _LastPlaybackSnapshot(
        episode: episode,
        positionMs: positionMs,
        durationMs: durationMs,
        playbackRate: playbackRate,
        savedAt: savedAt,
      );
    } catch (e) {
      logger.AppLogger.debug('[Playback] Failed to load playback snapshot: $e');
      return null;
    }
  }

  Future<bool> _restoreLastPlaybackSnapshotIfPossible() async {
    if (_isDisposed || !ref.mounted) return false;
    if (!ref.read(authProvider).isAuthenticated) return false;
    if (_isPlayingEpisode || state.currentEpisode != null) return false;

    final snapshot = await _loadLastPlaybackSnapshot();
    if (_isDisposed || !ref.mounted) return false;
    if (snapshot == null) return false;
    if (_isPlayingEpisode || state.currentEpisode != null) return false;

    final resolvedPlaybackRate = await _resolveEffectivePlaybackRate(
      subscriptionId: snapshot.episode.subscriptionId,
      fallbackRate: snapshot.playbackRate,
    );

    state = state.copyWith(
      currentEpisode: snapshot.episode.copyWith(
        playbackRate: resolvedPlaybackRate,
        playbackPosition: (snapshot.positionMs / 1000).round(),
      ),
      isPlaying: false,
      isLoading: false,
      position: snapshot.positionMs,
      duration: snapshot.durationMs,
      playbackRate: resolvedPlaybackRate,
      clearError: true,
    );
    return true;
  }
}
