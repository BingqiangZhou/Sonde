import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_state_models.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    show applePodcastRssServiceProvider;
import 'package:sonde/features/podcast/presentation/widgets/country_selector_dropdown.dart';

import '../../../../helpers/mock_audio_player_notifier.dart';
import '../../../../helpers/mock_local_storage_service.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

// ---------------------------------------------------------------------------
// Tests merged from:
//   - podcast_list_page_discover_actions_test.dart
//   - podcast_list_page_discover_search_sections_test.dart
//   - podcast_list_page_header_discover_test.dart
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // Discover actions  (origin: discover_actions_test.dart)
  // =========================================================================
  group('PodcastListPage discover actions', () {
    testWidgets('show subscribe button uses lookup and subscribes', (
      tester,
    ) async {
      final fakeLookupService = FakeITunesSearchService();
      final fakeSubscriptionNotifier = FakePodcastSubscriptionNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              SingleItemFakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              fakeLookupService,
            ),
            podcastSubscriptionProvider.overrideWith(
              () => fakeSubscriptionNotifier,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The single show renders on the top-shows shelf by default.
      await tester.tap(find.byKey(const Key('podcast_discover_subscribe_111')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(fakeLookupService.lookupCalled, isTrue);
      expect(
        fakeSubscriptionNotifier.lastAddedFeedUrl,
        'https://example.com/feed.xml',
      );
    });

    testWidgets(
      'podcast row opens episodes info sheet and has no open button',
      (tester) async {
        final fakeLookupService = FakeITunesSearchService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                MockLocalStorageService(),
              ),
              applePodcastRssServiceProvider.overrideWithValue(
                SingleItemFakeApplePodcastRssService(),
              ),
              search.iTunesSearchServiceProvider.overrideWithValue(
                fakeLookupService,
              ),
              podcastSubscriptionProvider.overrideWith(
                FakePodcastSubscriptionNotifier.new,
              ),
              search.podcastSearchProvider.overrideWith(
                () => PassthroughPodcastSearchNotifier(
                    const search.PodcastSearchState()),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_discover_open_111')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('podcast_discover_chart_row_111')),
        );
        await tester.pumpAndSettle();

        expect(fakeLookupService.lookupEpisodesCalled, isTrue);
        expect(
          find.byKey(const Key('discover_show_episodes_sheet')),
          findsOneWidget,
        );
        expect(find.text('Show Episode Preview'), findsOneWidget);
      },
    );

    testWidgets('episodes support detail sheet and internal play button', (
      tester,
    ) async {
      final audioNotifier = MockAudioPlayerNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              SingleItemFakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              FakeITunesSearchService(),
            ),
            podcastSubscriptionProvider.overrideWith(
              FakePodcastSubscriptionNotifier.new,
            ),
            audioPlayerProvider.overrideWith(() => audioNotifier),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The trending-episodes shelf renders alongside the shows shelf.
      expect(find.byKey(const Key('podcast_discover_open_222')), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_play_222')),
        findsOneWidget,
      );

      final episodeRow = find.byKey(const Key('podcast_discover_chart_row_222'));
      await tester.ensureVisible(episodeRow);
      await tester.pumpAndSettle();
      await tester.tap(episodeRow);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('discover_episode_detail_sheet')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('discover_episode_detail_play_button')),
      );
      await tester.pumpAndSettle();

      final played = audioNotifier.lastPlayedEpisode;
      expect(played, isNotNull);
      expect(played!.id, 222);
      expect(played.metadata?['discover_preview'], isTrue);
    });
  });

  // =========================================================================
  // Discover search sections  (origin: discover_search_sections_test.dart)
  // =========================================================================
  group('PodcastListPage discover search mode selector', () {
    testWidgets('shows selector and renders podcast results in podcast mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
              const search.PodcastSearchState(
                hasSearched: true,
                searchMode: search.PodcastSearchMode.podcasts,
                podcastResults: [
                  PodcastSearchResult(
                    collectionId: 100,
                    collectionName: 'Test Podcast',
                    artistName: 'Tester',
                    feedUrl: 'https://example.com/feed.xml',
                    artworkUrl100: 'https://example.com/podcast.png',
                    trackCount: 10,
                    primaryGenreName: 'Tech',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsNothing);
    });

    testWidgets('shows selector and renders episode results in episode mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
              search.PodcastSearchState(
                hasSearched: true,
                episodeResults: [
                  ITunesPodcastEpisodeResult(
                    trackId: 200,
                    collectionId: 100,
                    trackName: 'Episode 1',
                    collectionName: 'Test Podcast',
                    feedUrl: 'https://example.com/feed.xml',
                    previewUrl: 'https://example.com/ep.mp3',
                    releaseDate: DateTime(2026, 2, 14),
                    trackTimeMillis: 1200000,
                    artworkUrl100: 'https://example.com/ep.png',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsNothing,
      );
    });
  });

  // =========================================================================
  // Discover header  (origin: header_discover_test.dart)
  // =========================================================================
  group('PodcastListPage discover header', () {
    testWidgets('renders discover structure and sections', (tester) async {
      // A tall mobile viewport keeps every shelf header inside the lazy
      // sliver viewport so the structural assertions can find them.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [createTestSubscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          search.podcastSearchProvider.overrideWith(
            () => InteractivePodcastSearchNotifier(
                const search.PodcastSearchState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Start with a search'), findsNothing);
      expect(find.text('Refine query'), findsNothing);
      expect(find.text('Update query or switch modes.'), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_country_button')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('podcast_discover_country_button')),
          matching: find.text('CN'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('podcast_discover_country_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CountrySelectorDropdown), findsOneWidget);
      Navigator.of(tester.element(find.byType(CountrySelectorDropdown))).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('podcast_discover_search_bar')),
        findsOneWidget,
      );
      expect(find.byType(HeroHeader), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_search_input')),
        findsOneWidget,
      );
      final searchInputWidget = tester.widget<TextField>(
        find.byKey(const Key('podcast_discover_search_input')),
      );
      final decoration = searchInputWidget.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      // The magazine shelves: spotlight first, then top shows (with the
      // country pill and see-all), trending episodes, and category
      // shelves sliced from the chart genres.
      expect(
        find.byKey(const Key('podcast_discover_spotlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_spotlight_carousel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_spotlight_dots')),
        findsOneWidget,
      );
      // PageView builds lazily, so only the first spotlight card exists.
      expect(
        find.byKey(const Key('podcast_discover_spotlight_card_1000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_top_shows_header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_see_all_shows')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_see_all_episodes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsOneWidget,
      );
      // Category shelves appear below the ranked shelves; the fake chart
      // alternates Technology/News so both earn a shelf. The chips row
      // itself lives on the full charts page now.
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsNothing,
      );

      expect(find.byKey(const Key('podcast_list_header_title')), findsNothing);
      expect(
        find.byKey(const Key('podcast_list_discover_title')),
        findsNothing,
      );
    });

    testWidgets('search clear button follows controller text changes', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [createTestSubscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          search.podcastSearchProvider.overrideWith(
            () => InteractivePodcastSearchNotifier(
                const search.PodcastSearchState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const Key('podcast_discover_search_input'),
      );
      final clearButton = find.descendant(
        of: find.byKey(const Key('podcast_discover_search_bar')),
        matching: find.byIcon(Icons.clear),
      );

      expect(clearButton, findsNothing);

      await tester.enterText(searchInput, 'flutter');
      await tester.pump();

      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump();

      final textField = tester.widget<TextField>(searchInput);
      expect(textField.controller?.text, isEmpty);
      expect(clearButton, findsNothing);
    });
  });

  // =========================================================================
  // Discover browse redesign (spotlight + shelves + search states)
  // =========================================================================
  group('PodcastListPage discover browse redesign', () {
    testWidgets('spotlight card tap opens the show episodes sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeLookupService = FakeITunesSearchService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            fakeLookupService,
          ),
          podcastSubscriptionProvider.overrideWith(
            FakePodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
              const search.PodcastSearchState(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(
        const Key('podcast_discover_spotlight_card_1000'),
      );
      expect(cardFinder, findsOneWidget);

      // Tap the title area: the card center overlaps the subscribe CTA.
      final cardTopLeft = tester.getTopLeft(cardFinder);
      await tester.tapAt(cardTopLeft + const Offset(180, 30));
      // Bounded pumps: cached-image retries under the sheet keep scheduling
      // frames, which would make pumpAndSettle time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeLookupService.lookupEpisodesCalled, isTrue);
      expect(
        find.byKey(const Key('discover_show_episodes_sheet')),
        findsOneWidget,
      );
    });

    testWidgets('search empty state offers clear and returns to browse', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => InteractivePodcastSearchNotifier(
              const search.PodcastSearchState(
                hasSearched: true,
                currentQuery: 'nothing',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastListPage)),
      )!;
      expect(find.text(l10n.podcast_search_no_results), findsOneWidget);
      expect(find.text(l10n.podcast_search_empty_hint), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsNothing,
      );

      final clearButton = find.widgetWithText(FilledButton, l10n.clear);
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text(l10n.podcast_search_no_results), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsOneWidget,
      );
    });

    testWidgets('search error state retry clears the error', (tester) async {
      final retryNotifier = RetrySpySearchNotifier(
        const search.PodcastSearchState(
          hasSearched: true,
          currentQuery: 'kaboom',
          error: 'boom',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(
            FakeITunesSearchService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(() => retryNotifier),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastListPage)),
      )!;
      expect(find.text('boom'), findsOneWidget);

      final retryButton = find.widgetWithText(FilledButton, l10n.retry);
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retryNotifier.retryCalled, isTrue);
      expect(find.text('boom'), findsNothing);
    });
  });
}

/// Search notifier double that tracks [PodcastSearchNotifier.retrySearch]
/// without touching the real iTunes service.
class RetrySpySearchNotifier extends search.PodcastSearchNotifier {
  RetrySpySearchNotifier(this._initialState);

  final search.PodcastSearchState _initialState;
  bool retryCalled = false;

  @override
  search.PodcastSearchState build() => _initialState;

  @override
  Future<void> retrySearch() async {
    retryCalled = true;
    state = state.copyWith();
  }
}
