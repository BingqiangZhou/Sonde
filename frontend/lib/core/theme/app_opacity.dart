/// Semantic opacity tokens.
///
/// Use these instead of raw `withValues(alpha: x)` values so tint strength
/// stays consistent across pages. Exotic one-off values may stay literal,
/// but the common intents must map to one of these five levels.
class AppOpacity {
  AppOpacity._();

  /// Ghost tints: icon washes, secondary backgrounds.
  static const double faint = 0.1;

  /// Hairline borders drawn from outline/variant colors.
  static const double border = 0.15;

  /// Fills and pressed/hover overlays.
  static const double light = 0.3;

  /// Disabled states, heavy dividers.
  static const double medium = 0.5;

  /// Prominent tints (hints over fills, ghost text).
  static const double strong = 0.7;
}
