import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/theme/app_colors.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.title, required this.children, super.key,
    this.cardMargin = EdgeInsets.zero,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry cardMargin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacing.sm, bottom: context.spacing.sm),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: cardMargin,
          // Material 直接承载填充/边框/圆角，保证内部 ListTile 的
          // 背景和水波纹绘制在最近的 Material 上（Flutter 3.47 断言要求）。
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
