import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/features/podcast/presentation/pages/podcast_charts_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart'
    show applePodcastRssServiceProvider;

import '../../../../helpers/mock_local_storage_service.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer createContainer() {
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
            const search.PodcastSearchState(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    ProviderContainer container, {
    ThemeMode themeMode = ThemeMode.system,
    PodcastChartsSection section = PodcastChartsSection.shows,
  }) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: themeMode,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PodcastChartsPage(section: section),
        ),
      ),
    );
  }

  group('PodcastChartsPage', () {
    testWidgets('shows section renders the shows chart under the chips', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = createContainer();
      await pumpPage(
        tester,
        container,
        section: PodcastChartsSection.shows,
      );
      await tester.pumpAndSettle();

      final chipsTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_category_chips')))
          .dy;
      // The list sliver itself is not a RenderBox; measure its first row.
      final firstShowTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_chart_row_1000')))
          .dy;
      expect(chipsTop, lessThan(firstShowTop));

      expect(
        find.byKey(const Key('podcast_discover_category_chip_all')),
        findsOneWidget,
      );
      // Only the requested chart renders — the episodes list stays out.
      expect(
        find.byKey(const Key('podcast_charts_shows_list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_charts_episodes_list')),
        findsNothing,
      );
      expect(find.byKey(const Key('podcast_charts_back')), findsOneWidget);
    });

    testWidgets('episodes section renders the episodes chart only', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = createContainer();
      await pumpPage(
        tester,
        container,
        section: PodcastChartsSection.episodes,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_charts_episodes_list')),
        findsOneWidget,
      );
      // Fake shows start at 1000, episodes at 2000.
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsNothing,
      );
    });

    testWidgets('category chip filters the ranked rows', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = createContainer();
      await pumpPage(tester, container);
      await tester.pumpAndSettle();

      // Odd fake ids are News shows, even ones Technology.
      await tester.tap(
        find.byKey(const Key('podcast_discover_category_chip_news')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_1001')),
        findsOneWidget,
      );
    });

    testWidgets(
      'category with no matches shows empty state and see-all resets',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = createContainer();
        await pumpPage(tester, container);
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(PodcastChartsPage)),
        )!;

        container
            .read(search.podcastDiscoverProvider.notifier)
            .selectCategory('Nonexistent');
        await tester.pumpAndSettle();

        expect(find.text(l10n.podcast_discover_category_empty_title),
            findsOneWidget);
        expect(
          find.byKey(const Key('podcast_discover_chart_row_1000')),
          findsNothing,
        );

        final showAllButton = find.text(l10n.podcast_discover_see_all);
        await tester.ensureVisible(showAllButton);
        await tester.pumpAndSettle();
        await tester.tap(showAllButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.podcast_discover_category_empty_title),
          findsNothing,
        );
        expect(
          find.byKey(const Key('podcast_discover_chart_row_1000')),
          findsOneWidget,
        );
      },
    );

    testWidgets('scrolls to the 100th ranked row with tabular rank numerals',
        (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = createContainer();
      await pumpPage(tester, container);
      await tester.pumpAndSettle();

      // Short flings, stopping as soon as the 100th show scrolls into the
      // cache extent — a long ballistic fling would overshoot past it into
      // the episodes section.
      final rank100Finder = find.byKey(
        const Key('podcast_discover_chart_row_1099'),
      );
      final scrollFinder = find.byKey(const Key('podcast_charts_scroll'));
      var found = false;
      for (var index = 0; index < 16 && !found; index++) {
        await tester.fling(scrollFinder, const Offset(0, -700), 800);
        await tester.pumpAndSettle();
        found = rank100Finder.evaluate().isNotEmpty;
      }
      expect(found, isTrue);

      final rankTextFinder = find.byKey(
        const Key('podcast_discover_chart_rank_text_1099'),
      );
      expect(rankTextFinder, findsOneWidget);
      expect(tester.widget<Text>(rankTextFinder).data, equals('100'));

      final rankParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: rankTextFinder, matching: find.byType(RichText)),
      );
      expect(rankParagraph.didExceedMaxLines, isFalse);
    });

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets(
        'selected chip uses the theme primary in ${mode.name} mode',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = createContainer();
          await pumpPage(tester, container, themeMode: mode);
          await tester.pumpAndSettle();

          final allChipFinder = find.byKey(
            const Key('podcast_discover_category_chip_all'),
          );
          expect(allChipFinder, findsOneWidget);
          final allChip = tester.widget<ChoiceChip>(allChipFinder);
          final context = tester.element(allChipFinder);
          final scheme = Theme.of(context).colorScheme;

          expect(allChip.selected, isTrue);
          expect(allChip.selectedColor, equals(scheme.primary));
        },
      );
    }
  });
}
