import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/podcast_state_models.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    show applePodcastRssServiceProvider;
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';

import '../../../../helpers/mock_local_storage_service.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

// ---------------------------------------------------------------------------
// Tests merged from:
//   - podcast_list_page_desktop_list_layout_test.dart
//   - podcast_list_page_mobile_card_layout_test.dart
//   - podcast_list_page_layout_stable_dense_test.dart
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Desktop discover layout  (origin: desktop_list_layout_test.dart)
  // =========================================================================
  group('PodcastListPage desktop discover layout', () {
    testWidgets('renders the shelves as grids side by side', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Every shelf widens into a two-column grid on desktop; the top
      // shows and trending episodes sections render side by side in one
      // scroll view.
      expect(
        find.byKey(const Key('podcast_discover_top_shows_grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_top_episodes_grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );
      // The category chips live on the full charts page now.
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsNothing,
      );
    });

    testWidgets(
      'uses desktop hero spacing and keeps country pill inset from the right edge',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        final heroRect = tester.getRect(find.byType(HeroHeader));
        final searchBarRect = tester.getRect(
          find.byKey(const Key('podcast_discover_search_bar')),
        );
        final mastheadRect = tester.getRect(
          find.byKey(const Key('podcast_discover_masthead')),
        );
        final shelfHeaderRect = tester.getRect(
          find.byKey(const Key('podcast_discover_top_shows_header')),
        );
        final countryPillRect = tester.getRect(
          find.byKey(const Key('podcast_discover_country_button')),
        );

        final heroSpacing = searchBarRect.top - heroRect.bottom;
        expect(heroSpacing, greaterThanOrEqualTo(8));
        expect(heroSpacing, lessThanOrEqualTo(24));
        // The country selector sits on the "Global charts" masthead row —
        // above the shelves and inset from the viewport's right edge.
        expect(countryPillRect.top, lessThan(shelfHeaderRect.top));
        expect(countryPillRect.top, greaterThanOrEqualTo(mastheadRect.top));
        expect(countryPillRect.right, lessThan(mastheadRect.right));
      },
    );
  });

  // =========================================================================
  // Mobile discover list  (origin: mobile_card_layout_test.dart)
  // =========================================================================
  group('PodcastListPage mobile discover list', () {
    testWidgets('scrolls the masthead and the ranked shelves in one view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final scrollFinder = find.byKey(const Key('podcast_discover_scroll'));
      final showsHeaderFinder = find.byKey(
        const Key('podcast_discover_top_shows_header'),
      );
      final thirdRowFinder = find.byKey(
        const Key('podcast_discover_chart_row_1002'),
      );
      final rowFinder = find.byKey(
        const Key('podcast_discover_chart_row_1000'),
      );
      final scrollableFinder = find
          .descendant(
            of: scrollFinder,
            matching: find.byType(Scrollable),
          )
          .first;

      final showsHeaderTopBefore = tester.getTopLeft(showsHeaderFinder).dy;
      final thirdRowTopBefore = tester.getTopLeft(thirdRowFinder).dy;
      final scrollPositionBefore =
          tester.state<ScrollableState>(scrollableFinder).position.pixels;

      // A plain drag (no ballistic fling) keeps the measured sections within
      // the viewport.
      await tester.drag(scrollFinder, const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(scrollableFinder).position.pixels,
        greaterThan(scrollPositionBefore),
      );
      expect(
        tester.getTopLeft(showsHeaderFinder).dy,
        lessThan(showsHeaderTopBefore),
      );
      expect(
        tester.getTopLeft(thirdRowFinder).dy,
        lessThan(thirdRowTopBefore),
      );
      expect(rowFinder, findsOneWidget);
    });
  });

  // =========================================================================
  // Layout stable / dense  (origin: layout_stable_dense_test.dart)
  // =========================================================================
  group('PodcastListPage layout stable dense', () {
    testWidgets('Discover layout stays dense when subscriptions update', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
            DelayedSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
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

      await tester.pump();
      final tabSelector = find.byKey(const Key('podcast_discover_tab_selector'));
      final searchBar = find.byKey(const Key('podcast_discover_search_bar'));
      expect(tabSelector, findsOneWidget);
      expect(searchBar, findsOneWidget);
      final initialTabHeight = tester.getSize(tabSelector).height;
      final initialSearchHeight = tester.getSize(searchBar).height;
      expect(initialTabHeight, lessThanOrEqualTo(40));
      expect(initialSearchHeight, lessThanOrEqualTo(44));

      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getSize(tabSelector).height, initialTabHeight);
      expect(tester.getSize(searchBar).height, initialSearchHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Discover uses shared shell and backdrop on short screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
            DelayedSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
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

      expect(find.byType(HeroHeader), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_country_button')),
        findsOneWidget,
      );
      final viewportClip = tester.widget<ClipRRect>(
        find.byKey(const Key('content_shell_viewport_clip')),
      );
      expect(viewportClip.borderRadius, BorderRadius.circular(16));
    });

    testWidgets(
      'Discover uses profile-style mobile spacing below the hero card',
      (tester) async {
        tester.view.physicalSize = const Size(390, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
              DelayedSubscriptionNotifier.new,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
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

        final heroRect = tester.getRect(find.byType(HeroHeader));
        final searchBarRect = tester.getRect(
          find.byKey(const Key('podcast_discover_search_bar')),
        );

        final spacing = searchBarRect.top - heroRect.bottom;
        expect(spacing, greaterThanOrEqualTo(8));
        expect(spacing, lessThanOrEqualTo(24));
      },
    );

    testWidgets('uses dense layout when subscription total is at least 20', (
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
                total: 25,
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
            () => PassthroughPodcastSearchNotifier(
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

      final rowFinder = find.byKey(
        const Key('podcast_discover_chart_row_1000'),
      );
      expect(rowFinder, findsOneWidget);

      final imageWidget = tester.widget<PodcastImageWidget>(
        find
            .descendant(
              of: rowFinder,
              matching: find.byType(PodcastImageWidget),
            )
            .first,
      );
      expect(imageWidget.width, 48.0);
    });
  });
}
