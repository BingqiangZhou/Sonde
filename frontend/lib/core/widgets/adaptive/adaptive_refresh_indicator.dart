import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/platform/platform_helper.dart';

/// Adaptive refresh indicator.
///
/// iOS: uses [CupertinoSliverRefreshControl] via the [AdaptiveRefreshIndicator.sliver]
/// constructor, or falls back to Material [RefreshIndicator] for the default constructor.
/// Android/desktop: Material [RefreshIndicator].
///
/// For pages that already use a [CustomScrollView], use [AdaptiveRefreshIndicator.sliver]
/// which provides a [CupertinoSliverRefreshControl] for inclusion in the sliver list.
class AdaptiveRefreshIndicator extends StatelessWidget {
  /// Wraps [child] with a Material [RefreshIndicator].
  ///
  /// For native iOS pull-to-refresh, use the [AdaptiveRefreshIndicator.sliver]
  /// constructor instead.
  const AdaptiveRefreshIndicator({
    required this.onRefresh,
    required this.child,
    super.key,
  }) : builder = null;

  /// Provides a sliver-based builder for iOS pages that already use
  /// a [CustomScrollView].
  ///
  /// When [builder] is provided, on iOS the builder receives a
  /// [CupertinoSliverRefreshControl] widget that should be inserted as the
  /// first sliver in the scroll view. On other platforms the builder receives
  /// null and the [child] is wrapped with a Material [RefreshIndicator].
  const AdaptiveRefreshIndicator.sliver({
    required this.onRefresh,
    required this.child,
    required this.builder,
    super.key,
  });

  /// Callback invoked when the user triggers a refresh.
  final Future<void> Function() onRefresh;

  /// The content to wrap.
  final Widget child;

  /// Optional builder for the sliver approach.
  ///
  /// On iOS, receives a [CupertinoSliverRefreshControl] widget to insert as
  /// the first sliver. On other platforms, receives null.
  final Widget Function(BuildContext context, Widget? refreshSliver)? builder;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      if (builder != null) {
        return builder!(
          context,
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        );
      }
      // Default: use Material RefreshIndicator on iOS too.
      // Nested CustomScrollView causes viewport layout issues.
      return RefreshIndicator(onRefresh: onRefresh, child: child);
    }

    if (builder != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: builder!(context, null),
      );
    }

    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}
