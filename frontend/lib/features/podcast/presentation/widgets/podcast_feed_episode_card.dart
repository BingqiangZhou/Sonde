import 'package:flutter/material.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/base_episode_card.dart';

class PodcastFeedEpisodeCard extends StatelessWidget {
  const PodcastFeedEpisodeCard({
    required this.episode,
    required this.compact,
    required this.displayDescription,
    required this.onOpenDetail,
    super.key,
  });

  final PodcastEpisodeModel episode;
  final bool compact;
  final String displayDescription;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final titleFontSize = titleStyle?.fontSize ?? 13;
    final titleLineHeightFactor = titleStyle?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleLineHeightFactor);
    final coverIconSize = (coverSize * 0.58).clamp(14.0, 28.0);
    final metadataFontSize = compact ? 11.0 : (Breakpoints.isMobile(MediaQuery.sizeOf(context).width) ? 12.0 : 11.0);

    // Identity gradient colors (all gradients are now monochrome gray)
    final identityGradientColors = AppColors.podcastGradientColors.first;

    return RepaintBoundary(
      child: BaseEpisodeCard(
      config: EpisodeCardConfig(
        imageUrl: episode.imageUrl ?? episode.subscriptionImageUrl,
        imageSize: coverSize,
        imageIconSize: coverIconSize,
        dense: compact,
        cardMargin: compact
            ? EdgeInsets.symmetric(
                horizontal: context.spacing.xs,
                vertical: context.spacing.xs,
              )
            : null,
        showSubscriptionBadge: true,
        subscriptionBadgeText:
            episode.subscriptionTitle ?? l10n.podcast_default_podcast,
        showDate: true,
        date: episode.publishedAt,
        showDuration: true,
        formattedDuration: episode.formattedDuration,
        metadataFontSize: metadataFontSize,
        showDescription: displayDescription.isNotEmpty,
        description: displayDescription.isNotEmpty ? displayDescription : null,
        descriptionMaxLines: compact ? 2 : 4,
        heroTag: 'episode_cover_${episode.id}',
        useGradientIdentityBar: true,
        identityGradientColors: identityGradientColors,
      ),
      title: episode.title,
      onTap: onOpenDetail,
      additionalMetadata: episode.aiSummary != null
          ? [
              Tooltip(
                message: l10n.ai_summary_available,
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ]
          : null,
    ),
    );
  }
}
