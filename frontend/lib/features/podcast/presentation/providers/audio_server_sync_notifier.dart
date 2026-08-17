// riverpod 3.4 将 state/ref 标记为 @protected；本文件用 extension 组织 Notifier 功能，
// 访问不属于"子类实例成员"，两条告警均为误报。
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'podcast_playback_providers.dart';

/// Server-side playback state sync extension for AudioPlayerNotifier.
///
/// Handles throttled and immediate sync of playback state to the backend.
extension AudioServerSyncNotifier on AudioPlayerNotifier {
  Future<void> _updatePlaybackStateOnServer({bool immediate = false}) async {
    if (_isDisposed) return;

    final episode = state.currentEpisode;
    if (episode == null) return;
    if (!shouldSyncPlaybackToServer(episode)) return;

    // If immediate (pause/seek/stop/completed), send right away
    if (immediate) {
      await _syncImmediatePlaybackSnapshot(
        episode: episode,
        positionMs: state.position,
        isPlaying: state.isPlaying,
      );
      return;
    }

    await _scheduleThrottledSync(episode);
  }

  Future<void> _syncImmediatePlaybackSnapshot({
    required PodcastEpisodeModel episode,
    required int positionMs,
    required bool isPlaying,
  }) {
    // An in-flight throttled sync must not swallow the pause/seek snapshot:
    // chain behind it so the latest state still reaches the server.
    final pending = _playbackSyncInFlight;
    final future = (pending ?? Future<void>.value()).then((_) async {
      if (_isDisposed) return;
      _timers.cancel(AudioPlayerNotifier._kSyncThrottleTimer);
      final success = await _sendPlaybackSnapshot(
        episode: episode,
        positionMs: positionMs,
        isPlaying: isPlaying,
      );
      if (success) {
        _lastPlaybackSyncAt = DateTime.now();
      }
    });
    return _adoptPlaybackSyncFuture(future);
  }

  Future<void> _scheduleThrottledSync(PodcastEpisodeModel episode) async {
    // Skip if already syncing
    if (_playbackSyncInFlight != null) return;

    final now = DateTime.now();
    final lastSync = _lastPlaybackSyncAt;

    if (lastSync == null ||
        now.difference(lastSync) >= AudioPlayerNotifier._syncInterval) {
      await _runThrottledSyncNow(episode);
      return;
    }

    if (_timers.isActive(AudioPlayerNotifier._kSyncThrottleTimer)) {
      return;
    }

    final remaining =
        AudioPlayerNotifier._syncInterval - now.difference(lastSync);
    _timers.create(AudioPlayerNotifier._kSyncThrottleTimer, remaining, () {
      final currentEpisode = state.currentEpisode;
      if (currentEpisode == null) return;
      unawaited(_runThrottledSyncNow(currentEpisode));
    });
  }

  Future<void> _runThrottledSyncNow(PodcastEpisodeModel episode) {
    if (_isDisposed || _playbackSyncInFlight != null) {
      return Future<void>.value();
    }
    final future = _sendPlaybackUpdate(episode).then((success) {
      if (success) {
        _lastPlaybackSyncAt = DateTime.now();
      }
    });
    return _adoptPlaybackSyncFuture(future);
  }

  /// Tracks [future] as the in-flight sync and clears the slot once it (and
  /// anything chained behind it) drains. [_sendPlaybackSnapshot] catches all
  /// errors, so the future never rejects.
  Future<void> _adoptPlaybackSyncFuture(Future<void> future) {
    _playbackSyncInFlight = future;
    future.whenComplete(() {
      if (identical(_playbackSyncInFlight, future)) {
        _playbackSyncInFlight = null;
      }
    });
    return future;
  }

  Future<bool> _sendPlaybackUpdate(PodcastEpisodeModel episode) async {
    return _sendPlaybackSnapshot(
      episode: episode,
      positionMs: state.position,
      isPlaying: state.isPlaying,
    );
  }

  Future<bool> _sendPlaybackSnapshot({
    required PodcastEpisodeModel episode,
    required int positionMs,
    required bool isPlaying,
  }) async {
    if (_isDisposed) return false;
    if (!shouldSyncPlaybackToServer(episode)) return false;

    final payload = buildPersistPayload(positionMs, state.duration, isPlaying);

    try {
      await _repository.updatePlaybackProgress(
        episodeId: episode.id,
        position: payload.positionSec,
        isPlaying: payload.isPlaying,
        playbackRate: state.playbackRate,
      );
      return true;
    } catch (error) {
      // Log more detailed error for debugging
      logger.AppLogger.debug(
        '[Error] Failed to update playback state on server: $error',
      );
      logger.AppLogger.debug('[Playback] Episode ID: ${episode.id}');
      logger.AppLogger.debug(
        '[Playback] Position: ${positionMs}ms (${(positionMs / 1000).round()}s)',
      );
      logger.AppLogger.debug('[Playback] Is Playing: $isPlaying');
      logger.AppLogger.debug('[Playback] Playback Rate: ${state.playbackRate}');

      // Check if it's an authentication error
      if (error.toString().contains('401') ||
          error.toString().contains('authentication')) {
        logger.AppLogger.debug(
          '[Error] Authentication error - user may need to log in again',
        );
      }

      // Don't update the UI state for server errors - continue playback
      return false;
    }
  }
}
