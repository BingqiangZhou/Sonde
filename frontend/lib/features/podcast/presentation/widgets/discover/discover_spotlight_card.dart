import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Large editorial card for the discover spotlight section.
///
/// Gradient-tinted surface (palette picked by rank from
/// [AppColors.podcastGradientColors]), oversized artwork with an overlaid
/// rank badge, and a primary CTA: subscribe for shows, play for episodes.
class DiscoverSpotlightCard extends StatelessWidget {
  const DiscoverSpotlightCard({
    required this.rank,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    super.key,
    this.isActing = false,
    this.isDone = false,
  });

  static const double cardHeight = 168;
  static const double artworkSize = 104;

  final int rank;
  final PodcastDiscoverItem item;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final bool isActing;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final isShow = item.isPodcastShow;

    final palette =
        AppColors.podcastGradientColors[(rank - 1) % AppColors.podcastGradientColors.length];

    return RepaintBoundary(
      key: Key('podcast_discover_spotlight_card_${item.itemId}'),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(extension.cardRadius),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.first.withValues(alpha: 0.18),
              palette.last.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: AdaptiveInkWell(
            borderRadius: BorderRadius.circular(extension.cardRadius),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(context.spacing.md),
              child: Row(
                children: [
                  _buildArtwork(context, extension.buttonRadius, palette),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: context.spacing.xxs),
                        Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: context.spacing.sm),
                        _buildAction(context, isShow, l10n),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(
    BuildContext context,
    double cornerRadius,
    List<Color> palette,
  ) {
    return SizedBox(
      width: artworkSize,
      height: artworkSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: PodcastImageWidget(
              // Chart feeds only expose 100x100 artwork; request the
              // hi-res variant for the large spotlight surface.
              imageUrl: (item.artworkUrl ?? '').replaceAll('100x100', '600x600'),
              width: artworkSize,
              height: artworkSize,
              iconSize: 28,
            ),
          ),
          Positioned(
            left: -context.spacing.sm,
            top: -context.spacing.sm,
            child: Container(
              key: Key('podcast_discover_spotlight_rank_${item.itemId}'),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.sm,
                vertical: context.spacing.xxs + 1,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: palette),
                borderRadius: AppRadius.pillRadius,
                boxShadow: [
                  BoxShadow(
                    color: palette.first.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '#$rank',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, bool isShow, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (isShow) {
      return SizedBox(
        height: 34,
        child: FilledButton.tonalIcon(
          key: Key('podcast_discover_spotlight_action_${item.itemId}'),
          onPressed: isDone ? null : onPrimaryAction,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            visualDensity: VisualDensity.compact,
          ),
          icon: isActing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Icon(isDone ? Icons.check : Icons.add, size: 16),
          label: Text(
            isDone ? l10n.podcast_subscribed : l10n.podcast_subscribe,
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        key: Key('podcast_discover_spotlight_action_${item.itemId}'),
        onPressed: onPrimaryAction,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(l10n.podcast_play),
      ),
    );
  }
}
