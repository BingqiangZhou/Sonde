import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_chart_row.dart' show DiscoverChartRow;
import 'package:sonde/features/podcast/presentation/widgets/shared/base_episode_card.dart' show BaseEpisodeCard;

import 'package:sonde/shared/widgets/loading_widget.dart';

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

/// Full skeleton for the discover browse view: the two ranked shelves —
/// top shows and trending episodes — mirroring the charts-led layout.
class DiscoverBrowseSkeleton extends StatelessWidget {
  const DiscoverBrowseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonShelf(
            context: context,
            isMobile: MediaQuery.sizeOf(context).width < 600,
            rowCount: 4,
          ),
          _SkeletonShelf(
            context: context,
            isMobile: MediaQuery.sizeOf(context).width < 600,
            rowCount: 3,
          ),
        ],
      ),
    );
  }
}

/// One ranked-shelf placeholder: a header line (title + see-all stub)
/// followed by chart-row skeletons.
class _SkeletonShelf extends StatelessWidget {
  const _SkeletonShelf({
    required this.context,
    required this.isMobile,
    required this.rowCount,
  });

  final BuildContext context;
  final bool isMobile;
  final int rowCount;

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.spacing.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
          child: const Row(
            children: [
              SkeletonBox(height: 20, width: 120),
              Spacer(),
              SkeletonBox(height: 14, width: 56),
            ],
          ),
        ),
        SizedBox(height: context.spacing.xs),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: rowCount,
          itemBuilder: (_, index) => Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
            child: const DiscoverChartRowSkeleton(compact: true),
          ),
        ),
      ],
    );
  }
}

/// Skeleton for the full charts page: the category chips row, then the
/// single ranked chart it filters.
class DiscoverChartsSkeleton extends StatelessWidget {
  const DiscoverChartsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.sm,
              vertical: context.spacing.sm,
            ),
            child: const Row(
              children: [
                SkeletonBox(height: 28, width: 64, borderRadius: AppRadius.chip),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(height: 28, width: 88, borderRadius: AppRadius.chip),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(height: 28, width: 72, borderRadius: AppRadius.chip),
              ],
            ),
          ),
          _SkeletonShelf(
            context: context,
            isMobile: MediaQuery.sizeOf(context).width < 600,
            rowCount: 8,
          ),
        ],
      ),
    );
  }
}
