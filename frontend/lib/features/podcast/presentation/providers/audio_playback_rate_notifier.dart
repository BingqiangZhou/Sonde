// riverpod 3.4 将 state/ref 标记为 @protected；本文件用 extension 组织 Notifier 功能，
// 访问不属于"子类实例成员"，两条告警均为误报。
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'podcast_playback_providers.dart';

/// Playback rate management extension for AudioPlayerNotifier.
///
/// Handles setting, resolving, and caching playback speed preferences
/// for both global and per-subscription contexts.
extension AudioPlaybackRateNotifier on AudioPlayerNotifier {
  Future<void> setPlaybackRate(
    double rate, {
    bool applyToSubscription = false,
  }) async {
    if (_isDisposed) return;

    try {
      final currentEpisode = state.currentEpisode;
      if (applyToSubscription && currentEpisode == null) {
        throw StateError(
          'A current episode is required when applying to subscription',
        );
      }

      await setAudioSpeed(rate);
      final applied = await _localPlayback.applyRate(
        rate: rate,
        applyToSubscription: applyToSubscription,
        subscriptionId: currentEpisode?.subscriptionId,
      );

      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          playbackRate: applied.effectivePlaybackRate,
          currentEpisode: currentEpisode?.copyWith(
            playbackRate: applied.effectivePlaybackRate,
          ),
        );
        _cachePlaybackRateSelection(
          speed: applied.effectivePlaybackRate,
          applyToSubscription:
              currentEpisode != null && applied.source == 'subscription',
          subscriptionId: currentEpisode?.subscriptionId,
        );
        if (currentEpisode != null &&
            shouldSyncPlaybackToServer(currentEpisode)) {
          await _syncImmediatePlaybackSnapshot(
            episode: currentEpisode.copyWith(
              playbackRate: applied.effectivePlaybackRate,
            ),
            positionMs: state.position,
            isPlaying: state.isPlaying,
          );
        }
      }
    } catch (error) {
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(error: mapErrorMessage(error));
      }
    }
  }

  Future<PlaybackRateEffectiveResponse?> _fetchEffectivePlaybackRatePreference({
    int? subscriptionId,
  }) async {
    try {
      return await _localPlayback.effectiveRate(
        subscriptionId: subscriptionId,
      );
    } catch (error) {
      logger.AppLogger.debug(
        'Failed to resolve effective playback rate, using fallback value: $error',
      );
      return null;
    }
  }

  Future<double> _resolveEffectivePlaybackRate({
    required double fallbackRate, int? subscriptionId,
  }) async {
    final effective = await _fetchEffectivePlaybackRatePreference(
      subscriptionId: subscriptionId,
    );
    final fallbackSelection = _fallbackPlaybackRateSelection(
      subscriptionId: subscriptionId,
      fallbackRate: fallbackRate,
    );
    final resolvedPlaybackRate =
        effective?.effectivePlaybackRate ?? fallbackRate;
    _cachePlaybackRateSelection(
      speed: resolvedPlaybackRate,
      applyToSubscription: subscriptionId != null && (effective?.source == 'subscription' ||
                (effective == null && fallbackSelection.applyToSubscription)),
      subscriptionId: subscriptionId,
    );
    return resolvedPlaybackRate;
  }

  PlaybackRateSelectionSnapshot _fallbackPlaybackRateSelection({
    required int? subscriptionId,
    required double fallbackRate,
  }) {
    final cachedSelection = _playbackRateSelectionCache;
    if (cachedSelection == null) {
      return (speed: fallbackRate, applyToSubscription: false);
    }
    if (!cachedSelection.applyToSubscription) {
      return (speed: fallbackRate, applyToSubscription: false);
    }
    if (subscriptionId != null &&
        cachedSelection.subscriptionId == subscriptionId) {
      return (speed: fallbackRate, applyToSubscription: true);
    }
    return (speed: fallbackRate, applyToSubscription: false);
  }

  void _cachePlaybackRateSelection({
    required double speed,
    required bool applyToSubscription,
    int? subscriptionId,
  }) {
    _playbackRateSelectionCache = _PlaybackRateSelectionCache(
      speed: speed,
      applyToSubscription: applyToSubscription && subscriptionId != null,
      subscriptionId: applyToSubscription ? subscriptionId : null,
    );
  }
}

class _PlaybackRateSelectionCache {
  const _PlaybackRateSelectionCache({
    required this.speed,
    required this.applyToSubscription,
    required this.subscriptionId,
  });

  final double speed;
  final bool applyToSubscription;
  final int? subscriptionId;
}
