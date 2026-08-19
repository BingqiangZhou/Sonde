import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/constants/cache_constants.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:sonde/features/podcast/data/services/itunes_search_service.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';

import '../../../../helpers/mock_local_storage_service.dart';

void main() {
  group('podcastDiscoverProvider', () {
    test('loads the whole chart in one request', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final state = container.read(podcastDiscoverProvider);

      expect(state.topShows, hasLength(100));
      expect(state.topEpisodes, hasLength(100));
      expect(state.selectedCategory, PodcastDiscoverState.allCategoryValue);
      // One fetch per chart, already at the maximum limit — no hydration
        // pagination round trips anymore.
      expect(fakeService.showsLimits, equals([CacheConstants.discoverTopChartMaxLimit]));
      expect(fakeService.episodeLimits, equals([CacheConstants.discoverTopChartMaxLimit]));
    });

    test('derives category shelves from the top-shows chart', () async {
      final container = _createContainer(_FakeApplePodcastRssService());
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final state = container.read(podcastDiscoverProvider);

      // The fake alternates Technology/News 50:50, so both earn a shelf;
      // the alphabetical tie-break puts News first.
      expect(state.categoryShelves, hasLength(2));
      final shelf = state.categoryShelves.first;
      expect(shelf.category, 'News');
      expect(shelf.items, hasLength(CacheConstants.discoverShelfItemCount));
      expect(shelf.items.every((item) => item.hasGenre('News')), isTrue);
    });

    test('category filtering applies to both charts', () async {
      final container = _createContainer(_FakeApplePodcastRssService());
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final notifier = container.read(podcastDiscoverProvider.notifier);
      notifier.selectCategory('News');
      final state = container.read(podcastDiscoverProvider);

      expect(state.selectedCategory, 'News');
      expect(state.filteredShows.every((item) => item.hasGenre('News')), isTrue);
      expect(
        state.filteredEpisodes.every((item) => item.hasGenre('News')),
        isTrue,
      );
      expect(state.filteredShows, isNotEmpty);
    });

    test('hydrates feed urls and episode meta after loading', () async {
      final fakeItunes = _FakeITunesHydrationService();
      final container = _createContainer(
        _FakeApplePodcastRssService(),
        itunesService: fakeItunes,
      );
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(podcastDiscoverProvider);
      expect(fakeItunes.hydrationCalls, 1);
      expect(state.showFeedUrls[1000], 'https://example.com/feed-1000.xml');
      expect(
        state.episodeMeta[1000]?.trackTimeMillis,
        1800000,
      );
    });

    test('registerShowFeedUrl merges into the hydrated map', () async {
      final container = _createContainer(_FakeApplePodcastRssService());
      addTearDown(container.dispose);

      final notifier = container.read(podcastDiscoverProvider.notifier);
      notifier.registerShowFeedUrl(42, 'https://example.com/feed-42.xml');

      expect(
        container.read(podcastDiscoverProvider).showFeedUrls[42],
        'https://example.com/feed-42.xml',
      );
    });

    test('reloads on country change', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final initialCalls = fakeService.showsCalls;

      await container
          .read(podcastDiscoverProvider.notifier)
          .onCountryChanged(PodcastCountry.japan);

      final state = container.read(podcastDiscoverProvider);
      expect(state.country, PodcastCountry.japan);
      expect(state.topShows, hasLength(100));
      expect(fakeService.showsCalls, greaterThan(initialCalls));
    });

    test('uses latest country when a load is already in flight', () async {
      final fakeService = _DelayedApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      final notifier = container.read(podcastDiscoverProvider.notifier);
      final initialLoad = notifier.loadInitialData();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final changeLoad = notifier.onCountryChanged(PodcastCountry.usa);
      await Future.wait([initialLoad, changeLoad]);

      final state = container.read(podcastDiscoverProvider);
      expect(state.country, PodcastCountry.usa);
      expect(state.topShows.first.url, contains('/us/'));
      expect(state.topEpisodes.first.url, contains('/us/'));
    });

    test('skips repeated load when discover data is fresh', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final showsCallsAfterFirstLoad = fakeService.showsCalls;
      final episodesCallsAfterFirstLoad = fakeService.episodeCalls;

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();

      expect(fakeService.showsCalls, showsCallsAfterFirstLoad);
      expect(fakeService.episodeCalls, episodesCallsAfterFirstLoad);
    });

    test('loads both shows and episodes in parallel', () async {
      final fakeService = _DelayedApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      // During loading, state should still be loading (no partial data)
      final future = container
          .read(podcastDiscoverProvider.notifier)
          .loadInitialData();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final midState = container.read(podcastDiscoverProvider);
      // Both are loaded atomically via parallel fetch, so during loading
      // the state has not yet been updated with results.
      expect(midState.isLoading, isTrue);

      await future;

      final finalState = container.read(podcastDiscoverProvider);
      expect(finalState.topEpisodes, isNotEmpty);
      expect(finalState.topShows, isNotEmpty);
      expect(finalState.isLoading, isFalse);
    });

    test(
      'clearRuntimeCache clears discover state and triggers refetch',
      () async {
        final fakeService = _FakeApplePodcastRssService();
        final container = _createContainer(fakeService);
        addTearDown(container.dispose);

        await container
            .read(podcastDiscoverProvider.notifier)
            .loadInitialData();
        final callsBeforeClear = fakeService.showsCalls;

        container.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
        final clearedState = container.read(podcastDiscoverProvider);
        expect(clearedState.topShows, isEmpty);
        expect(clearedState.topEpisodes, isEmpty);
        expect(clearedState.showFeedUrls, isEmpty);
        expect(fakeService.clearCacheCalls, 1);

        await container
            .read(podcastDiscoverProvider.notifier)
            .loadInitialData();
        expect(fakeService.showsCalls, greaterThan(callsBeforeClear));
      },
    );
  });
}

ProviderContainer _createContainer(
  ApplePodcastRssService service, {
  ITunesSearchService? itunesService,
}) {
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
      applePodcastRssServiceProvider.overrideWithValue(service),
      iTunesSearchServiceProvider.overrideWithValue(
        itunesService ?? _FakeITunesHydrationService(),
      ),
    ],
  );
}

class _FakeApplePodcastRssService extends ApplePodcastRssService {
  _FakeApplePodcastRssService() : super();

  int showsCalls = 0;
  int episodeCalls = 0;
  int clearCacheCalls = 0;
  final List<int> showsLimits = [];
  final List<int> episodeLimits = [];

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    showsCalls += 1;
    showsLimits.add(limit);
    return _responseFor(kind: 'podcasts', country: country.code, count: limit);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    episodeCalls += 1;
    episodeLimits.add(limit);
    return _responseFor(
      kind: 'podcast-episodes',
      country: country.code,
      count: limit,
    );
  }

  @override
  void clearCache() {
    clearCacheCalls += 1;
    super.clearCache();
  }

  ApplePodcastChartResponse _responseFor({
    required String kind,
    required String country,
    required int count,
  }) {
    final items = List.generate(
      count,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${1000 + index}',
        'name': 'Item $index',
        'kind': kind,
        'artworkUrl100': 'https://example.com/$index.png',
        'genres': [
          {'name': index.isEven ? 'Technology' : 'News'},
        ],
        'url': 'https://podcasts.apple.com/$country/podcast/id${1000 + index}',
      }),
    );

    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed(
        title: kind,
        country: country,
        updated: '2026-02-14T00:00:00Z',
        results: items,
      ),
    );
  }
}

class _DelayedApplePodcastRssService extends _FakeApplePodcastRssService {
  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    showsCalls += 1;
    showsLimits.add(limit);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _responseFor(kind: 'podcasts', country: country.code, count: limit);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    episodeCalls += 1;
    episodeLimits.add(limit);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _responseFor(
      kind: 'podcast-episodes',
      country: country.code,
      count: limit,
    );
  }
}

/// Hydration double: returns a feed url + duration for the first show /
/// episode id it is asked about.
class _FakeITunesHydrationService extends ITunesSearchService {
  int hydrationCalls = 0;

  @override
  Future<ITunesChartHydrationResult> lookupChartEntities({
    required List<int> ids,
    PodcastCountry country = PodcastCountry.china,
  }) async {
    hydrationCalls += 1;
    final showFeedUrls = <int, String>{};
    final episodeMeta = <int, ITunesPodcastEpisodeResult>{};
    for (final id in ids) {
      showFeedUrls[id] = 'https://example.com/feed-$id.xml';
      episodeMeta[id] = ITunesPodcastEpisodeResult(
        trackId: id,
        collectionId: id,
        trackName: 'Episode $id',
        collectionName: 'Show $id',
        feedUrl: 'https://example.com/feed-$id.xml',
        releaseDate: DateTime(2026, 2, 14),
        trackTimeMillis: 1800000,
      );
    }
    return ITunesChartHydrationResult(
      showFeedUrls: showFeedUrls,
      episodeMeta: episodeMeta,
    );
  }
}
