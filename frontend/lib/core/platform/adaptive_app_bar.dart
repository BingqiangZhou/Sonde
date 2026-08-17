import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/platform/platform_helper.dart';

PreferredSizeWidget adaptiveAppBar(
  BuildContext context, {
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  bool? centerTitle,
  Color? backgroundColor,
}) {
  final isIOS = PlatformHelper.isApple(context);
  return AppBar(
    title: titleWidget ?? (title != null ? Text(title, overflow: TextOverflow.ellipsis) : null),
    elevation: 0,
    scrolledUnderElevation: isIOS ? 0.1 : 0,
    centerTitle: centerTitle ?? isIOS,
    backgroundColor: backgroundColor ?? Colors.transparent,
    surfaceTintColor: Colors.transparent,
    actions: actions,
    leading: leading,
  );
}
