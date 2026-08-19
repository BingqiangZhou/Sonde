import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/scroll_constants.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:sonde/features/podcast/presentation/pages/sections/discover_interaction_handler.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_category_chips.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_charts_list.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_country_pill.dart';
import 'package:sonde/shared/widgets/skeleton_widgets.dart';

/// Which ranked chart the full charts page renders — each discover shelf's
/// "see all" lands on its own section.
enum PodcastChartsSection { shows, episodes }

/// Full charts page pushed from a discover shelf's "see all".
///
/// Renders one ranked chart ([section]) in full, with the category chips
/// above it — Apple's per-chart page shape.
class PodcastChartsPage extends ConsumerStatefulWidget {
  const PodcastChartsPage({this.section = PodcastChartsSection.shows, super.key});

  final PodcastChartsSection section;

  @override
  ConsumerState<PodcastChartsPage> createState() => _PodcastChartsPageState();
}

class _PodcastChartsPageState extends ConsumerState<PodcastChartsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(podcastDiscoverProvider.notifier).loadInitialData(),
      );
    });
  }

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
    final discoverState = ref.watch(podcastDiscoverProvider);
    final l10n = context.l10n;
    final sectionLabel = widget.section == PodcastChartsSection.shows
        ? l10n.podcast_discover_top_shows
        : l10n.podcast_discover_top_episodes;

    return ContentShell(
      title: l10n.podcast_discover_top_charts,
      subtitle: sectionLabel,
      roundedViewport: true,
      leading: IconButton(
        key: const Key('podcast_charts_back'),
        icon: Icon(Icons.adaptive.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      trailing: DiscoverCountryPill(
        onTap: () =>
            DiscoverInteractionHandler.openCountrySelector(ref, context),
      ),
      child: _buildBody(context, discoverState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PodcastDiscoverState discoverState,
  ) {
    if (discoverState.isLoading && !discoverState.hasData) {
      return const DiscoverChartsSkeleton();
    }

    final error = discoverState.error;
    if (error != null && !discoverState.hasData) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: error,
        action: FilledButton.icon(
          onPressed: () =>
              ref.read(podcastDiscoverProvider.notifier).loadInitialData(),
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.retry),
        ),
      );
    }

    return AdaptiveRefreshIndicator.sliver(
      onRefresh: () => ref.read(podcastDiscoverProvider.notifier).refresh(),
      child: const SizedBox.shrink(),
      builder: (context, refreshSliver) => _buildScroll(
        context,
        discoverState,
        refreshSliver,
      ),
    );
  }

  Widget _buildScroll(
    BuildContext context,
    PodcastDiscoverState discoverState,
    Widget? refreshSliver,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isShowsSection = widget.section == PodcastChartsSection.shows;
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

    final visibleItems =
        isShowsSection ? discoverState.filteredShows : discoverState.filteredEpisodes;

    return CustomScrollView(
      key: const Key('podcast_charts_scroll'),
      cacheExtent: ScrollConstants.largeListCacheExtent,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (refreshSliver != null) refreshSliver,
        SliverToBoxAdapter(
          child: DiscoverCategoryChips(
            state: discoverState,
            onCategorySelected: (category) =>
                ref.read(podcastDiscoverProvider.notifier).selectCategory(category),
          ),
        ),
        if (visibleItems.isNotEmpty) ...[
          DiscoverChartsSliver(
            visibleItems: visibleItems,
            onItemTap: (item) =>
                DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
            onItemSubscribe: onSubscribe,
            onItemPlay: (item) =>
                DiscoverInteractionHandler.playEpisodeFromChartRow(ref, context, item),
            subscribingShowIds: subscribingShowIds,
            subscribedShowIds: subscribedShowIds,
            isDense: true,
            listKey: isShowsSection
                ? 'podcast_charts_shows_list'
                : 'podcast_charts_episodes_list',
            gridKey: isShowsSection
                ? 'podcast_charts_shows_grid'
                : 'podcast_charts_episodes_grid',
            subtitleSuffixBuilder: isShowsSection
                ? null
                : (item) => _episodeDurationSuffix(discoverState, item),
          ),
        ],
        if (discoverState.hasData && visibleItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.md),
              child: AppEmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: l10n.podcast_discover_category_empty_title,
                subtitle: l10n.podcast_discover_category_empty_subtitle,
                action: FilledButton.tonal(
                  onPressed: () => ref
                      .read(podcastDiscoverProvider.notifier)
                      .selectCategory(PodcastDiscoverState.allCategoryValue),
                  child: Text(l10n.podcast_discover_see_all),
                ),
              ),
            ),
          ),
        if (discoverState.hasData)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
              child: Center(
                child: Text(
                  l10n.podcast_discover_footer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
      ],
    );
  }
}
