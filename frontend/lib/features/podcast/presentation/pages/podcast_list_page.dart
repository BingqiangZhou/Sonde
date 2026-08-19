import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/scroll_constants.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/utils/debounce.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/adaptive_sheet_helper.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/pages/sections/discover_interaction_handler.dart';
import 'package:sonde/features/podcast/presentation/pages/sections/search_mode_toggle.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:sonde/features/podcast/presentation/widgets/country_selector_dropdown.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_charts_list.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_search_input.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_spotlight_section.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_top_charts_section.dart';
import 'package:sonde/features/podcast/presentation/widgets/search/podcast_search_results_list.dart';
import 'package:sonde/shared/widgets/skeleton_widgets.dart';

/// Discover page: search plus an editorial browse view with a spotlight
/// carousel of the top-ranked chart items and the numbered charts list,
/// all scrolling in a single view.
class PodcastListPage extends ConsumerStatefulWidget {
  const PodcastListPage({super.key});

  @override
  ConsumerState<PodcastListPage> createState() => _PodcastListPageState();
}

class _PodcastListPageState extends ConsumerState<PodcastListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _discoverListScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<int> _subscribingShowIds = <int>{};
  final Set<int> _subscribedShowIds = <int>{};
  DebounceTimer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _discoverListScrollController.addListener(_onDiscoverListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialData());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.dispose();
    _discoverListScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      await ref.read(podcastSubscriptionProvider.notifier).loadSubscriptions();
      await ref.read(podcastDiscoverProvider.notifier).loadInitialData();
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.error,
          isError: true,
        );
      }
    }
  }

  void _handleDiscoverTabSelected(PodcastSearchMode mode) {
    ref.read(podcastSearchProvider.notifier).setSearchMode(mode);
    ref.read(podcastDiscoverProvider.notifier).setTab(
          mode == PodcastSearchMode.podcasts
              ? PodcastDiscoverTab.podcasts
              : PodcastDiscoverTab.episodes,
        );
    _resetDiscoverListScroll();
  }

  void _handleDiscoverCategorySelected(String category) {
    ref.read(podcastDiscoverProvider.notifier).selectCategory(category);
    _resetDiscoverListScroll();
  }

  void _resetDiscoverCategoryFilter() {
    ref
        .read(podcastDiscoverProvider.notifier)
        .selectCategory(PodcastDiscoverState.allCategoryValue);
    _resetDiscoverListScroll();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebounce?.cancel();
      ref.read(podcastSearchProvider.notifier).clearSearch();
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = DebounceTimer(
      AppDurations.debounceMedium,
      () {
        final notifier = ref.read(podcastSearchProvider.notifier);
        final mode = ref.read(podcastSearchProvider).searchMode;
        mode == PodcastSearchMode.episodes
            ? notifier.searchEpisodes(query)
            : notifier.searchPodcasts(query);
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(podcastSearchProvider.notifier).clearSearch();
    _searchFocusNode.requestFocus();
  }

  void _onDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) return;
    final position = _discoverListScrollController.position;
    if (position.extentAfter > 200) return;
    ref.read(podcastDiscoverProvider.notifier).loadMoreCurrentTab();
  }

  void _resetDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) return;
    _discoverListScrollController.jumpTo(0);
  }

  Future<void> _handleSubscribeFromChart(PodcastDiscoverItem item) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final itunesId = item.itunesId;

    if (itunesId == null || _subscribingShowIds.contains(itunesId)) return;

    setState(() => _subscribingShowIds.add(itunesId));

    try {
      final searchService = ref.read(iTunesSearchServiceProvider);
      final lookup = await searchService.lookupPodcast(
        itunesId: itunesId,
        country: country,
      );
      final feedUrl = lookup?.feedUrl;
      if (feedUrl == null) throw Exception('No RSS feed url');

      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: feedUrl);

      if (!mounted) return;
      setState(() => _subscribedShowIds.add(itunesId));
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_success(lookup?.collectionName ?? item.title),
      );
    } catch (error) {
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _subscribingShowIds.remove(itunesId));
    }
  }

  Future<void> _openCountrySelector(BuildContext context) async {
    await showAdaptiveSheet<void>(
      context: context,
      desktopMaxWidth: 480,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.md),
            child: CountrySelectorDropdown(
              onCountryChanged: (country) {
                _resetDiscoverListScroll();
                ref.read(podcastDiscoverProvider.notifier).onCountryChanged(country);
                if (ref.read(podcastSearchProvider).currentQuery.isNotEmpty) {
                  ref.read(podcastSearchProvider.notifier).retrySearch();
                }
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(podcastSearchProvider);
    final discoverState = ref.watch(podcastDiscoverProvider);
    const isDense = true;
    final hasSearched = searchState.hasSearched;
    final searchMode = searchState.searchMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final useCompactShell =
            constraints.maxHeight < 540 || screenHeight < 720;
        final headerSpacing = screenWidth < 600 ? 20.0 : 12.0;
        // Magazine masthead only where there is room for it; short
        // viewports keep the browse content closer to the top.
        final showMasthead = !useCompactShell;

        final content = hasSearched
            ? PodcastSearchResultsList(
                searchState: searchState,
                onEpisodeTap: (e) =>
                    DiscoverInteractionHandler.handleEpisodeTap(ref, context, e),
                onEpisodePlay: (e) =>
                    DiscoverInteractionHandler.handleEpisodePlay(ref, context, e),
                onPodcastSubscribe: (r) => DiscoverInteractionHandler
                    .subscribeFromSearch(ref, context, r),
                onRetry: () =>
                    ref.read(podcastSearchProvider.notifier).retrySearch(),
                onClear: _clearSearch,
                isDense: isDense,
              )
            : _buildBrowseContent(
                context, discoverState, isDense, showMasthead);

        return ContentShell(
          title: context.l10n.podcast_discover_title,
          subtitle: '',
          headerSpacing: headerSpacing,
          roundedViewport: true,
          trailing: SearchModeToggle(
            searchMode: searchMode,
            isDense: isDense,
            onTabSelected: _handleDiscoverTabSelected,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiscoverSearchInput(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
                searchMode: searchMode,
                isDense: isDense,
              ),
              SizedBox(height: useCompactShell ? context.spacing.smMd : context.spacing.md),
              Expanded(child: Material(color: Colors.transparent, child: content)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrowseContent(
    BuildContext context,
    PodcastDiscoverState discoverState,
    bool isDense,
    bool showMasthead,
  ) {
    final l10n = context.l10n;

    if (discoverState.isLoading &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return const DiscoverBrowseSkeleton();
    }

    final error = discoverState.error;
    if (error != null &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return _buildErrorView(context, l10n, error);
    }

    return AdaptiveRefreshIndicator.sliver(
      onRefresh: () => ref.read(podcastDiscoverProvider.notifier).refresh(),
      // Ignored on every platform: the builder below always supplies the
      // scroll view (with a Cupertino refresh sliver on Apple platforms).
      child: const SizedBox.shrink(),
      builder: (context, refreshSliver) => _buildBrowseScroll(
        context,
        discoverState,
        isDense,
        refreshSliver,
        showMasthead,
      ),
    );
  }

  Widget _buildBrowseScroll(
    BuildContext context,
    PodcastDiscoverState discoverState,
    bool isDense,
    Widget? refreshSliver,
    bool showMasthead,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visibleItems = discoverState.visibleItems;
    final spotlightItems = visibleItems
        .take(DiscoverSpotlightSection.maxItemCount)
        .toList();

    return CustomScrollView(
      key: const Key('podcast_discover_scroll'),
      controller: _discoverListScrollController,
      cacheExtent: ScrollConstants.largeListCacheExtent,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (refreshSliver != null) refreshSliver,
        if (showMasthead)
          SliverToBoxAdapter(
            child: Padding(
              key: const Key('podcast_discover_masthead'),
              padding: EdgeInsets.fromLTRB(
                context.spacing.xs,
                context.spacing.xxs,
                context.spacing.xs,
                context.spacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.podcast_discover_header_eyebrow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Text(
                    l10n.podcast_discover_header_subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: DiscoverSpotlightSection(
            items: spotlightItems,
            onItemTap: (item) =>
                DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
            onItemSubscribe: _handleSubscribeFromChart,
            onItemPlay: (item) => DiscoverInteractionHandler
                .playEpisodeFromChartRow(ref, context, item),
            subscribingShowIds: _subscribingShowIds,
            subscribedShowIds: _subscribedShowIds,
          ),
        ),
        SliverToBoxAdapter(
          child: DiscoverTopChartsSection(
            state: discoverState,
            onCategorySelected: _handleDiscoverCategorySelected,
            onCountryTap: () => _openCountrySelector(context),
            isDense: isDense,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spacing.sm)),
        DiscoverChartsSliver(
          visibleItems: visibleItems,
          onItemTap: (item) =>
              DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
          onItemSubscribe: _handleSubscribeFromChart,
          onItemPlay: (item) =>
              DiscoverInteractionHandler.playEpisodeFromChartRow(ref, context, item),
          subscribingShowIds: _subscribingShowIds,
          subscribedShowIds: _subscribedShowIds,
          isDense: isDense,
        ),
        if (discoverState.isCurrentTabLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (!discoverState.currentTabHasMore && visibleItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
              child: Center(
                child: Text(
                  key: const Key('podcast_discover_footer'),
                  l10n.podcast_discover_footer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (visibleItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.md),
              child: discoverState.activeItems.isEmpty
                  ? AppEmptyState(
                      icon: Icons.leaderboard_outlined,
                      title: l10n.podcast_discover_no_chart_data,
                      action: FilledButton.icon(
                        onPressed: () => ref
                            .read(podcastDiscoverProvider.notifier)
                            .loadInitialData(),
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      ),
                    )
                  : AppEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: l10n.podcast_discover_category_empty_title,
                      subtitle: l10n.podcast_discover_category_empty_subtitle,
                      action: FilledButton.tonal(
                        onPressed: _resetDiscoverCategoryFilter,
                        child: Text(l10n.podcast_discover_see_all),
                      ),
                    ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, AppLocalizations l10n, String error) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: error,
      action: FilledButton.icon(
        onPressed: () =>
            ref.read(podcastDiscoverProvider.notifier).loadInitialData(),
        icon: const Icon(Icons.refresh),
        label: Text(l10n.retry),
      ),
    );
  }
}
