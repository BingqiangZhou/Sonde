import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/linear_section_header.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_spotlight_card.dart';

/// Spotlight section: the top-ranked chart items as large editorial cards.
///
/// - Narrow layouts: horizontal snapping carousel peeking at the next card.
/// - Wide layouts (>= [Breakpoints.mediumLarge]): the cards side by side.
///
/// Hidden when fewer than two items are available.
class DiscoverSpotlightSection extends StatefulWidget {
  const DiscoverSpotlightSection({
    required this.items,
    required this.onItemTap,
    required this.onItemSubscribe,
    required this.onItemPlay,
    required this.subscribingShowIds,
    required this.subscribedShowIds,
    super.key,
  });

  static const int maxItemCount = 3;
  static const double carouselViewportFraction = 0.86;

  final List<PodcastDiscoverItem> items;
  final ValueChanged<PodcastDiscoverItem> onItemTap;
  final ValueChanged<PodcastDiscoverItem> onItemSubscribe;
  final ValueChanged<PodcastDiscoverItem> onItemPlay;
  final Set<int> subscribingShowIds;
  final Set<int> subscribedShowIds;

  @override
  State<DiscoverSpotlightSection> createState() =>
      _DiscoverSpotlightSectionState();
}

class _DiscoverSpotlightSectionState extends State<DiscoverSpotlightSection> {
  PageController? _carouselController;

  @override
  void dispose() {
    _carouselController?.dispose();
    super.dispose();
  }

  PageController _ensureCarouselController() {
    return _carouselController ??= PageController(
      viewportFraction: DiscoverSpotlightSection.carouselViewportFraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.length < 2) return const SizedBox.shrink();

    return Column(
      key: const Key('podcast_discover_spotlight'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearSectionHeader.label(
          context.l10n.podcast_discover_spotlight,
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xs,
            vertical: context.spacing.xs,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= Breakpoints.mediumLarge;
            if (isWide) {
              return Row(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index != 0) SizedBox(width: context.spacing.sm),
                    Expanded(child: _buildCard(index)),
                  ],
                ],
              );
            }
            return SizedBox(
              height: DiscoverSpotlightCard.cardHeight,
              child: PageView.builder(
                key: const Key('podcast_discover_spotlight_carousel'),
                controller: _ensureCarouselController(),
                itemCount: items.length,
                padEnds: false,
                physics: const PageScrollPhysics(),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: index == 0 ? context.spacing.xs : context.spacing.xxs,
                    end: context.spacing.xs,
                  ),
                  child: _buildCard(index),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final item = widget.items[index];
    final itunesId = item.itunesId;
    return DiscoverSpotlightCard(
      rank: index + 1,
      item: item,
      onTap: () => widget.onItemTap(item),
      onPrimaryAction: item.isPodcastShow
          ? () => widget.onItemSubscribe(item)
          : () => widget.onItemPlay(item),
      isActing: itunesId != null && widget.subscribingShowIds.contains(itunesId),
      isDone: itunesId != null && widget.subscribedShowIds.contains(itunesId),
    );
  }
}
