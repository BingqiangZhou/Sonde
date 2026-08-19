import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/platform/platform_helper.dart';
import 'package:sonde/core/widgets/app_dialog.dart';

/// Show a modal dialog built on the [AppDialog] shell.
///
/// Example:
/// ```dart
/// showAppDialog(
///   context: context,
///   builder: (ctx) => AppDialog(
///     title: Text(l10n.some_title),
///     content: Text(l10n.some_message),
///   ),
/// );
/// ```
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  bool useRootNavigator = false,
}) {
  if (PlatformHelper.isApple(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) => Center(child: builder(dialogContext)),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: ResponsiveDialogHelper.insetPadding(),
      child: builder(dialogContext),
    ),
  );
}

/// Show a simple confirmation dialog built on the [AppDialog] shell.
///
/// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
///
/// Example:
/// ```dart
/// final confirmed = await showAppConfirmationDialog(
///   context: context,
///   title: 'Delete?',
///   message: 'This cannot be undone.',
///   isDestructive: true,
/// );
/// ```
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelText,
  String? confirmText,
  bool isDestructive = false,
}) {
  final l10n = context.l10n;
  final resolvedCancelText = cancelText ?? l10n.cancel;
  final resolvedConfirmText = confirmText ?? l10n.confirm;

  return showAppDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final Widget cancelAction;
      final Widget confirmAction;
      if (PlatformHelper.isApple(dialogContext)) {
        cancelAction = CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(resolvedCancelText),
        );
        confirmAction = CupertinoDialogAction(
          isDestructiveAction: isDestructive,
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(resolvedConfirmText),
        );
      } else {
        final errorColor = Theme.of(dialogContext).colorScheme.error;
        cancelAction = TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(resolvedCancelText),
        );
        confirmAction = TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: isDestructive
              ? TextButton.styleFrom(foregroundColor: errorColor)
              : null,
          child: Text(
            resolvedConfirmText,
            style: isDestructive
                ? TextStyle(color: errorColor)
                : null,
          ),
        );
      }
      return AppDialog(
        title: Text(title),
        content: Text(message),
        actions: [cancelAction, confirmAction],
      );
    },
  );
}

class ResponsiveDialogHelper {
  const ResponsiveDialogHelper._();

  static double maxWidth(
    BuildContext context, {
    double desktopMaxWidth = 560,
    double mobileHorizontalMargin = 16,
  }) {
    if (!context.isMobile) {
      return desktopMaxWidth;
    }
    final horizontalInset = mobileHorizontalMargin * 2;
    return context.screenWidth - horizontalInset;
  }

  static EdgeInsets insetPadding({double all = 16}) => EdgeInsets.all(all);

  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static ButtonStyle actionButtonStyle(BuildContext context) =>
      TextButton.styleFrom(foregroundColor: iconColor(context));

  static ButtonStyle segmentedButtonStyle(BuildContext context) =>
      SegmentedButton.styleFrom(selectedForegroundColor: iconColor(context));
}
