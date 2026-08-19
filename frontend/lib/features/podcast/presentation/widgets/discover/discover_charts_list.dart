import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_chart_row.dart';

/// Sliver of ranked chart rows for the discover browse view.
///
/// Adapts layout based on the sliver's cross-axis extent:
/// - Narrow (<[Breakpoints.medium]): single-column [SliverList]
/// - Wide (>=[Breakpoints.medium]): two-column [SliverGrid]
///
/// Loading-more and empty states are rendered by the parent scroll view.
class DiscoverChartsSliver extends StatelessWidget {
  const DiscoverChartsSliver({
    required this.visibleItems,
    required this.onItemTap,
    required this.onItemSubscribe,
    required this.onItemPlay,
    required this.subscribingShowIds,
    required this.subscribedShowIds,
    super.key,
    this.isDense = false,
  });

  final List<PodcastDiscoverItem> visibleItems;
  final ValueChanged<PodcastDiscoverItem> onItemTap;
  final ValueChanged<PodcastDiscoverItem> onItemSubscribe;
  final ValueChanged<PodcastDiscoverItem> onItemPlay;
  final Set<int> subscribingShowIds;
  final Set<int> subscribedShowIds;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.crossAxisExtent;
        final isMobile = crossAxisExtent < Breakpoints.medium;

        if (isMobile) {
          return SliverList(
            key: const Key('podcast_discover_list'),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildItem(context, visibleItems, index, gridMode: false),
              childCount: visibleItems.length,
            ),
          );
        }

        const crossAxisCount = 2;
        final spacing = context.spacing.sm;
        final cardWidth = (crossAxisExtent - spacing) / crossAxisCount;
        const cardHeight = 72.0;

        return SliverGrid(
          key: const Key('podcast_discover_grid'),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildItem(context, visibleItems, index, gridMode: true),
            childCount: visibleItems.length,
          ),
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    List<PodcastDiscoverItem> visibleItems,
    int index, {
    required bool gridMode,
  }) {
    final item = visibleItems[index];
    final itunesId = item.itunesId;

    return RepaintBoundary(
      key: ValueKey('chart_row_${item.itemId}'),
      child: DiscoverChartRow(
        rank: index + 1,
        item: item,
        onTap: () => onItemTap(item),
        onSubscribe: () => onItemSubscribe(item),
        onPlay: () => onItemPlay(item),
        isSubscribing: itunesId != null && subscribingShowIds.contains(itunesId),
        isSubscribed: itunesId != null && subscribedShowIds.contains(itunesId),
        isDense: isDense,
        cardMargin: gridMode ? EdgeInsets.zero : null,
      ),
    );
  }
}
