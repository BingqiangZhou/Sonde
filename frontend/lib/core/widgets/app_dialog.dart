import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/platform/platform_helper.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';

/// The unified modal dialog shell used by every dialog in the app.
///
/// Renders one consistent surface across platforms:
/// - Apple: centered title, `systemBackground` surface, Cupertino-flavored text.
/// - Others: start-aligned title, `surfaceContainerHighest` surface.
///
/// Actions are laid out by form factor: mobile gets an iOS-style stretched row
/// (large touch targets), desktop gets an end-aligned compact row.
///
/// Always shown via [showAppDialog]:
/// ```dart
/// showAppDialog(
///   context: context,
///   builder: (ctx) => AppDialog(
///     title: Text(l10n.some_title),
///     content: Text(l10n.some_message),
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.of(ctx).pop(),
///         child: Text(l10n.ok),
///       ),
///     ],
///   ),
/// );
/// ```
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.content,
    this.title,
    this.actions = const <Widget>[],
    this.maxWidth = 560,
    super.key,
  });

  /// Dialog title above [content]. May be null for status/loading dialogs.
  final Widget? title;

  /// Dialog body.
  final Widget content;

  /// Action widgets; the shell decides their layout.
  final List<Widget> actions;

  /// Maximum dialog width on desktop. Mobile always fills the screen minus
  /// the dialog inset padding.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isApple = PlatformHelper.isApple(context);
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final hasTitle = title != null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ResponsiveDialogHelper.maxWidth(
          context,
          desktopMaxWidth: maxWidth,
        ),
      ),
      child: Material(
        color: isApple
            ? CupertinoColors.systemBackground.resolveFrom(context)
            : theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appThemeOf(context).dialogRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Stretch so the dialog always fills its constrained max width.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasTitle)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  isApple ? AppSpacing.mdLg : AppSpacing.lg,
                  spacing.lg,
                  isApple ? AppSpacing.sm : AppSpacing.md,
                ),
                child: Align(
                  alignment: isApple
                      ? Alignment.center
                      : AlignmentDirectional.centerStart,
                  child: DefaultTextStyle(
                    style: isApple
                        ? CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                fontSize: theme.textTheme.titleLarge?.fontSize,
                                fontWeight: FontWeight.w600,
                              )
                        : theme.textTheme.titleLarge!,
                    child: title!,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                hasTitle ? 0 : (isApple ? AppSpacing.mdLg : AppSpacing.lg),
                spacing.lg,
                spacing.md,
              ),
              child: Align(
                alignment: isApple
                    ? Alignment.center
                    : AlignmentDirectional.centerStart,
                child: DefaultTextStyle(
                  style: isApple
                      ? CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              fontSize:
                                  theme.textTheme.bodyMedium?.fontSize,
                            )
                      : theme.textTheme.bodyMedium!,
                  child: content,
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              if (context.isMobile)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in actions) Expanded(child: action),
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.smMd,
                    spacing.md,
                    spacing.smMd,
                  ),
                  // OverflowBar wraps actions to a column instead of
                  // overflowing when they cannot fit on one line.
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: spacing.sm,
                    children: actions,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
