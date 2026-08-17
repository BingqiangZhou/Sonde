/// Scrolling view unified configuration constants.
///
/// Centralizing scroll-related values ensures consistency across
/// the application and makes it easy to adjust scroll behavior globally.
class ScrollConstants {
  ScrollConstants._();

  // ==================== Cache Extent ====================

  /// Default cache area size (pixels).
  /// Suitable for most list views with standard item heights.
  static const double defaultCacheExtent = 500;

  /// Large list cache area size.
  /// Used for lists with many items or complex layouts.
  static const double largeListCacheExtent = 1000;

  // ==================== Item Extent ====================

  /// Queue item height estimate.
  /// Height for podcast queue items with cover and metadata.
  static const double queueItemExtent = 88;

  // ==================== Load More Threshold ====================

  /// Load more trigger threshold (pixels from bottom).
  /// When scroll position reaches this distance from bottom,
  /// load more data should be triggered.
  static const double loadMoreThreshold = 320;
}
