import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';

/// On desktop/tablet (width >= 600), shows a centred [Dialog] within the
/// current navigator's content area.  On mobile shows a standard
/// [showModalBottomSheet].
///
/// Returns the value produced by the builder (if any).
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
  double desktopMaxWidth = 560,
  double desktopMaxHeightFraction = 0.85,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<T?>.value();
  }

  final screenWidth = MediaQuery.of(resolvedContext).size.width;

  // iOS mobile: use Cupertino modal popup
  if (PlatformHelper.isApple(resolvedContext) && screenWidth < 600) {
    return showCupertinoModalPopup<T>(
      context: resolvedContext,
      builder: (sheetCtx) {
        // Material 直接承载填充与圆角，避免 DecoratedBox 挡住内部
        // ListTile 的背景与水波纹（Flutter 3.47 断言要求）。
        return Material(
          color: CupertinoColors.systemBackground.resolveFrom(sheetCtx),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.mdLg)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(child: builder(sheetCtx)),
        );
      },
    );
  }

  if (screenWidth >= 600) {
    // Desktop / tablet -> centred dialog.
    return showDialog<T>(
      context: resolvedContext,
      barrierColor: Colors.black54,
      builder: (dialogCtx) {
        final size = MediaQuery.of(dialogCtx).size;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktopMaxWidth,
              maxHeight: size.height * desktopMaxHeightFraction,
            ),
            child: Material(
              color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              clipBehavior: Clip.antiAlias,
              child: builder(dialogCtx),
            ),
          ),
        );
      },
    );
  }

  // Mobile -> bottom sheet.
  return showModalBottomSheet<T>(
    context: resolvedContext,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (sheetCtx) {
      return Material(
        color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: builder(sheetCtx),
      );
    },
  );
}
