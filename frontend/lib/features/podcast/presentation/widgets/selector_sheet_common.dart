import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';

/// Shared visual language for the compact player selector sheets
/// (playback speed, sleep timer), mirroring the queue sheet header:
/// icon badge + bold title + close button over a hairline divider.
class SelectorSheetHeader extends StatelessWidget {
  const SelectorSheetHeader({
    required this.title,
    super.key,
    this.icon,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
    this.titleStyle,
    this.titleMaxLines = 1,
    this.onClose,
  }) : assert(
         leading != null || icon != null,
         'Provide either a custom leading widget or an icon.',
       );

  /// Icon rendered inside the default tonal badge when no [leading]
  /// widget is given.
  final IconData? icon;

  /// Title text; rendered with [titleStyle] when given, otherwise
  /// `titleMedium` w800.
  final String title;

  /// Optional supporting line under the title.
  final String? subtitle;

  /// Replaces the default icon badge (e.g. a podcast artwork).
  final Widget? leading;

  /// Optional action placed left of the built-in close button.
  final Widget? trailing;

  /// Optional row rendered below the title row, above the divider.
  final Widget? bottom;

  final TextStyle? titleStyle;
  final int titleMaxLines;

  /// Overrides the default pop behaviour of the close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.md,
        context.spacing.smMd,
        context.spacing.sm,
        context.spacing.smMd,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              leading ??
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.mdLgRadius,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style:
                          titleStyle ??
                          theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: context.spacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
              SelectorSheetCloseButton(onClose: onClose),
            ],
          ),
          if (bottom != null) ...[
            SizedBox(height: context.spacing.smMd),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// The standard sheet close affordance: compact icon button with a
/// localized tooltip that pops the enclosing route by default.
class SelectorSheetCloseButton extends StatelessWidget {
  const SelectorSheetCloseButton({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IconButton(
      tooltip: l10n.close,
      visualDensity: VisualDensity.compact,
      onPressed: onClose ?? () => Navigator.of(context).pop(),
      icon: const Icon(Icons.close_rounded),
    );
  }
}

/// Selectable pill option used by selector sheets. Sized for comfortable
/// touch targets; the width hugs its label so long localized durations
/// never overflow.
class SelectorOptionPill extends StatelessWidget {
  const SelectorOptionPill({
    required this.label,
    required this.onTap,
    super.key,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillRadius,
        child: AdaptiveInkWell(
          borderRadius: AppRadius.pillRadius,
          onTap: onTap,
          child: Container(
            height: 44,
            constraints: const BoxConstraints(minWidth: 84),
            padding: EdgeInsets.symmetric(horizontal: context.spacing.mdLg),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: AppRadius.pillRadius,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.55)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width tinted action row (e.g. "stop after episode", "cancel timer").
class SelectorActionRow extends StatelessWidget {
  const SelectorActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = foregroundColor ?? theme.colorScheme.primary;

    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: AppRadius.lgXlRadius,
      clipBehavior: Clip.antiAlias,
      child: AdaptiveInkWell(
        borderRadius: AppRadius.lgXlRadius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.smMd,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
