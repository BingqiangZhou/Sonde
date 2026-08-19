import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/app/config/app_config.dart';
import 'package:sonde/core/database/database_provider.dart';
import 'package:sonde/core/network/dio_client.dart';
import 'package:sonde/core/network/server_health_service.dart';
import 'package:sonde/core/services/app_cache_service.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/utils/url_normalizer.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_daily_report_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_feed_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';

/// Server URL resolved during bootstrap (stored custom URL or environment
/// default); main() overrides it via ProviderScope before runApp.
final bootstrapServerUrlProvider = Provider<String>(
  (ref) => AppConfig.defaultServerBaseUrl,
);

// Dio Client Provider
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient(
    initOptions: DioClientInitOptions(
      initialServerBaseUrl: ref.read(bootstrapServerUrlProvider),
    ),
    secureStorage: ref.read(secureStorageProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});

final appCacheServiceProvider = Provider<AppCacheService>((ref) {
  AppCacheService.initialize();

  return AppCacheService();
});

typedef ServerHealthServiceFactory = ServerHealthService Function();

final serverHealthServiceFactoryProvider = Provider<ServerHealthServiceFactory>(
  (ref) {
    return () => ServerHealthService(Dio());
  },
);

// Server Config Provider - Manages backend server address configuration
class ServerConfigState {

  const ServerConfigState({
    required this.serverUrl,
    this.isLoading = false,
    this.error,
  });
  final String serverUrl;
  final bool isLoading;
  final String? error;

  ServerConfigState copyWith({
    String? serverUrl,
    bool? isLoading,
    String? error,
  }) {
    return ServerConfigState(
      serverUrl: serverUrl ?? this.serverUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServerConfigNotifier extends Notifier<ServerConfigState> {
  LocalStorageService get _storageService => ref.read(localStorageServiceProvider);

  @override
  ServerConfigState build() {
    // Get initial server URL from the bootstrap-resolved value
    final initialUrl = ref.watch(bootstrapServerUrlProvider);
    return ServerConfigState(serverUrl: initialUrl);
  }

  /// Clear all server-related data when switching servers.
  Future<void> _clearAllServerData() async {
    final dioClient = ref.read(dioClientProvider);

    // 1. Clear network cache
    await dioClient.clearCache();

    // 2. Clear cached list responses (Drift response_cache). Best effort;
    // stale rows would expire via TTL anyway.
    await ref.read(appDatabaseProvider).responseCacheDao.clearAll();

    // 3. Clear media cache
    await ref.read(appCacheServiceProvider).clearAll();

    // 4. Clear auth state (was authServerConfigListenerProvider)
    ref.read(authProvider.notifier).clearLocalAuthState();

    // 5. Clear podcast caches (was podcastServerConfigListenerProvider)
    ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
    ref.read(iTunesSearchServiceProvider).clearCache();
    ref.read(profileStatsProvider.notifier).reset();
    ref.read(playbackHistoryLiteProvider.notifier).reset();
    ref.invalidate(podcastFeedProvider);
    ref.invalidate(podcastDiscoverProvider);
    ref.invalidate(podcastSubscriptionProvider);
    ref.invalidate(podcastEpisodesProvider);
    ref.invalidate(profileStatsProvider);
    ref.invalidate(playbackHistoryLiteProvider);
    ref.invalidate(podcastStatsProvider);
    ref.invalidate(dailyReportProvider);
    ref.invalidate(dailyReportDatesProvider);
    ref.invalidate(podcastSearchProvider);
  }

  /// Update server base URL and apply to DioClient
  /// If [clearData] is true and URL changes, all server data will be cleared
  Future<void> updateServerUrl(String newUrl, {bool clearData = true}) async {
    final oldUrl = state.serverUrl;
    state = state.copyWith(isLoading: true);

    try {
      // Normalize URL
      final normalizedUrl = UrlNormalizer.normalize(newUrl);

      // Clear all server data if URL changed and clearData is true
      if (clearData && oldUrl != normalizedUrl) {
        await _clearAllServerData();
      }

      // Save to storage
      await _storageService.saveServerBaseUrl(normalizedUrl);

      // Update DioClient
      final dioClient = ref.read(dioClientProvider);
      dioClient.updateBaseUrl('$normalizedUrl/api/v1');

      state = state.copyWith(serverUrl: normalizedUrl, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update server URL: $e',
      );
    }
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfigState>(
      ServerConfigNotifier.new,
    );
