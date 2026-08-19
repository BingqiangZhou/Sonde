import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/services/app_cache_service.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Full-bleed editorial hero card for the discover spotlight section.
///
/// Each item gets its own color world: its own artwork, blurred and scaled
/// up as an ambient backdrop, tinted by a saturated gradient picked
/// deterministically from [AppColors.podcastGradientColors] by item id.
/// White typography, a floating shadowed artwork, and a white pill CTA
/// (subscribe for shows, listen now for episodes) sit on top.
class DiscoverSpotlightCard extends StatelessWidget {
  const DiscoverSpotlightCard({
    required this.chartRank,
    required this.item,
    required this.onTap,
    required this.onPrimaryAction,
    super.key,
    this.isActing = false,
    this.isDone = false,
    this.isWide = false,
  });

  // Heights hug the content (artwork + padding) so the card carries no
  // dead vertical space.
  static const double cardHeight = 200;
  static const double wideCardHeight = 168;
  static const double artworkSize = 144;
  static const double wideArtworkSize = 112;

  /// The item's rank on its source chart — explains why it is featured.
  final int chartRank;
  final PodcastDiscoverItem item;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final bool isActing;
  final bool isDone;
  final bool isWide;

  String get _hiResArtworkUrl =>
      (item.artworkUrl ?? '').replaceAll('100x100', '600x600');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final l10n = context.l10n;
    final isShow = item.isPodcastShow;

    final palette = AppColors
        .podcastGradientColors[item.itemId.hashCode.abs() % AppColors.podcastGradientColors.length];
    final height = isWide ? wideCardHeight : cardHeight;
    final artwork = isWide ? wideArtworkSize : artworkSize;
    // A semantic eyebrow — top show / top episode with the chart rank —
    // tells the reader why the item is featured.
    final eyebrowText = isShow
        ? l10n.podcast_discover_spotlight_top_show(chartRank)
        : l10n.podcast_discover_spotlight_top_episode(chartRank);

    return RepaintBoundary(
      key: Key('podcast_discover_spotlight_card_${item.itemId}'),
      child: _HoverLift(
        shadowColor: palette.last,
        radius: extension.cardRadius,
        child: Container(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(extension.cardRadius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
              // Ambient backdrop: the item's own artwork, blurred and
              // oversized, so every card is tinted by its cover.
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.5,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: CachedNetworkImage(
                      imageUrl: _hiResArtworkUrl,
                      cacheManager: AppMediaCacheManager.instance,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorListener: (_) {},
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.first.withValues(alpha: 0.88),
                        palette.last.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              // Top-left light bloom keeps the saturated field from
              // reading flat.
              Positioned(
                left: -artwork / 2,
                top: -artwork / 2,
                child: Container(
                  width: artwork * 1.6,
                  height: artwork * 1.6,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: AdaptiveInkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.all(context.spacing.md),
                    // The stack passes tight constraints down, so without
                    // the center wrapper the content row would stick to the
                    // card top with dead space below.
                    child: Center(
                      child: Row(
                        children: [
                          _buildArtwork(context, extension.buttonRadius, palette, artwork),
                          SizedBox(width: context.spacing.md),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eyebrowText.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: context.spacing.xs),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: context.spacing.xxs),
                                Text(
                                  item.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                                SizedBox(height: context.spacing.sm),
                                _buildAction(context, isShow, l10n),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    double size,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: PodcastImageWidget(
                // Chart feeds only expose 100x100 artwork; request the
                // hi-res variant for the large hero surface.
                imageUrl: (item.artworkUrl ?? '').replaceAll('100x100', '600x600'),
                width: size,
                height: size,
                iconSize: 32,
              ),
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                '#$chartRank',
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
    final pillStyle = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black.withValues(alpha: 0.87),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.mdLg),
      textStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );

    if (isShow) {
      return SizedBox(
        height: 36,
        child: FilledButton.icon(
          key: Key('podcast_discover_spotlight_action_${item.itemId}'),
          onPressed: isDone ? null : onPrimaryAction,
          style: pillStyle,
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
      height: 36,
      child: FilledButton.icon(
        key: Key('podcast_discover_spotlight_action_${item.itemId}'),
        onPressed: onPrimaryAction,
        style: pillStyle,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(l10n.podcast_discover_listen_now),
      ),
    );
  }
}

/// Desktop hover treatment: the hero card rises slightly and its colored
/// shadow deepens. A no-op on touch devices.
class _HoverLift extends StatefulWidget {
  const _HoverLift({
    required this.shadowColor,
    required this.radius,
    required this.child,
  });

  final Color shadowColor;
  final double radius;
  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.transitionFast,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor.withValues(alpha: _hovered ? 0.5 : 0.35),
              blurRadius: _hovered ? 28 : 20,
              offset: Offset(0, _hovered ? 12 : 8),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
