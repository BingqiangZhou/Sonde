import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/base_episode_card.dart' show BaseEpisodeCard;

/// Chart row widget for displaying a single discover item with rank and actions.
///
/// The rank is an oversized light-weight numeral — colored for the top 3
/// (gold/coral/violet) and a ghost texture for the rest — on a card-style
/// container matching [BaseEpisodeCard] visual pattern.
class DiscoverChartRow extends StatelessWidget {
  const DiscoverChartRow({
    required this.rank,
    required this.item,
    required this.onTap,
    required this.onSubscribe,
    required this.onPlay,
    super.key,
    this.isSubscribing = false,
    this.isSubscribed = false,
    this.isDense = false,
    this.cardMargin,
    this.subtitleSuffix,
  });

  final int rank;
  final PodcastDiscoverItem item;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final VoidCallback onPlay;
  final bool isSubscribing;
  final bool isSubscribed;
  final bool isDense;
  final EdgeInsetsGeometry? cardMargin;

  /// Optional pre-built suffix appended to the subtitle (e.g. a hydrated
  /// episode duration), replacing the genre when present.
  final String? subtitleSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final showSubscribe = item.isPodcastShow;
    final rankSlotWidth = isDense ? 40.0 : 48.0;
    final actionSlotWidth = isDense ? 32.0 : 48.0;
    final innerPadding = isDense ? context.spacing.sm : context.spacing.md;
    final imageSize = isDense ? 48.0 : 62.0;
    final titleStyle =
        (isDense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle =
        (isDense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    // 显式 List<Color>：switch 含 `const []` 分支时推断会退化为 List<dynamic>。
    final List<Color> identityColors = switch (rank) {
      1 => AppColors.goldColors,
      2 => AppColors.coralColors,
      3 => AppColors.violetColors,
      _ => const <Color>[],
    };
    // Ghost numerals whisper the item's hero palette so the chart list
    // reads as one color system with the spotlight above.
    final itemPalette = AppColors
        .podcastGradientColors[item.itemId.hashCode.abs() % AppColors.podcastGradientColors.length];
    final rankColor = rank <= 3
        ? identityColors.first
        : itemPalette.first.withValues(alpha: 0.38);

    final genre =
        item.genres.where((g) => g.trim().isNotEmpty).firstOrNull;
    final subtitleText = subtitleSuffix != null
        ? '${item.artist} · $subtitleSuffix'
        : genre == null
            ? item.artist
            : '${item.artist} · $genre';

    return Padding(
      key: Key('podcast_discover_chart_row_${item.itemId}'),
      padding: cardMargin ??
          EdgeInsets.symmetric(vertical: isDense ? context.spacing.xxs : context.spacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(extension.cardRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: AdaptiveInkWell(
            borderRadius: BorderRadius.circular(extension.cardRadius),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isDense ? context.spacing.sm : context.spacing.md,
                horizontal: innerPadding,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: rankSlotWidth,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          key: Key(
                            'podcast_discover_chart_rank_text_${item.itemId}',
                          ),
                          '$rank',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w200,
                            height: 1.1,
                            color: rankColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isDense ? context.spacing.xs - 1 : context.spacing.smMd,
                  ),
                  RepaintBoundary(
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(extension.buttonRadius),
                        // Medal ring for the top 3, matching the rank color.
                        border: rank <= 3
                            ? Border.all(
                                color: rankColor.withValues(alpha: 0.7),
                                width: 2,
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(extension.buttonRadius),
                        child: PodcastImageWidget(
                          imageUrl: item.artworkUrl,
                          width: imageSize,
                          height: imageSize,
                          iconSize: 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isDense ? context.spacing.xs : context.spacing.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: isDense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        SizedBox(
                          height: context.spacing.xxs,
                        ),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isDense ? context.spacing.xs : context.spacing.sm,
                  ),
                  if (showSubscribe)
                    SizedBox(
                      width: actionSlotWidth,
                      child: Center(
                        child: SizedBox(
                          width: isDense ? 32 : 36,
                          height: isDense ? 32 : 36,
                          child: isSubscribing
                              ? Padding(
                                  padding: EdgeInsets.all(context.spacing.sm),
                                  child: const CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton.filledTonal(
                                  key: Key(
                                    'podcast_discover_subscribe_${item.itemId}',
                                  ),
                                  onPressed: isSubscribed ? null : onSubscribe,
                                  tooltip: context.l10n.podcast_subscribe,
                                  style: IconButton.styleFrom(
                                    minimumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                                    maximumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                                    tapTargetSize:
                                        MaterialTapTargetSize.padded,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    isSubscribed ? Icons.check : Icons.add,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  if (!showSubscribe)
                    SizedBox(
                      width: actionSlotWidth,
                      child: Center(
                        child: SizedBox(
                          width: isDense ? 32 : 36,
                          height: isDense ? 32 : 36,
                          child: IconButton.filledTonal(
                            key: Key(
                              'podcast_discover_play_${item.itemId}',
                            ),
                            onPressed: onPlay,
                            tooltip: context.l10n.podcast_play,
                            style: IconButton.styleFrom(
                              minimumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                              maximumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          ),
                        ),
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
}
