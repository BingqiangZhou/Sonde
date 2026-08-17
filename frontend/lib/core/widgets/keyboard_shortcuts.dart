import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Provides keyboard shortcuts for media playback on desktop platforms.
///
/// Wrap the main content area with this widget to enable:
/// - Space: Toggle play/pause
/// - Left arrow: Seek back 10 seconds
/// - Right arrow: Seek forward 30 seconds
/// - J / K: Seek back / forward 10 seconds
/// - Up arrow: Volume up
/// - Down arrow: Volume down
/// - N / MediaTrackNext: Next episode
/// - P / MediaTrackPrevious: Previous episode
///
/// Only active when [enabled] is true (typically when a text field is NOT focused).
class PlaybackShortcuts extends StatelessWidget {
  const PlaybackShortcuts({
    required this.child, required this.onTogglePlayPause, required this.onSeekBackward, required this.onSeekForward, super.key,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.onTabSwitch,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final void Function(int index)? onTabSwitch;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Skip registering shortcuts on mobile platforms — they have no physical keyboard.
    if (!PlatformHelper.isDesktop(context)) return child;
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.space):
            const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ):
            const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK):
            const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _VolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _VolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyN): const _NextEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyP): const _PreviousEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackNext):
            const _NextEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious):
            const _PreviousEpisodeIntent(),
        // Tab switching shortcuts: Ctrl/Cmd + 1/2/3
        if (onTabSwitch != null) ...{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
              const _TabSwitch0Intent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2):
              const _TabSwitch1Intent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3):
              const _TabSwitch2Intent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1):
              const _TabSwitch0Intent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2):
              const _TabSwitch1Intent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3):
              const _TabSwitch2Intent(),
        },
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayPauseIntent: _CallbackAction(onTogglePlayPause),
          _SeekBackwardIntent: _CallbackAction(onSeekBackward),
          _SeekForwardIntent: _CallbackAction(onSeekForward),
          if (onVolumeUp != null)
            _VolumeUpIntent: _CallbackAction(onVolumeUp!),
          if (onVolumeDown != null)
            _VolumeDownIntent: _CallbackAction(onVolumeDown!),
          if (onNextEpisode != null)
            _NextEpisodeIntent: _CallbackAction(onNextEpisode!),
          if (onPreviousEpisode != null)
            _PreviousEpisodeIntent: _CallbackAction(onPreviousEpisode!),
          if (onTabSwitch != null) ...{
            _TabSwitch0Intent: _CallbackAction(() => onTabSwitch!(0)),
            _TabSwitch1Intent: _CallbackAction(() => onTabSwitch!(1)),
            _TabSwitch2Intent: _CallbackAction(() => onTabSwitch!(2)),
          },
        },
        child: child,
      ),
    );
  }
}

class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _VolumeUpIntent extends Intent {
  const _VolumeUpIntent();
}

class _VolumeDownIntent extends Intent {
  const _VolumeDownIntent();
}

class _NextEpisodeIntent extends Intent {
  const _NextEpisodeIntent();
}

class _PreviousEpisodeIntent extends Intent {
  const _PreviousEpisodeIntent();
}

class _TabSwitch0Intent extends Intent {
  const _TabSwitch0Intent();
}

class _TabSwitch1Intent extends Intent {
  const _TabSwitch1Intent();
}

class _TabSwitch2Intent extends Intent {
  const _TabSwitch2Intent();
}

class _CallbackAction extends Action<Intent> {
  _CallbackAction(this.callback);

  final VoidCallback callback;

  @override
  Object? invoke(Intent intent) {
    callback();
    return null;
  }
}
