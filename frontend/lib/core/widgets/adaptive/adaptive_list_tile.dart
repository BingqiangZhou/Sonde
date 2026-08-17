import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/platform/platform_helper.dart';

/// Adaptive list tile.
///
/// iOS: [CupertinoListTile] with Cupertino-style padding and dividers.
/// Android: Material [ListTile].
class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leadingToTitle,
    this.contentPadding,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? leadingToTitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      final cupertinoTile = CupertinoListTile(
        leading: leading,
        title: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: title,
        ),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        leadingToTitle: leadingToTitle ?? 16.0,
      );

      if (contentPadding != null) {
        return Padding(
          padding: contentPadding!,
          child: cupertinoTile,
        );
      }
      return cupertinoTile;
    }

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      contentPadding: contentPadding,
    );
  }
}
