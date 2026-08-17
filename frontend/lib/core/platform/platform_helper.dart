import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart' show Breakpoints;

class PlatformHelper {
  PlatformHelper._();

  static bool isIOS(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  static bool isAndroid(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.android;
  }

  /// Returns true on macOS, Windows, or Linux.
  ///
  /// **Note:** Always returns false on web due to the [kIsWeb] guard,
  /// even when the browser viewport is wide. Use [Breakpoints] for
  /// width-based layout decisions on web.
  static bool isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  static bool isMacOS(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.macOS;
  }

  static bool isApple(BuildContext context) {
    return isIOS(context) || isMacOS(context);
  }
}
