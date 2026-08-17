import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache configuration constants.
///
/// These values are tuned for a podcast/feed reader app with:
/// - Mix of small icons and large cover images
/// - Need for both performance and disk space management
/// - Offline-first usage pattern
class _AppCacheConfig {
  /// Maximum number of cached media objects (images, audio files)
  /// 200 is reasonable for podcast cover art and feed icons
  static const int maxNrOfCacheObjects = 200;

  /// Cache duration before considering stale
  /// 30 days for media files is reasonable for podcast content
  static const Duration stalePeriod = Duration(days: 30);

  /// Maximum memory cache size for images
  /// 100 MB is a good balance between performance and memory
  static const int maxMemoryCacheSize = 100 * 1024 * 1024;

  /// Maximum number of images to keep in memory
  /// Reduces from default 1000 to 200 for better memory management
  static const int maxMemoryCacheEntries = 200;
}

class AppMediaCacheManager extends CacheManager {

  AppMediaCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: _AppCacheConfig.stalePeriod,
            maxNrOfCacheObjects: _AppCacheConfig.maxNrOfCacheObjects,
            // Use custom file service for better error handling
            fileService: HttpFileService(),
          ),
        );
  static const String key = 'app_media_cache';
  static final AppMediaCacheManager instance = AppMediaCacheManager._();
}

class AppCacheService {
  static bool _initialized = false;

  /// Initialize the cache service with optimized memory settings.
  ///
  /// Should be called once at app startup. Safe to call multiple times;
  /// subsequent calls are no-ops.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    final imageCache = PaintingBinding.instance.imageCache;

    // Configure memory cache size
    // Default is 1000 entries, we reduce to 200 for better memory management
    imageCache.maximumSize = _AppCacheConfig.maxMemoryCacheEntries;

    // Set maximum memory cache size in bytes
    // Default varies by device, we set to 100MB
    imageCache.maximumSizeBytes = _AppCacheConfig.maxMemoryCacheSize;

    // Only clear live images that are no longer pinned by widgets.
    // Do NOT call imageCache.clear() — that discards all cached images
    // including valid ones, forcing unnecessary network re-fetches.
    // flutter_cache_manager handles disk staleness per-file via stalePeriod.
    imageCache.clearLiveImages();
  }

  CacheManager get mediaCacheManager => AppMediaCacheManager.instance;

  Future<void> clearMediaCache() async {
    await mediaCacheManager.emptyCache();
  }

  Future<void> clearMemoryImageCache() async {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  Future<void> clearAll() async {
    await clearMediaCache();
    await clearMemoryImageCache();
  }
}
