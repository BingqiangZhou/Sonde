import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonde/core/platform/platform_helper.dart';

/// Provides app-level keyboard shortcuts on desktop platforms.
///
/// Wrap the main content area with this widget to enable:
/// - Ctrl/Cmd + 1/2/3: Switch between the first three tabs
///
/// Only active when [enabled] is true (typically when a text field is NOT focused).
/// Shortcuts are not registered on mobile platforms — they have no physical keyboard.
class AppKeyboardShortcuts extends StatelessWidget {
  const AppKeyboardShortcuts({
    required this.child,
    required this.onTabSwitch,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final void Function(int index) onTabSwitch;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Skip registering shortcuts on mobile platforms — they have no physical keyboard.
    if (!PlatformHelper.isDesktop(context)) return child;
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
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
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TabSwitch0Intent: _CallbackAction(() => onTabSwitch(0)),
          _TabSwitch1Intent: _CallbackAction(() => onTabSwitch(1)),
          _TabSwitch2Intent: _CallbackAction(() => onTabSwitch(2)),
        },
        child: child,
      ),
    );
  }
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
