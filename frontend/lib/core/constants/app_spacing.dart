import 'package:flutter/widgets.dart';

import 'package:sonde/core/constants/breakpoints.dart';

/// Spacing system for the Sonde.
///
/// Follows a 4-point grid scale for consistent, predictable spacing.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2; // minimal: fine-grained spacing
  static const double xs = 4; // tight: icon-text gap, compact elements
  static const double xsSm = 6; // between xs and sm
  static const double sm = 8; // small: within-group spacing
  static const double smLg = 10; // between sm and smMd
  static const double smMd = 12; // medium-small: list item internal
  static const double mdXs = 14; // between smMd and md
  static const double md = 16; // standard: default element gap (most used)
  static const double mdSm = 18; // between md and mdLg
  static const double mdLg = 20; // medium-large: card content padding
  static const double lgXs = 22; // between mdLg and lg
  static const double lg = 24; // large: section separators
  static const double xl = 32; // extra-large: major block separators
  static const double xxl = 48; // page-level whitespace
}

/// Responsive spacing data with compact (mobile) and standard (tablet/desktop) variants.
class AppSpacingData {
  const AppSpacingData({
    required this.xxs,
    required this.xs,
    required this.xsSm,
    required this.sm,
    required this.smLg,
    required this.smMd,
    required this.mdXs,
    required this.md,
    required this.mdSm,
    required this.mdLg,
    required this.lgXs,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  final double xxs;
  final double xs;
  final double xsSm;
  final double sm;
  final double smLg;
  final double smMd;
  final double mdXs;
  final double md;
  final double mdSm;
  final double mdLg;
  final double lgXs;
  final double lg;
  final double xl;
  final double xxl;

  static const standard = AppSpacingData(
    xxs: 2,
    xs: 4,
    xsSm: 6,
    sm: 8,
    smLg: 10,
    smMd: 12,
    mdXs: 14,
    md: 16,
    mdSm: 18,
    mdLg: 20,
    lgXs: 22,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  static const compact = AppSpacingData(
    xxs: 1,
    xs: 3,
    xsSm: 4,
    sm: 6,
    smLg: 8,
    smMd: 8,
    mdXs: 10,
    md: 12,
    mdSm: 12,
    mdLg: 14,
    lgXs: 16,
    lg: 16,
    xl: 20,
    xxl: 28,
  );
}

/// Provides responsive spacing via [BuildContext].
///
/// Returns [AppSpacingData.compact] on mobile (<600px),
/// [AppSpacingData.standard] otherwise.
extension SpacingExtension on BuildContext {
  AppSpacingData get spacing =>
      MediaQuery.sizeOf(this).width < Breakpoints.medium
          ? AppSpacingData.compact
          : AppSpacingData.standard;
}
