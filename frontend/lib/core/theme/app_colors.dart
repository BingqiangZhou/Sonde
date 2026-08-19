import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';

/// ============================================================
/// App Design System
///
/// Design Philosophy:
/// Apple HIG system tints on flat, subtly-bordered surfaces
/// combined with precise typography and spacing.
/// ============================================================

class AppColors {
  AppColors._();

  // ============================================================
  // LIGHT THEME - 亮色主题
  /// Arc+Linear surface colors
  // ============================================================

  // Background Colors - 背景色系
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F2F7);
  static const Color lightOnSurfaceMuted = Color(0x8C1a1a2e); // rgba 0.55

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextTertiary = Color(0xFF3C3C43);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color lightOutline = Color(0xFFC7C7CC);
  static const Color lightOutlineVariant = Color(0xFFD1D1D6);


  // ============================================================
  // DARK THEME - 暗色主题
  /// Arc+Linear surface colors
  // ============================================================

  // Background Colors - 背景色系
  static const Color darkBackground = Color(0xFF0f0f1a);
  static const Color darkSurface = Color(0xFF1a1a2e);
  static const Color darkOnBackground = Color(0xE6FFFFFF); // rgba 0.9
  static const Color darkOnSurface = Color(0x80FFFFFF); // rgba 0.5
  static const Color darkOnSurfaceMuted = Color(0x80FFFFFF); // rgba 0.50

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextTertiary = Color(0xFFEBEBF5);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color darkOutline = Color(0xFF48484A);
  static const Color darkOutlineVariant = Color(0xFF3A3A3C);


  // ============================================================
  // BRAND COLORS - 品牌色 (Apple HIG system tints)
  // ============================================================

  // Primary - System Indigo (Apple HIG)
  static const Color primary = Color(0xFF5856D6); // systemIndigo light
  static const Color primaryLight = Color(0xFF5E5CE6); // systemIndigo dark
  static const Color primaryContainer = Color(0xFFE8E8FF);
  static const Color primaryContainerDark = Color(0xFF1E1B4B);

  // Warm accents - System Orange (Apple HIG)
  static const Color accentWarm = Color(0xFFFF9500); // systemOrange light
  static const Color accentWarmDark = Color(0xFFFF9F0A); // systemOrange dark
  static const Color accentCoral = Color(0xFFFF2D55); // systemPink light
  static const Color accentCoralLight = Color(0xFFFF375F); // systemPink dark

  // Tertiary - System Green (Apple HIG)
  static const Color tertiary = Color(0xFF34C759); // systemGreen light

  // ============================================================
  // SEMANTIC COLORS - 语义色彩 (Apple HIG system colors)
  // ============================================================

  static const Color success = Color(0xFF34C759); // systemGreen light
  static const Color warning = Color(0xFFFF9500); // systemOrange light
  static const Color error = Color(0xFFFF3B30); // systemRed light

  // Legacy named colors
  static const Color sunGlow = Color(0xFFFFCC00); // systemYellow light
  static const Color sunRay = Color(0xFFFF3B30); // systemRed light
  static const Color leaf = Color(0xFF34C759); // systemGreen light

  // ============================================================
  // GRADIENT PALETTE - 渐变色板 (Arc-style accents)
  // ============================================================

  static const List<Color> coralColors = [Color(0xFFFF6B6B), Color(0xFFE84545)];
  static const List<Color> violetColors = [Color(0xFF7C6AEF), Color(0xFF5845D6)];
  static const List<Color> goldColors = [Color(0xFFF5A623), Color(0xFFD4901E)];

  static const List<List<Color>> podcastGradientColors = [
    coralColors,
    violetColors,
    [Color(0xFF4FC3D6), Color(0xFF389CAE)],
    goldColors,
    [Color(0xFFFF6B8A), Color(0xFFD4536E)],
    [Color(0xFF5AC8FA), Color(0xFF4AA8D6)],
  ];

  // ============================================================
  // DATA VISUALIZATION - 数据可视化色彩
  /// Using Apple HIG system tint colors
  // ============================================================

  static const Color chart5 = Color(0xFFAF52DE); // systemPurple
  static const Color chart7 = Color(0xFF5AC8FA); // systemTeal
}

/// ============================================================
/// APP THEME EXTENSION
/// App Theme Extension
/// ============================================================

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.contentMaxWidth,
    required this.sectionGap,
    required this.cardRadius,
    required this.buttonRadius,
    required this.navItemRadius,
    required this.itemRadius,
    required this.sheetRadius,
    required this.pillRadius,
    required this.dialogRadius,
    required this.inputFillAlpha,
    required this.listTileHorizontalPadding,
    required this.listTileVerticalPadding,
    required this.listTileRadius,
    required this.centerTitle,
    required this.warmAccent,
    required this.coralAccent,
    required this.shadowXs,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  // Layout
  final double contentMaxWidth;
  final double sectionGap;
  final double cardRadius;
  final double buttonRadius;
  final double navItemRadius;
  final double itemRadius;
  final double sheetRadius;
  final double pillRadius;
  final double dialogRadius;
  final double inputFillAlpha;
  final double listTileHorizontalPadding;
  final double listTileVerticalPadding;
  final double listTileRadius;
  final bool centerTitle;

  // Accent colors (theme-aware, light/dark variants)
  final Color warmAccent;
  final Color coralAccent;

  // Shadows
  final BoxShadow shadowXs;
  final BoxShadow shadowSm;
  final BoxShadow shadowMd;
  final BoxShadow shadowLg;

  @override
  AppThemeExtension copyWith({
    double? contentMaxWidth,
    double? sectionGap,
    double? cardRadius,
    double? buttonRadius,
    double? navItemRadius,
    double? itemRadius,
    double? sheetRadius,
    double? pillRadius,
    double? dialogRadius,
    double? inputFillAlpha,
    double? listTileHorizontalPadding,
    double? listTileVerticalPadding,
    double? listTileRadius,
    bool? centerTitle,
    Color? warmAccent,
    Color? coralAccent,
    BoxShadow? shadowXs,
    BoxShadow? shadowSm,
    BoxShadow? shadowMd,
    BoxShadow? shadowLg,
  }) {
    return AppThemeExtension(
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      navItemRadius: navItemRadius ?? this.navItemRadius,
      itemRadius: itemRadius ?? this.itemRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      inputFillAlpha: inputFillAlpha ?? this.inputFillAlpha,
      listTileHorizontalPadding: listTileHorizontalPadding ?? this.listTileHorizontalPadding,
      listTileVerticalPadding: listTileVerticalPadding ?? this.listTileVerticalPadding,
      listTileRadius: listTileRadius ?? this.listTileRadius,
      centerTitle: centerTitle ?? this.centerTitle,
      warmAccent: warmAccent ?? this.warmAccent,
      coralAccent: coralAccent ?? this.coralAccent,
      shadowXs: shadowXs ?? this.shadowXs,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
    );
  }

  @override
  AppThemeExtension lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      navItemRadius: lerpDouble(navItemRadius, other.navItemRadius, t)!,
      itemRadius: lerpDouble(itemRadius, other.itemRadius, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
      pillRadius: lerpDouble(pillRadius, other.pillRadius, t)!,
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t)!,
      inputFillAlpha: lerpDouble(inputFillAlpha, other.inputFillAlpha, t)!,
      listTileHorizontalPadding: lerpDouble(listTileHorizontalPadding, other.listTileHorizontalPadding, t)!,
      listTileVerticalPadding: lerpDouble(listTileVerticalPadding, other.listTileVerticalPadding, t)!,
      listTileRadius: lerpDouble(listTileRadius, other.listTileRadius, t)!,
      centerTitle: t < 0.5 ? centerTitle : other.centerTitle,
      warmAccent: Color.lerp(warmAccent, other.warmAccent, t)!,
      coralAccent: Color.lerp(coralAccent, other.coralAccent, t)!,
      shadowXs: BoxShadow.lerp(shadowXs, other.shadowXs, t)!,
      shadowSm: BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerp(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerp(shadowLg, other.shadowLg, t)!,
    );
  }

  /// Light theme extension (const base)
  static const light = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 16,
    buttonRadius: 14,
    navItemRadius: 12,
    itemRadius: 10,
    sheetRadius: 20,
    pillRadius: 999,
    dialogRadius: 24,
    inputFillAlpha: 0.6,
    listTileHorizontalPadding: AppSpacing.md,
    listTileVerticalPadding: 0,
    listTileRadius: 14,
    centerTitle: false,
    warmAccent: AppColors.accentWarm,
    coralAccent: AppColors.accentCoral,
    shadowXs: BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    shadowSm: BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 2,
      offset: Offset(0, 2),
    ),
    shadowMd: BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 4),
    ),
    shadowLg: BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 8),
    ),
  );

  /// Dark theme extension (const base)
  static const dark = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 16,
    buttonRadius: 14,
    navItemRadius: 12,
    itemRadius: 10,
    sheetRadius: 20,
    pillRadius: 999,
    dialogRadius: 24,
    inputFillAlpha: 0.6,
    listTileHorizontalPadding: AppSpacing.md,
    listTileVerticalPadding: 0,
    listTileRadius: 14,
    centerTitle: false,
    warmAccent: AppColors.accentWarmDark,
    coralAccent: AppColors.accentCoralLight,
    shadowXs: BoxShadow(
      color: Color(0x33000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    shadowSm: BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 2,
      offset: Offset(0, 2),
    ),
    shadowMd: BoxShadow(
      color: Color(0x66000000),
      blurRadius: 4,
      offset: Offset(0, 4),
    ),
    shadowLg: BoxShadow(
      color: Color(0x80000000),
      blurRadius: 8,
      offset: Offset(0, 8),
    ),
  );

  /// Light theme extension for iOS (flat shadows, padded list tiles).
  /// Radii are unified across platforms; only feel-related tweaks differ.
  /// Derived from [light] via copyWith.
  static AppThemeExtension lightIOS() => _iosFrom(light);

  /// Dark theme extension for iOS (flat shadows, padded list tiles).
  /// Radii are unified across platforms; only feel-related tweaks differ.
  /// Derived from [dark] via copyWith.
  static AppThemeExtension darkIOS() => _iosFrom(dark);

  /// Applies the iOS-specific tweaks (transparent shadows, padded list
  /// tiles, centered titles, lighter input fill) to [base]. Radii are
  /// platform-unified and therefore not overridden here.
  static AppThemeExtension _iosFrom(AppThemeExtension base) => base.copyWith(
    inputFillAlpha: 0.4,
    listTileHorizontalPadding: AppSpacing.mdLg,
    listTileVerticalPadding: AppSpacing.xs,
    centerTitle: true,
    shadowXs: const BoxShadow(color: Color(0x00000000)),
    shadowSm: const BoxShadow(color: Color(0x00000000)),
    shadowMd: const BoxShadow(color: Color(0x00000000)),
    shadowLg: const BoxShadow(color: Color(0x00000000)),
  );
}

/// Get the App theme extension from context
AppThemeExtension appThemeOf(BuildContext context) {
  return Theme.of(context).extension<AppThemeExtension>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? AppThemeExtension.dark
          : AppThemeExtension.light);
}
