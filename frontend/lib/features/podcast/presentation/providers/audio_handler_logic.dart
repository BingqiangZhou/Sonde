import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;

// Pure decision logic extracted from PodcastAudioHandler so it can be
// unit tested without an audio player, platform channels, or the handler
// singleton. Keep this file free of any state or I/O.

/// Validates and sanitizes artUri for Vivo/OriginOS lock screen
/// compatibility: only http/https URLs are returned, anything else
/// (asset://, file://, content://, malformed input) becomes null.
Uri? validateArtUri(String? urlString) {
  if (urlString == null || urlString.isEmpty) return null;

  final uri = Uri.tryParse(urlString);
  if (uri == null) return null;

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    if (kDebugMode) {
      logger.AppLogger.debug(
        '⚠️ [ART_URI] Invalid scheme: ${uri.scheme} (only http/https allowed)',
      );
    }
    return null;
  }

  return uri;
}

/// Maps audioplayers' PlayerState to audio_service's
/// AudioProcessingState for notification and playbackState broadcasts.
AudioProcessingState mapPlayerProcessingState(PlayerState state) {
  switch (state) {
    case PlayerState.stopped:
      return AudioProcessingState.idle;
    case PlayerState.disposed:
      return AudioProcessingState.idle;
    case PlayerState.playing:
    case PlayerState.paused:
      return AudioProcessingState.ready;
    case PlayerState.completed:
      return AudioProcessingState.completed;
  }
}

/// Notification controls for the current state: full transport row when
/// content is loaded, a lone play button otherwise.
List<MediaControl> buildMediaControls({
  required bool playing,
  required bool hasContent,
}) {
  return hasContent
      ? [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ]
      : [MediaControl.play];
}

/// Android compact-view indices matching [buildMediaControls].
List<int> buildAndroidCompactActionIndices({required bool hasContent}) {
  return hasContent ? const [0, 1, 2] : const [0];
}

/// Applies [delta] to [position] clamped to [0, duration]. A null
/// duration clamps to zero, mirroring the original fast-forward behavior
/// when duration is still unknown.
Duration clampSeek({
  required Duration position,
  required Duration delta,
  Duration? duration,
}) {
  final target = position + delta;
  final upper = duration ?? Duration.zero;
  if (target < Duration.zero) return Duration.zero;
  if (target > upper) return upper;
  return target;
}

/// Position-tick throttle: emit when 500ms elapsed OR the position jumped
/// by at least 1s (e.g. an explicit seek), skip otherwise.
bool shouldEmitPositionTick({
  required DateTime now,
  required DateTime lastEmitAt,
  required Duration lastEmittedPosition,
  required Duration position,
}) {
  final elapsedMs = now.difference(lastEmitAt).inMilliseconds;
  final deltaMs = (position - lastEmittedPosition).abs().inMilliseconds;
  return elapsedMs >= 500 || deltaMs >= 1000;
}
