import 'package:flutter/material.dart';
import 'package:sonde/core/constants/app_spacing.dart';

import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class DiscoverEpisodeDetailSheet extends StatelessWidget {
  const DiscoverEpisodeDetailSheet({
    required this.episode, super.key,
  });

  final ITunesPodcastEpisodeResult episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = episode.description?.trim().isNotEmpty == true
        ? episode.description!
        : (episode.shortDescription ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('discover_episode_detail_sheet'),
        padding: EdgeInsets.fromLTRB(context.spacing.smMd, context.spacing.smMd, context.spacing.smMd, context.spacing.smMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
                    child: PodcastImageWidget(
                      imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
                      width: 64,
                      height: 64,
                      iconSize: 26,
                    ),
                  ),
                ),
                SizedBox(width: context.spacing.smMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.trackName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.spacing.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  episode.collectionName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: context.spacing.xxs),
                                Text(
                                  _buildMetaText(episode),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: context.spacing.smMd),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _buildMetaText(ITunesPodcastEpisodeResult episode) {
    final parts = <String>[];
    if (episode.releaseDate != null) {
      parts.add(EpisodeCardUtils.formatDate(episode.releaseDate!));
    }
    if (episode.trackTimeMillis != null && episode.trackTimeMillis! > 0) {
      parts.add(
        TimeFormatter.formatDuration(
          Duration(milliseconds: episode.trackTimeMillis!),
        ),
      );
    }
    return parts.join(' · ');
  }
}
