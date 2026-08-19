import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/core/widgets/linear_section_header.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:sonde/features/podcast/presentation/widgets/podcast_episode_search_result_card.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_search_result_card.dart';
import 'package:sonde/shared/widgets/skeleton_widgets.dart';

/// Search results view for the discover page: one query returns both
/// shows and episodes, rendered as two labeled sections in a single
/// scroll view — skeleton loading, proper empty/error states, and a
/// result-count header above everything.
///
/// Podcast results adapt to a two-column grid on wide layouts; episode
/// results stay in a single column.
class PodcastSearchResultsList extends ConsumerWidget {
  const PodcastSearchResultsList({
    required this.searchState,
    required this.onEpisodeTap,
    required this.onEpisodePlay,
    required this.onPodcastSubscribe,
    required this.onRetry,
    required this.onClear,
    required this.isDense,
    super.key,
  });

  final search.PodcastSearchState searchState;
  final ValueChanged<ITunesPodcastEpisodeResult> onEpisodeTap;
  final ValueChanged<ITunesPodcastEpisodeResult> onEpisodePlay;
  final ValueChanged<PodcastSearchResult> onPodcastSubscribe;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    if (searchState.isLoading) {
      return const SkeletonCardList(compact: true, showDescription: false);
    }

    if (searchState.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: searchState.error!,
        subtitle: searchState.currentQuery,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
      );
    }

    final podcastResults = searchState.podcastResults;
    final episodeResults = searchState.episodeResults;
    if (podcastResults.isEmpty && episodeResults.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: l10n.podcast_search_no_results,
        subtitle: l10n.podcast_search_empty_hint,
        action: FilledButton.tonalIcon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: Text(l10n.clear),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearSectionHeader.label(
          l10n.podcast_search_results_count(
            podcastResults.length + episodeResults.length,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xs,
            vertical: context.spacing.xs,
          ),
        ),
        Expanded(child: _buildResults(context, ref)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final podcastResults = searchState.podcastResults;
    final episodeResults = searchState.episodeResults;

    return CustomScrollView(
      key: const Key('podcast_discover_search_results'),
      slivers: [
        if (podcastResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: LinearSectionHeader.label(
              l10n.podcast_search_section_podcasts,
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xs,
                vertical: context.spacing.xs,
              ),
            ),
          ),
          _buildPodcastSliver(context, ref, podcastResults),
        ],
        if (episodeResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: LinearSectionHeader.label(
              l10n.podcast_search_section_episodes,
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xs,
                vertical: context.spacing.xs,
              ),
            ),
          ),
          SliverList.builder(
            itemCount: episodeResults.length,
            itemBuilder: (context, index) {
              final episode = episodeResults[index];
              return RepaintBoundary(
                key: ValueKey('episode_result_${episode.trackId}'),
                child: PodcastEpisodeSearchResultCard(
                  episode: episode,
                  dense: isDense,
                  onTap: () => onEpisodeTap(episode),
                  onPlay: () => onEpisodePlay(episode),
                  key: ValueKey('episode_search_${episode.trackId}'),
                ),
              );
            },
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.md)),
      ],
    );
  }

  Widget _buildPodcastSliver(
    BuildContext context,
    WidgetRef ref,
    List<PodcastSearchResult> results,
  ) {
    final normalizedSubscribedFeedUrls = ref.watch(
      subscribedNormalizedFeedUrlsProvider,
    );
    final normalizedSubscribingFeedUrls = ref.watch(
      subscribingNormalizedFeedUrlsProvider,
    );

    Widget buildItem(BuildContext context, PodcastSearchResult result) {
      return RepaintBoundary(
        key: ValueKey('podcast_result_${result.feedUrl}'),
        child: _PodcastSearchResultItem(
          result: result,
          isDense: isDense,
          searchCountry: searchState.searchCountry,
          normalizedSubscribedFeedUrls: normalizedSubscribedFeedUrls,
          normalizedSubscribingFeedUrls: normalizedSubscribingFeedUrls,
          onSubscribe: onPodcastSubscribe,
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.crossAxisExtent < Breakpoints.medium;

        if (isMobile) {
          return SliverList.builder(
            itemCount: results.length,
            itemBuilder: (context, index) =>
                buildItem(context, results[index]),
          );
        }

        final spacing = context.spacing.sm;
        final cardWidth = (constraints.crossAxisExtent - spacing) / 2;
        // Dense result rows (artwork + title/subtitle/metadata) need ~120px
        // in the Ahem test font; 128 keeps a comfortable margin.
        const cardHeight = 128.0;

        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) => buildItem(context, results[index]),
        );
      },
    );
  }
}

class _PodcastSearchResultItem extends StatelessWidget {
  const _PodcastSearchResultItem({
    required this.result,
    required this.isDense,
    required this.searchCountry,
    required this.normalizedSubscribedFeedUrls,
    required this.normalizedSubscribingFeedUrls,
    required this.onSubscribe,
  });

  final PodcastSearchResult result;
  final bool isDense;
  final PodcastCountry searchCountry;
  final Set<String> normalizedSubscribedFeedUrls;
  final Set<String> normalizedSubscribingFeedUrls;
  final ValueChanged<PodcastSearchResult> onSubscribe;

  @override
  Widget build(BuildContext context) {
    final normalizedResultFeedUrl = result.feedUrl == null
        ? null
        : PodcastUrlUtils.normalizeFeedUrl(result.feedUrl!);
    final isSubscribed =
        normalizedResultFeedUrl != null &&
        normalizedSubscribedFeedUrls.contains(normalizedResultFeedUrl);
    final isSubscribing =
        normalizedResultFeedUrl != null &&
        normalizedSubscribingFeedUrls.contains(normalizedResultFeedUrl);

    return PodcastSearchResultCard(
      result: result,
      onSubscribe: onSubscribe,
      isSubscribed: isSubscribed,
      isSubscribing: isSubscribing,
      searchCountry: searchCountry,
      dense: isDense,
      key: ValueKey('search_${result.feedUrl}'),
    );
  }
}
