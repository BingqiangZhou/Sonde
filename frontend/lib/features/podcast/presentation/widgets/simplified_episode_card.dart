import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/features/podcast/core/utils/episode_description_helper.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/base_episode_card.dart';

/// Simplified episode card without podcast image and name (for episodes list page)
class SimplifiedEpisodeCard extends ConsumerWidget {
  const SimplifiedEpisodeCard({
    required this.episode,
    super.key,
    this.onTap,
  });
  final PodcastEpisodeModel episode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < Breakpoints.medium;

    final displayDescription = EpisodeDescriptionHelper.getDisplayDescription(
      aiSummary: episode.aiSummary,
      description: episode.description,
    );

    return RepaintBoundary(
      key: ValueKey('simplified_episode_card_${episode.id}'),
      child: BaseEpisodeCard(
        config: EpisodeCardConfig(
          showImage: false,
          dense: isMobile,
          cardMargin: isMobile
              ? EdgeInsets.symmetric(
                  horizontal: context.spacing.xs,
                  vertical: context.spacing.xs,
                )
              : EdgeInsets.zero,
          showDate: true,
          date: episode.publishedAt,
          showDuration: true,
          formattedDuration: episode.formattedDuration,
          showDescription: displayDescription.isNotEmpty,
          description: displayDescription.isNotEmpty
              ? displayDescription
              : null,
          descriptionMaxLines: isMobile ? 2 : 4,
        ),
        title: episode.title,
        onTap: onTap,
        additionalMetadata: episode.aiSummary != null
            ? [
                Tooltip(
                  message: context.l10n.ai_summary_available,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}
