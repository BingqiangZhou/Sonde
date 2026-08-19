import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/selector_sheet_common.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class DiscoverEpisodeDetailSheet extends StatelessWidget {
  const DiscoverEpisodeDetailSheet({
    required this.episode, required this.onPlay, super.key,
  });

  final ITunesPodcastEpisodeResult episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final description = episode.description?.trim().isNotEmpty == true
        ? episode.description!
        : (episode.shortDescription ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('discover_episode_detail_sheet'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectorSheetHeader(
              leading: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    appThemeOf(context).itemRadius,
                  ),
                  child: PodcastImageWidget(
                    imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
                    width: 56,
                    height: 56,
                    iconSize: 24,
                  ),
                ),
              ),
              title: episode.trackName,
              titleMaxLines: 2,
              subtitle: episode.collectionName,
              trailing: IconButton(
                key: const Key('discover_episode_detail_play_button'),
                tooltip: l10n.podcast_play,
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                onPressed: onPlay,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.md,
                context.spacing.sm,
                context.spacing.md,
                context.spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _buildMetaText(episode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: context.spacing.smMd),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
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
