import 'package:material_ui/material_ui.dart';

import 'package:sonde/core/theme/app_colors.dart';

/// ============================================================
/// Arc+Linear Design System - 形状与圆角系统
///
/// Design Philosophy:
/// - Clean geometric radii aligned with Apple HIG
/// - Arc+Linear: consistent, intentional radius scale
/// ============================================================

/// Design tokens for border radius throughout the app.
///
/// Values are aligned with [AppThemeExtension] as the single source of truth.
/// Use the pre-built [BorderRadius] and [RoundedRectangleBorder] getters
/// for convenience, or access [AppThemeExtension] directly for theme-aware values.
class AppRadius {
  AppRadius._();

  // ============================================================
  // CORE RADIUS VALUES — aligned with AppThemeExtension
  // ============================================================

  // Incremental scale
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double mdLg = 12;
  static const double lg = 14;
  static const double lgXl = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxlCard = 22;
  static const double chip = 18;
  static const double pill = 999;

  // ============================================================
  // PRE-BUILT BORDER RADIUS INSTANCES - 预构建圆角实例
  // ============================================================

  static BorderRadius get xsRadius => BorderRadius.circular(xs);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get mdLgRadius => BorderRadius.circular(mdLg);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get lgXlRadius => BorderRadius.circular(lgXl);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get xxlRadius => BorderRadius.circular(xxl);
  static BorderRadius get xxlCardRadius => BorderRadius.circular(xxlCard);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);

  // ============================================================
  // ROUNDED RECTANGLE BORDER SHAPES - 预构建形状
  // ============================================================

  static RoundedRectangleBorder get mdLgShape =>
      RoundedRectangleBorder(borderRadius: mdLgRadius);
  static RoundedRectangleBorder get pillShape =>
      RoundedRectangleBorder(borderRadius: pillRadius);
}
