import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive tap-feedback widget.
///
/// iOS/macOS: [GestureDetector] with no splash — native Apple apps use
/// subtle dim/highlight rather than ink ripples.
/// Android: Material [InkWell] with the standard ripple effect.
///
/// Callers must provide a [Material] ancestor for the ink splash to render
/// on Android. A `Material(color: Colors.transparent)` wrapper is typical.
class AdaptiveInkWell extends StatelessWidget {
  const AdaptiveInkWell({
    required this.child,
    super.key,
    this.onTap,
    this.borderRadius,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.splashColor,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool enableFeedback;
  final bool excludeFromSemantics;

  /// Color for the Material ink splash. Ignored on Cupertino.
  final Color? splashColor;

  /// Color for the Material highlight. Ignored on Cupertino.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return GestureDetector(
        onTap: onTap,
        excludeFromSemantics: excludeFromSemantics,
        child: child,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      enableFeedback: enableFeedback,
      excludeFromSemantics: excludeFromSemantics,
      splashColor: splashColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}
