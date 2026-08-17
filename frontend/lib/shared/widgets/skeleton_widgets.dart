import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_chart_row.dart' show DiscoverChartRow;
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart' show BaseEpisodeCard;

import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

/// A single shimmer rectangle with rounded corners.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.xs,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular shimmer placeholder.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton for an episode feed card matching [BaseEpisodeCard] layout.
///
/// Wraps content in [ShimmerLoading] for animation.
class EpisodeCardSkeleton extends StatelessWidget {
  const EpisodeCardSkeleton({
    super.key,
    this.compact = false,
    this.showDescription = true,
    this.cardMargin,
  });

  final bool compact;
  final bool showDescription;
  final EdgeInsetsGeometry? cardMargin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = compact
        ? EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.smMd)
        : EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.md, context.spacing.smMd);
    final titleFont = compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium;
    final titleFontSize = titleFont?.fontSize ?? 14;
    final titleHeight = titleFont?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleHeight);
    const coverRadius = AppRadius.sm;

    return ShimmerLoading(
      child: Card(
        margin: cardMargin ?? (compact ? EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.smMd) : null),
        shape: AppRadius.mdLgShape,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: [image skeleton, title lines]
              Row(
                children: [
                  SkeletonBox(
                    width: coverSize,
                    height: coverSize,
                    borderRadius: coverRadius,
                  ),
                  SizedBox(width: context.spacing.smMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: titleFontSize + 2, width: double.infinity),
                        SizedBox(height: context.spacing.sm),
                        SkeletonBox(height: titleFontSize + 2, width: compact ? 120 : 180),
                      ],
                    ),
                  ),
                ],
              ),
              if (showDescription) ...[
                SizedBox(height: context.spacing.sm),
                const SkeletonBox(height: 12, width: double.infinity),
                SizedBox(height: context.spacing.xs),
                SkeletonBox(height: 12, width: compact ? 200 : 280),
              ],
              SizedBox(height: context.spacing.sm),
              // Meta row
              Row(
                children: [
                  const SkeletonBox(height: 10, width: 60),
                  SizedBox(width: context.spacing.sm),
                  const SkeletonBox(height: 10, width: 40),
                  const Spacer(),
                  const SkeletonCircle(size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of skeleton cards for initial loading state.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    this.itemCount = 5,
    this.compact = false,
    this.showDescription = true,
  });

  final int itemCount;
  final bool compact;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      itemCount: itemCount,
      itemBuilder: (context, index) => EpisodeCardSkeleton(
        compact: compact,
        showDescription: showDescription,
      ),
    );
  }
}

/// A grid of skeleton cards for desktop layout.
class SkeletonCardGrid extends StatelessWidget {
  const SkeletonCardGrid({
    required this.crossAxisCount, super.key,
    this.itemCount = 8,
    this.childAspectRatio = 2.0,
  });

  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: context.spacing.sm,
        mainAxisSpacing: context.spacing.sm,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const EpisodeCardSkeleton(),
    );
  }
}

/// Skeleton for a discover chart row card, matching [DiscoverChartRow] layout.
class DiscoverChartRowSkeleton extends StatelessWidget {
  const DiscoverChartRowSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final padding = compact ? context.spacing.smMd : context.spacing.md;

    return ShimmerLoading(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(extension.cardRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              const SkeletonBox(width: 32, height: 20),
              SizedBox(width: context.spacing.smMd),
              const SkeletonBox(width: 48, height: 48, borderRadius: AppRadius.sm),
              SizedBox(width: context.spacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: double.infinity),
                    SizedBox(height: context.spacing.xs),
                    SkeletonBox(height: 12, width: compact ? 100 : 140),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const SkeletonCircle(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of discover chart skeleton cards for initial loading state.
class DiscoverChartSkeletonList extends StatelessWidget {
  const DiscoverChartSkeletonList({
    super.key,
    this.itemCount = 6,
    this.compact = true,
  });

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
        child: DiscoverChartRowSkeleton(compact: compact),
      ),
    );
  }
}

/// A grid of discover chart skeleton cards for desktop layout.
class DiscoverChartSkeletonGrid extends StatelessWidget {
  const DiscoverChartSkeletonGrid({
    required this.crossAxisCount,
    super.key,
    this.itemCount = 8,
  });

  final int itemCount;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing.sm;
        final availableWidth =
            constraints.maxWidth - (crossAxisCount - 1) * spacing;
        final cardWidth = availableWidth / crossAxisCount;
        const cardHeight = 72.0;
        final childAspectRatio = cardWidth / cardHeight;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) =>
              const DiscoverChartRowSkeleton(compact: true),
        );
      },
    );
  }
}
