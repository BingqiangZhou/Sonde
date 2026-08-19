import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/selector_sheet_common.dart';
import 'package:sonde/features/podcast/presentation/widgets/simplified_episode_card.dart';

class DiscoverShowEpisodesSheet extends StatelessWidget {
  const DiscoverShowEpisodesSheet({
    required this.showId, required this.showTitle, required this.episodes, required this.onEpisodeSelected, required this.onPlayEpisode, super.key,
  });

  final int showId;
  final String showTitle;
  final List<ITunesPodcastEpisodeResult> episodes;
  final void Function(ITunesPodcastEpisodeResult episode) onEpisodeSelected;
  final void Function(ITunesPodcastEpisodeResult episode) onPlayEpisode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: Column(
        key: const Key('discover_show_episodes_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectorSheetHeader(
            icon: Icons.podcasts_rounded,
            title: showTitle,
            titleMaxLines: 2,
            subtitle: '${episodes.length} ${l10n.podcast_episodes}',
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.md,
                context.spacing.sm,
                context.spacing.md,
                context.spacing.md,
              ),
              child: episodes.isEmpty
                  ? Center(
                      child: Text(
                        l10n.podcast_no_episodes_found,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final discoverEpisode = PodcastEpisodeModel(
                          id: episode.trackId,
                          subscriptionId: 0,
                          title: episode.trackName,
                          subscriptionTitle: episode.collectionName,
                          description:
                              episode.description ??
                              episode.shortDescription ??
                              '',
                          audioUrl: episode.resolvedAudioUrl ?? '',
                          audioDuration: episode.trackTimeMillis == null
                              ? null
                              : (episode.trackTimeMillis! / 1000).round(),
                          publishedAt: episode.releaseDate ?? now,
                          imageUrl:
                              episode.artworkUrl600 ?? episode.artworkUrl100,
                          itemLink: episode.trackViewUrl,
                          metadata: {
                            'discover_preview': true,
                            'source': 'top_charts',
                            'show_id': showId,
                            'track_id': episode.trackId,
                          },
                          createdAt: now,
                        );

                        return SimplifiedEpisodeCard(
                          episode: discoverEpisode,
                          onTap: () => onEpisodeSelected(episode),
                          onPlay: () => onPlayEpisode(episode),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
