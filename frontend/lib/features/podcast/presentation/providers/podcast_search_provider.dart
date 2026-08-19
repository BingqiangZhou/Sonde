import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/cache_constants.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/utils/debounce.dart' as utils;
import 'package:sonde/core/utils/request_dedup.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:sonde/features/podcast/data/services/itunes_search_service.dart';

final podcastSearchDebounceDurationProvider = Provider<Duration>((ref) {
  return AppDurations.debounceMedium;
});

class PodcastSearchState extends Equatable {

  const PodcastSearchState({
    this.podcastResults = const [],
    this.episodeResults = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
    this.currentQuery = '',
    this.searchCountry = PodcastCountry.china,
  });
  final List<PodcastSearchResult> podcastResults;
  final List<ITunesPodcastEpisodeResult> episodeResults;
  final bool isLoading;
  final bool hasSearched;
  final String? error;
  final String currentQuery;
  final PodcastCountry searchCountry;

  PodcastSearchState copyWith({
    List<PodcastSearchResult>? podcastResults,
    List<ITunesPodcastEpisodeResult>? episodeResults,
    bool? isLoading,
    bool? hasSearched,
    String? error,
    String? currentQuery,
    PodcastCountry? searchCountry,
  }) {
    return PodcastSearchState(
      podcastResults: podcastResults ?? this.podcastResults,
      episodeResults: episodeResults ?? this.episodeResults,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: error,
      currentQuery: currentQuery ?? this.currentQuery,
      searchCountry: searchCountry ?? this.searchCountry,
    );
  }

  @override
  List<Object?> get props => [
        podcastResults,
        episodeResults,
        isLoading,
        hasSearched,
        error,
        currentQuery,
        searchCountry,
      ];
}

final iTunesSearchServiceProvider = Provider<ITunesSearchService>((ref) {
  return ITunesSearchService();
});

final podcastSearchProvider =
    NotifierProvider<PodcastSearchNotifier, PodcastSearchState>(
      PodcastSearchNotifier.new,
    );

class PodcastSearchNotifier extends Notifier<PodcastSearchState> {
  utils.DebounceTimer? _debounce;
  Duration get _debounceDuration => ref.read(podcastSearchDebounceDurationProvider);
  final RequestToken _searchToken = RequestToken();

  @override
  PodcastSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });

    return const PodcastSearchState();
  }

  /// Searches both podcasts and podcast episodes for [query] — one
  /// search, two result kinds, rendered as separate sections.
  void search(String query) {
    _scheduleSearch(query);
  }

  void _scheduleSearch(
    String query, {
    bool bypassDebounce = false,
  }) {
    _debounce?.cancel();
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      _searchToken.cancel();
      state = const PodcastSearchState();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      hasSearched: true,
      currentQuery: normalizedQuery,
    );

    final requestId = _searchToken.begin();
    final delay = bypassDebounce ? Duration.zero : _debounceDuration;
    _debounce = utils.DebounceTimer(delay, () async {
      await _performSearch(normalizedQuery, requestId: requestId);
    });
  }

  Future<void> _performSearch(
    String query, {
    required int requestId,
  }) async {
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);

    try {
      // Both charts in parallel — the results view sections them.
      final (podcastResponse, episodes) = await (
        searchService.searchPodcasts(term: query, country: country),
        searchService.searchPodcastEpisodes(term: query, country: country),
      ).wait;

      if (!_isRequestActive(requestId, query)) {
        return;
      }
      state = state.copyWith(
        podcastResults: podcastResponse.results,
        episodeResults: episodes,
        isLoading: false,
        searchCountry: country,
      );
    } catch (error) {
      if (!_isRequestActive(requestId, query)) {
        return;
      }
      state = state.copyWith(
        podcastResults: const [],
        episodeResults: const [],
        isLoading: false,
        searchCountry: country,
        error: mapErrorMessage(error),
      );
    }
  }

  bool _isRequestActive(int requestId, String query) {
    return _searchToken.isCurrent(requestId) && state.currentQuery == query;
  }

  void clearSearch() {
    _debounce?.cancel();
    _searchToken.cancel();
    state = const PodcastSearchState();
  }

  Future<void> retrySearch() async {
    if (state.currentQuery.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true);
    final requestId = _searchToken.begin();
    await _performSearch(
      state.currentQuery,
      requestId: requestId,
    );
  }
}

// Country Selector

/// 国家选择状态
class CountrySelectorState {

  const CountrySelectorState({
    required this.selectedCountry,
    this.isLoading = false,
  });
  final PodcastCountry selectedCountry;
  final bool isLoading;

  CountrySelectorState copyWith({
    PodcastCountry? selectedCountry,
    bool? isLoading,
  }) {
    return CountrySelectorState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 国家选择器 Notifier
final countrySelectorProvider =
    NotifierProvider<CountrySelectorNotifier, CountrySelectorState>(
      CountrySelectorNotifier.new,
    );

class CountrySelectorNotifier extends Notifier<CountrySelectorState> {
   @override
  CountrySelectorState build() {
    final localStorage = ref.read(localStorageServiceProvider);

    // Load saved country preference asynchronously
    _loadSavedCountry(localStorage);

    return CountrySelectorState(
      selectedCountry: _getDefaultCountry(),
    );
  }

  /// 获取默认国家
  PodcastCountry _getDefaultCountry() {
    return PodcastCountry.china;
  }

  /// 从本地存储加载保存的国家偏好
  Future<void> _loadSavedCountry(LocalStorageService localStorage) async {
    final savedCountryCode = await localStorage.getString('podcast_search_country');

    if (savedCountryCode != null) {
      final savedCountry = PodcastCountry.values.firstWhere(
        (country) => country.code == savedCountryCode,
        orElse: _getDefaultCountry,
      );

      if (state.selectedCountry != savedCountry) {
        state = CountrySelectorState(selectedCountry: savedCountry);
      }
    }
  }

  /// 选择国家
  Future<void> selectCountry(PodcastCountry country) async {
    final localStorage = ref.read(localStorageServiceProvider);

    state = CountrySelectorState(selectedCountry: country);

    // 保存到本地存储
    await localStorage.saveString('podcast_search_country', country.code);
  }

  /// 获取当前选中的国家
  PodcastCountry get selectedCountry => state.selectedCountry;
}

// Discover

class PodcastDiscoverState extends Equatable {

  const PodcastDiscoverState({
    required this.country,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedCategory = allCategoryValue,
    this.topShows = const [],
    this.topEpisodes = const [],
    this.showFeedUrls = const {},
    this.episodeMeta = const {},
    this.lastRefreshTime,
  });
  final PodcastCountry country;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String selectedCategory;
  final List<PodcastDiscoverItem> topShows;
  final List<PodcastDiscoverItem> topEpisodes;

  /// iTunes show id -> RSS feed url, hydrated via one batched lookup after
  /// a chart load. Lets chart rows derive their subscribed state from the
  /// global subscription list instead of a session-local overlay alone.
  final Map<int, String> showFeedUrls;

  /// Episode track id -> hydrated iTunes metadata (duration, release date)
  /// for the trending-episodes shelf rows.
  final Map<int, ITunesPodcastEpisodeResult> episodeMeta;
  final DateTime? lastRefreshTime;

  static const String allCategoryValue = '__all__';

  PodcastDiscoverState copyWith({
    PodcastCountry? country,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    String? selectedCategory,
    List<PodcastDiscoverItem>? topShows,
    List<PodcastDiscoverItem>? topEpisodes,
    Map<int, String>? showFeedUrls,
    Map<int, ITunesPodcastEpisodeResult>? episodeMeta,
    DateTime? lastRefreshTime,
  }) {
    return PodcastDiscoverState(
      country: country ?? this.country,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      selectedCategory: selectedCategory ?? this.selectedCategory,
      topShows: topShows ?? this.topShows,
      topEpisodes: topEpisodes ?? this.topEpisodes,
      showFeedUrls: showFeedUrls ?? this.showFeedUrls,
      episodeMeta: episodeMeta ?? this.episodeMeta,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  bool isDataFresh({
    Duration cacheDuration = CacheConstants.discoverCacheDuration,
  }) {
    final refreshTime = lastRefreshTime;
    if (refreshTime == null) return false;
    return DateTime.now().difference(refreshTime) < cacheDuration;
  }

  bool get hasData => topShows.isNotEmpty || topEpisodes.isNotEmpty;

  /// The first rows shown on the browse page's ranked shelves.
  List<PodcastDiscoverItem> get topShowsPreview =>
      topShows.take(CacheConstants.discoverShelfItemCount).toList();

  List<PodcastDiscoverItem> get topEpisodesPreview =>
      topEpisodes.take(CacheConstants.discoverShelfItemCount).toList();

  List<String> get categories {
    final counts = <String, int>{};
    for (final item in topShows.followedBy(topEpisodes)) {
      for (final genre in item.genres) {
        final trimmed = genre.trim();
        if (trimmed.isEmpty) continue;
        counts[trimmed] = (counts[trimmed] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return sorted.map((entry) => entry.key).toList();
  }

  List<PodcastDiscoverItem> get filteredShows => selectedCategory == allCategoryValue
      ? topShows
      : topShows.where((item) => item.hasGenre(selectedCategory)).toList();

  List<PodcastDiscoverItem> get filteredEpisodes =>
      selectedCategory == allCategoryValue
          ? topEpisodes
          : topEpisodes.where((item) => item.hasGenre(selectedCategory)).toList();

  @override
  List<Object?> get props => [
        country,
        isLoading,
        isRefreshing,
        error,
        selectedCategory,
        topShows,
        topEpisodes,
        showFeedUrls,
        episodeMeta,
        lastRefreshTime,
      ];
}

final applePodcastRssServiceProvider = Provider<ApplePodcastRssService>((ref) {
  return ApplePodcastRssService.ref();
});

final podcastDiscoverProvider =
    NotifierProvider<PodcastDiscoverNotifier, PodcastDiscoverState>(
      PodcastDiscoverNotifier.new,
    );

class PodcastDiscoverNotifier extends Notifier<PodcastDiscoverState> {
  ApplePodcastRssService get _rssService => ref.read(applePodcastRssServiceProvider);
  final InFlightSlot<void> _loadSlot = InFlightSlot<void>();
  PodcastCountry? _loadSlotCountry;
  final RequestToken _requestToken = RequestToken();

  @override
  PodcastDiscoverState build() {
    // Reset in-flight tracking on rebuild to avoid stale futures
    _loadSlot.reset();
    _loadSlotCountry = null;

    final selectedCountry = ref.read(countrySelectorProvider).selectedCountry;

    ref.listen<CountrySelectorState>(countrySelectorProvider, (previous, next) {
      final previousCountry = previous?.selectedCountry;
      if (previousCountry != next.selectedCountry) {
        unawaited(onCountryChanged(next.selectedCountry));
      }
    });

    return PodcastDiscoverState(country: selectedCountry);
  }

  Future<void> loadInitialData() async {
    if (state.hasData && state.isDataFresh()) {
      return;
    }
    await _loadCharts(country: state.country, isRefresh: false);
  }

  Future<void> refresh() async {
    await _loadCharts(
      country: state.country,
      isRefresh: true,
      forceRefresh: true,
    );
  }

  Future<void> onCountryChanged(PodcastCountry country) async {
    if (country == state.country && state.hasData && state.isDataFresh()) {
      return;
    }
    state = state.copyWith(
      country: country,
      selectedCategory: PodcastDiscoverState.allCategoryValue,
      topShows: const [],
      topEpisodes: const [],
      showFeedUrls: const {},
      episodeMeta: const {},
      clearError: true,
    );
    await _loadCharts(country: country, isRefresh: false, forceRefresh: true);
  }

  void selectCategory(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(selectedCategory: normalized);
  }

  /// Records a show's feed url learned outside the batched hydration
  /// (e.g. from a subscribe lookup), keeping the subscribed-state
  /// derivation complete.
  void registerShowFeedUrl(int itunesId, String feedUrl) {
    if (state.showFeedUrls[itunesId] == feedUrl) return;
    state = state.copyWith(
      showFeedUrls: {...state.showFeedUrls, itunesId: feedUrl},
    );
  }

  void clearRuntimeCache() {
    final rssService = ref.read(applePodcastRssServiceProvider);
    final selectedCountry = ref.read(countrySelectorProvider).selectedCountry;
    rssService.clearCache();
    _requestToken.cancel();
    _loadSlot.reset();
    _loadSlotCountry = null;
    state = PodcastDiscoverState(country: selectedCountry);
  }

  Future<void> _loadCharts({
    required PodcastCountry country,
    required bool isRefresh,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        country == state.country &&
        state.hasData &&
        state.isDataFresh()) {
      return;
    }

    final existingLoad = _loadSlot.inFlight;
    if (existingLoad != null &&
        !forceRefresh &&
        _loadSlotCountry == country) {
      return existingLoad;
    }

    final requestId = _requestToken.begin();
    // Replacing any earlier chart load: the stale request keeps running but
    // its results are discarded via the request token above.
    _loadSlot.reset();
    _loadSlotCountry = country;

    state = state.copyWith(
      country: country,
      isLoading: !isRefresh,
      isRefreshing: isRefresh,
      selectedCategory: PodcastDiscoverState.allCategoryValue,
      clearError: true,
    );

    await _loadSlot(() async {
      try {
        // The whole chart is fetched in one request and sliced into
        // shelves client-side; there is no incremental pagination.
        final chartLimit = CacheConstants.discoverTopChartMaxLimit;
        final showsFuture = _rssService.fetchTopShows(
          country: country,
          limit: chartLimit,
        );
        final episodesFuture = _rssService.fetchTopEpisodes(
          country: country,
          limit: chartLimit,
        );

        // Parallel loading for better performance
        final (showsResponse, episodesResponse) = await (
          showsFuture,
          episodesFuture,
        ).wait;

        if (!_isRequestActive(requestId)) {
          return;
        }

        final shows = _mapChartItems(
          showsResponse,
          defaultKind: PodcastDiscoverKind.podcasts,
        );
        final episodes = _mapChartItems(
          episodesResponse,
          defaultKind: PodcastDiscoverKind.podcastEpisodes,
        );

        state = state.copyWith(
          country: country,
          isLoading: false,
          isRefreshing: false,
          topShows: shows,
          topEpisodes: episodes,
          selectedCategory: PodcastDiscoverState.allCategoryValue,
          clearError: true,
          lastRefreshTime: DateTime.now(),
        );

        unawaited(_hydrateChartMeta(requestId, shows, episodes));
      } catch (error) {
        if (!_isRequestActive(requestId)) {
          return;
        }
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: mapErrorMessage(error),
        );
      }
    });
    if (_loadSlot.inFlight == null) {
      _loadSlotCountry = null;
    }
  }

  /// One batched iTunes lookup across the visible chart ids: feed urls for
  /// the subscribed-state derivation and duration/date metadata for the
  /// trending-episodes shelf. Best-effort — failures leave the charts
  /// fully usable, just undecorated.
  Future<void> _hydrateChartMeta(
    int requestId,
    List<PodcastDiscoverItem> shows,
    List<PodcastDiscoverItem> episodes,
  ) async {
    final showIds = shows
        .map((item) => item.itunesId)
        .whereType<int>()
        .take(CacheConstants.discoverTopChartMaxLimit)
        .toList();
    final episodeIds = episodes
        .map((item) => item.itunesId)
        .whereType<int>()
        .take(CacheConstants.discoverShelfItemCount)
        .toList();

    final ids = [...showIds, ...episodeIds];
    if (ids.isEmpty) return;

    try {
      final result = await ref.read(iTunesSearchServiceProvider)
          .lookupChartEntities(ids: ids, country: state.country);
      if (!_isRequestActive(requestId)) return;
      state = state.copyWith(
        showFeedUrls: result.showFeedUrls,
        episodeMeta: result.episodeMeta,
      );
    } catch (_) {
      // Decoration only; chart data already rendered.
    }
  }

  bool _isRequestActive(int requestId) =>
      ref.mounted && _requestToken.isCurrent(requestId);

  List<PodcastDiscoverItem> _mapChartItems(
    ApplePodcastChartResponse response, {
    required PodcastDiscoverKind defaultKind,
  }) {
    return response.feed.results
        .map(
          (entry) => PodcastDiscoverItem.fromChartEntry(
            entry,
            defaultKind: defaultKind,
          ),
        )
        .toList();
  }
}
