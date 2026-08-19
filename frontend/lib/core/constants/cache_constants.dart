/// Unified cache and pagination constants for the application.
///
/// Centralizing these values ensures consistency across providers
/// and makes it easy to adjust cache behavior globally.
class CacheConstants {
  CacheConstants._();

  // ==================== Cache Durations ====================

  /// Cache duration for the podcast feed (episodes from all subscriptions).
  /// Balanced duration to reduce API calls while keeping content fresh.
  static const Duration feedCacheDuration = Duration(minutes: 2);

  /// Default cache duration for list data that doesn't change often.
  static const Duration defaultListCacheDuration = Duration(minutes: 5);

  /// Cache duration for discover/chart data.
  /// Charts don't update very frequently.
  static const Duration discoverCacheDuration = Duration(minutes: 5);

  // ==================== Pagination Sizes ====================

  /// Default page size for paginated API requests.
  static const int defaultPageSize = 20;

  /// Page size for subscription lists (smaller for faster initial load).
  static const int subscriptionsPageSize = 10;

  /// Initial fetch limit for discover charts. The whole chart is fetched
  /// in one request and sliced into shelves client-side; there is no
  /// incremental pagination.
  static const int discoverInitialFetchLimit = 100;

  /// Maximum number of items to load for discover charts (RSS API cap).
  static const int discoverTopChartMaxLimit = 100;

  /// Number of ranked rows shown per shelf on the discover browse page.
  static const int discoverShelfItemCount = 7;

  /// Category shelves sliced from the top-shows chart on the browse page.
  static const int discoverCategoryShelfCount = 3;

  /// Minimum shows in a category for it to earn its own shelf.
  static const int discoverCategoryShelfMinItems = 5;
}
