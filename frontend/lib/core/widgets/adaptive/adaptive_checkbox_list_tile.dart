import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive checkbox list tile.
///
/// iOS: [CupertinoListTile] with a trailing [CupertinoCheckbox].
/// Android: Material [CheckboxListTile].
class AdaptiveCheckboxListTile extends StatelessWidget {
  const AdaptiveCheckboxListTile({
    required this.title,
    super.key,
    this.subtitle,
    this.value,
    this.onChanged,
    this.contentPadding,
  });

  final Widget title;
  final Widget? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      final cupertinoTile = CupertinoListTile(
        title: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: title,
        ),
        subtitle: subtitle,
        trailing: CupertinoCheckbox(
          value: value ?? false,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        onTap: () => onChanged?.call(!(value ?? false)),
      );

      if (contentPadding != null) {
        return Padding(
          padding: contentPadding!,
          child: cupertinoTile,
        );
      }
      return cupertinoTile;
    }

    return CheckboxListTile(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      contentPadding: contentPadding,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
