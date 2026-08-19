import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';

void main() {
  // ── PodcastDiscoverState ────────────────────────────────────────

  group('PodcastDiscoverState', () {
    PodcastDiscoverState defaultState() {
      return const PodcastDiscoverState(country: PodcastCountry.usa);
    }

    // -- Default values --

    group('default values', () {
      test('has expected defaults', () {
        final state = defaultState();
        expect(state.country, PodcastCountry.usa);
        expect(state.isLoading, isFalse);
        expect(state.isRefreshing, isFalse);
        expect(state.error, isNull);
        expect(state.selectedCategory, PodcastDiscoverState.allCategoryValue);
        expect(state.topShows, isEmpty);
        expect(state.topEpisodes, isEmpty);
        expect(state.showFeedUrls, isEmpty);
        expect(state.episodeMeta, isEmpty);
        expect(state.lastRefreshTime, isNull);
        expect(state.hasData, isFalse);
      });
    });

    // -- copyWith --

    group('copyWith', () {
      test('updates individual fields', () {
        final base = defaultState();
        final updated = base.copyWith(isLoading: true, error: 'oops');
        expect(updated.isLoading, isTrue);
        expect(updated.error, 'oops');
        expect(updated.country, PodcastCountry.usa);
      });

      test('preserves fields not specified', () {
        final base = defaultState().copyWith(isLoading: true, error: 'err');
        final updated = base.copyWith(isLoading: false, clearError: true);
        expect(updated.isLoading, isFalse);
        expect(updated.error, isNull);
      });

      test('clearError sets error to null', () {
        final withError = defaultState().copyWith(error: 'network failure');
        expect(withError.error, 'network failure');

        final cleared = withError.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });

      test('clearError with explicit error still clears', () {
        final state = defaultState().copyWith(
          error: 'original',
          clearError: true,
        );
        expect(state.error, isNull);
      });

      test('does not clear error when clearError is false', () {
        final state = defaultState().copyWith(error: 'kept');
        final updated = state.copyWith(isLoading: true);
        expect(updated.error, 'kept');
      });
    });

    // -- isDataFresh --

    group('isDataFresh', () {
      test('returns false when no lastRefreshTime', () {
        final state = defaultState();
        expect(state.isDataFresh(), isFalse);
      });

      test('returns true when within cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 3)),
        );
        expect(state.isDataFresh(), isTrue);
      });

      test('returns false when past cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 10)),
        );
        expect(state.isDataFresh(), isFalse);
      });

      test('respects custom cache duration', () {
        final state = defaultState().copyWith(
          lastRefreshTime: DateTime.now().subtract(const Duration(minutes: 3)),
        );
        expect(
          state.isDataFresh(cacheDuration: const Duration(minutes: 2)),
          isFalse,
        );
        expect(
          state.isDataFresh(),
          isTrue,
        );
      });
    });

    // -- hasData / previews --

    group('hasData and previews', () {
      test('hasData reflects either chart', () {
        expect(
          defaultState().copyWith(topShows: [_makeItem(id: '1')]).hasData,
          isTrue,
        );
        expect(
          defaultState().copyWith(topEpisodes: [_makeItem(id: '2')]).hasData,
          isTrue,
        );
      });

      test('previews cap at the shelf item count', () {
        final items = List.generate(20, (i) => _makeItem(id: '$i'));
        final state = defaultState().copyWith(topShows: items);
        expect(state.topShowsPreview, hasLength(5));
        expect(state.topShowsPreview.first, items.first);
        expect(state.topShows, hasLength(20));
      });
    });

    // -- categories --

    group('categories', () {
      test('returns empty list when no chart items', () {
        final state = defaultState();
        expect(state.categories, isEmpty);
      });

      test('extracts genres from both charts and sorts by count descending',
          () {
        final state = defaultState().copyWith(
          topShows: [
            _makeItem(id: '1', genres: ['Technology', 'News']),
            _makeItem(id: '2', genres: ['News']),
            _makeItem(id: '3', genres: ['Technology']),
          ],
          topEpisodes: [
            _makeItem(id: '4', genres: ['Technology', 'Comedy']),
          ],
        );

        final cats = state.categories;
        // Technology: 3, News: 2, Comedy: 1 — episodes contribute too.
        expect(cats, ['Technology', 'News', 'Comedy']);
      });

      test('breaks ties alphabetically (case-insensitive)', () {
        final items = [
          _makeItem(id: '1', genres: ['banana']),
          _makeItem(id: '2', genres: ['Apple']),
        ];
        final state = defaultState().copyWith(topShows: items);

        final cats = state.categories;
        // Both have count 1. Tie broken alphabetically case-insensitive.
        // "Apple" (a) < "banana" (b).
        expect(cats, ['Apple', 'banana']);
      });

      test('trims genre names and skips empty ones', () {
        final items = [
          _makeItem(id: '1', genres: ['  Tech  ', '  ', '']),
          _makeItem(id: '2', genres: ['Tech']),
        ];
        final state = defaultState().copyWith(topShows: items);

        final cats = state.categories;
        expect(cats, ['Tech']);
      });
    });

    // -- filtered shows / episodes --

    group('filteredShows and filteredEpisodes', () {
      final shows = [
        _makeItem(id: '1', genres: ['Technology']),
        _makeItem(id: '2', genres: ['News']),
        _makeItem(id: '3', genres: ['Technology', 'Comedy']),
      ];
      final episodes = [
        _makeItem(id: '4', genres: ['Technology']),
        _makeItem(id: '5', genres: ['News']),
      ];

      test('returns all items when selectedCategory is allCategoryValue', () {
        final state = defaultState().copyWith(
          selectedCategory: PodcastDiscoverState.allCategoryValue,
          topShows: shows,
          topEpisodes: episodes,
        );
        expect(state.filteredShows, hasLength(3));
        expect(state.filteredEpisodes, hasLength(2));
      });

      test('filters both charts by selectedCategory', () {
        final state = defaultState().copyWith(
          selectedCategory: 'Technology',
          topShows: shows,
          topEpisodes: episodes,
        );
        expect(state.filteredShows, hasLength(2));
        expect(state.filteredShows.every((i) => i.hasGenre('Technology')), isTrue);
        expect(state.filteredEpisodes, hasLength(1));
      });

      test('returns empty when no items match category', () {
        final state = defaultState().copyWith(
          selectedCategory: 'Sports',
          topShows: shows,
          topEpisodes: episodes,
        );
        expect(state.filteredShows, isEmpty);
        expect(state.filteredEpisodes, isEmpty);
      });
    });

    // -- Equality --

    group('equality', () {
      test('equal when all fields match', () {
        final now = DateTime(2026, 1, 15, 10, 30);
        final a = PodcastDiscoverState(
          country: PodcastCountry.usa,
          isLoading: true,
          error: 'err',
          selectedCategory: 'Tech',
          topShows: [_makeItem(id: '1')],
          topEpisodes: [_makeItem(id: '2')],
          showFeedUrls: const {1: 'https://example.com/feed.xml'},
          lastRefreshTime: now,
        );
        final b = PodcastDiscoverState(
          country: PodcastCountry.usa,
          isLoading: true,
          error: 'err',
          selectedCategory: 'Tech',
          topShows: [_makeItem(id: '1')],
          topEpisodes: [_makeItem(id: '2')],
          showFeedUrls: const {1: 'https://example.com/feed.xml'},
          lastRefreshTime: now,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when any field differs', () {
        final a = defaultState();
        final b = a.copyWith(isLoading: true);
        expect(a, isNot(equals(b)));
      });
    });

    // -- allCategoryValue constant --

    group('allCategoryValue', () {
      test('is a sentinel value distinct from real categories', () {
        expect(PodcastDiscoverState.allCategoryValue, isNot(equals('News')));
      });
    });
  });
}

PodcastDiscoverItem _makeItem({
  required String id,
  List<String> genres = const [],
}) {
  return PodcastDiscoverItem(
    itemId: id,
    itunesId: int.tryParse(id),
    title: 'Item $id',
    artist: 'Artist $id',
    artworkUrl: null,
    url: 'https://podcasts.apple.com/us/podcast/id$id',
    genres: genres,
    kind: PodcastDiscoverKind.podcasts,
  );
}
