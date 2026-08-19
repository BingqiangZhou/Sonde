import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/scroll_constants.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/utils/debounce.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/core/widgets/linear_section_header.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:sonde/features/podcast/presentation/pages/sections/discover_interaction_handler.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_charts_list.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_country_pill.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_search_input.dart';
import 'package:sonde/features/podcast/presentation/widgets/search/podcast_search_results_list.dart';
import 'package:sonde/shared/widgets/skeleton_widgets.dart';

/// Discover page: search plus a charts-led browse view — the top-shows
/// and trending-episodes shelves, with the country selector beside the
/// page title and the full charts (and their category chips) behind a
/// "see all" push.
class PodcastListPage extends ConsumerStatefulWidget {
  const PodcastListPage({super.key});

  @override
  ConsumerState<PodcastListPage> createState() => _PodcastListPageState();
}

class _PodcastListPageState extends ConsumerState<PodcastListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  DebounceTimer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialData());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.dispose();
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

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebounce?.cancel();
      ref.read(podcastSearchProvider.notifier).clearSearch();
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = DebounceTimer(
      AppDurations.debounceMedium,
      () => ref.read(podcastSearchProvider.notifier).search(query),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(podcastSearchProvider.notifier).clearSearch();
    _searchFocusNode.requestFocus();
  }

  /// Chart shows carry no feed url from the RSS API; the discover provider
  /// hydrates them via one batched lookup, so subscribed state derives
  /// from the real subscription list instead of a session-only set.
  Set<int> _resolveSubscribedShowIds(
    PodcastDiscoverState discoverState,
    Set<String> subscribedFeedUrls,
    Set<int> sessionSubscribedShowIds,
  ) {
    final result = sessionSubscribedShowIds.toSet();
    for (final entry in discoverState.showFeedUrls.entries) {
      if (subscribedFeedUrls
          .contains(PodcastUrlUtils.normalizeFeedUrl(entry.value))) {
        result.add(entry.key);
      }
    }
    return result;
  }

  String? _episodeDurationSuffix(
    PodcastDiscoverState discoverState,
    PodcastDiscoverItem item,
  ) {
    final trackId = item.itunesId;
    if (trackId == null) return null;
    final millis = discoverState.episodeMeta[trackId]?.trackTimeMillis;
    if (millis == null || millis <= 0) return null;
    return TimeFormatter.formatDuration(Duration(milliseconds: millis));
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(podcastSearchProvider);
    final discoverState = ref.watch(podcastDiscoverProvider);
    const isDense = true;
    final hasSearched = searchState.hasSearched;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final useCompactShell =
            constraints.maxHeight < 540 || screenHeight < 720;
        final headerSpacing = screenWidth < 600 ? 20.0 : 12.0;

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
            : _buildBrowseContent(context, discoverState, isDense);

        return ContentShell(
          title: context.l10n.podcast_discover_title,
          subtitle: '',
          headerSpacing: headerSpacing,
          roundedViewport: true,
          trailing: DiscoverCountryPill(
            onTap: () => DiscoverInteractionHandler.openCountrySelector(
              ref,
              context,
              retrySearchIfNeeded: true,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiscoverSearchInput(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
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
  ) {
    final l10n = context.l10n;

    if (discoverState.isLoading && !discoverState.hasData) {
      return const DiscoverBrowseSkeleton();
    }

    final error = discoverState.error;
    if (error != null && !discoverState.hasData) {
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
      ),
    );
  }

  Widget _buildBrowseScroll(
    BuildContext context,
    PodcastDiscoverState discoverState,
    bool isDense,
    Widget? refreshSliver,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subscribedFeedUrls = ref.watch(subscribedNormalizedFeedUrlsProvider);
    final subscribeState = ref.watch(discoverSubscribeProvider);
    final subscribingShowIds = subscribeState.subscribingShowIds;
    final subscribedShowIds = _resolveSubscribedShowIds(
      discoverState,
      subscribedFeedUrls,
      subscribeState.sessionSubscribedShowIds,
    );
    void onSubscribe(PodcastDiscoverItem item) =>
        DiscoverInteractionHandler.subscribeFromChart(ref, context, item);

    final topShowsShelf = discoverState.topShowsPreview;
    final topEpisodesShelf = discoverState.topEpisodesPreview;
    final hasAnyShelf =
        topShowsShelf.isNotEmpty || topEpisodesShelf.isNotEmpty;

    return CustomScrollView(
      key: const Key('podcast_discover_scroll'),
      cacheExtent: ScrollConstants.largeListCacheExtent,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (refreshSliver != null) refreshSliver,
        if (topShowsShelf.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildShelfHeader(
              context,
              title: l10n.podcast_discover_top_shows,
              titleKey: 'podcast_discover_top_shows_header',
              onSeeAll: () => context.push('/discover/charts?section=shows'),
              seeAllKey: 'podcast_discover_see_all_shows',
            ),
          ),
          DiscoverChartsSliver(
            visibleItems: topShowsShelf,
            onItemTap: (item) =>
                DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
            onItemSubscribe: onSubscribe,
            onItemPlay: (item) =>
                DiscoverInteractionHandler.playEpisodeFromChartRow(ref, context, item),
            subscribingShowIds: subscribingShowIds,
            subscribedShowIds: subscribedShowIds,
            isDense: isDense,
            listKey: 'podcast_discover_top_shows_list',
            gridKey: 'podcast_discover_top_shows_grid',
          ),
        ],
        if (topEpisodesShelf.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildShelfHeader(
              context,
              title: l10n.podcast_discover_top_episodes,
              titleKey: 'podcast_discover_top_episodes_header',
              onSeeAll: () => context.push('/discover/charts?section=episodes'),
              seeAllKey: 'podcast_discover_see_all_episodes',
            ),
          ),
          DiscoverChartsSliver(
            visibleItems: topEpisodesShelf,
            onItemTap: (item) =>
                DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
            onItemSubscribe: onSubscribe,
            onItemPlay: (item) =>
                DiscoverInteractionHandler.playEpisodeFromChartRow(ref, context, item),
            subscribingShowIds: subscribingShowIds,
            subscribedShowIds: subscribedShowIds,
            isDense: isDense,
            listKey: 'podcast_discover_top_episodes_list',
            gridKey: 'podcast_discover_top_episodes_grid',
            subtitleSuffixBuilder: (item) =>
                _episodeDurationSuffix(discoverState, item),
          ),
        ],
        if (hasAnyShelf)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
              child: Center(
                child: Text(
                  key: const Key('podcast_discover_footer'),
                  l10n.podcast_discover_footer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (!discoverState.hasData)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.md),
              child: AppEmptyState(
                icon: Icons.leaderboard_outlined,
                title: l10n.podcast_discover_no_chart_data,
                action: FilledButton.icon(
                  onPressed: () => ref
                      .read(podcastDiscoverProvider.notifier)
                      .loadInitialData(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
      ],
    );
  }

  /// A ranked shelf header: the 24px section title with an optional
  /// trailing control (country pill) and a "see all" push affordance.
  Widget _buildShelfHeader(
    BuildContext context, {
    required String title,
    required String titleKey,
    Widget? trailing,
    VoidCallback? onSeeAll,
    String? seeAllKey,
  }) {
    final theme = Theme.of(context);
    return Row(
      key: Key(titleKey),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: LinearSectionHeader(
            title: title,
            titleSize: 24,
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.xs,
              vertical: context.spacing.smMd,
            ),
          ),
        ),
        if (trailing != null)
          Padding(
            padding: EdgeInsets.only(left: context.spacing.md),
            child: trailing,
          ),
        if (onSeeAll != null)
          Padding(
            padding: EdgeInsets.only(
              left: context.spacing.sm,
              right: context.spacing.sm,
              bottom: context.spacing.xs,
            ),
            child: TextButton.icon(
              key: Key(seeAllKey ?? 'podcast_discover_see_all'),
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.primary,
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(context.l10n.podcast_discover_see_all),
            ),
          ),
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
