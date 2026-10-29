import 'package:flutter/material.dart';

/// Named text style helpers filling gaps between standard TextTheme slots.
///
/// Sizes deliberately stay on the app's type scale (11 / 12 / 14 / 16 —
/// matching labelSmall / bodySmall / bodyMedium / bodyLarge) instead of
/// introducing 1px off-scale steps. These are pure functions with no theme
/// dependency.
class AppTextStyles {
  AppTextStyles._();

  /// Monospace style for code, timestamps, and data.
  ///
  /// Uses the platform monospace fallback chain; no bundled family is
  /// guaranteed on Android/iOS/desktop.
  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
      fontFamily: 'monospace',
      fontFamilyFallback: <String>['RobotoMono', 'Menlo', 'Consolas'],
      color: color,
    );
  }

  /// Transcript body text (fontSize: 14, height: 1.6).
  static TextStyle transcriptBody([Color? color]) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
    color: color,
  );

  /// Caption text (fontSize: 12, height: 1.4).
  static TextStyle caption([Color? color]) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
    color: color,
  );

  /// Compact metadata text (fontSize: 11, height: 1.3).
  static TextStyle metaSmall([Color? color]) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    color: color,
  );

  /// Navigation rail label (fontSize: 10, height: 1.0).
  static TextStyle navLabel(Color? color, {FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontSize: 10,
      fontWeight: weight,
      height: 1,
      letterSpacing: 0.2,
      color: color,
    );
}
