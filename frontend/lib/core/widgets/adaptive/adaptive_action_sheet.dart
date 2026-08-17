import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// An action for [showAdaptiveActionSheet].
class AdaptiveActionSheetAction {
  const AdaptiveActionSheetAction({
    required this.child,
    this.onPressed,
    this.isDestructive = false,
    this.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final Key? key;
}

/// Shows a platform-adaptive action sheet.
///
/// iOS: [CupertinoActionSheet] presented via [showCupertinoModalPopup].
/// Android: [showModalBottomSheet] with a list of action tiles.
Future<void> showAdaptiveActionSheet({
  required BuildContext context,
  required List<AdaptiveActionSheetAction> actions,
  Widget? title,
  Widget? message,
  Widget? cancelWidget,
}) {
  if (PlatformHelper.isApple(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: title,
        message: message,
        actions: actions.map((action) {
          return CupertinoActionSheetAction(
            key: action.key,
            onPressed: () {
              Navigator.of(popupContext).pop();
              action.onPressed?.call();
            },
            isDestructiveAction: action.isDestructive,
            child: action.child,
          );
        }).toList(),
        cancelButton: cancelWidget != null
            ? CupertinoActionSheetAction(
                onPressed: () => Navigator.of(popupContext).pop(),
                child: cancelWidget,
              )
            : null,
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      // Material 直接承载填充与圆角，避免 DecoratedBox 挡住 ListTile 的
      // 背景与水波纹（Flutter 3.47 断言要求）。
      return Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null || message != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, context.spacing.sm),
                  child: Column(
                    children: [
                      if (title != null)
                        DefaultTextStyle(
                          style: theme.textTheme.titleMedium!,
                          child: title,
                        ),
                      if (message != null)
                        Padding(
                          padding: EdgeInsets.only(top: context.spacing.xs),
                          child: DefaultTextStyle(
                            style: theme.textTheme.bodyMedium!,
                            child: message,
                          ),
                        ),
                    ],
                  ),
                ),
              ...actions.map((action) {
                return ListTile(
                  key: action.key,
                  title: DefaultTextStyle(
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: action.isDestructive
                          ? theme.colorScheme.error
                          : null,
                    ),
                    child: action.child,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onPressed?.call();
                  },
                );
              }),
              if (cancelWidget != null)
                ListTile(
                  title: DefaultTextStyle(
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    child: cancelWidget,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
            ],
          ),
          ),
        ),
      );
    },
  );
}
