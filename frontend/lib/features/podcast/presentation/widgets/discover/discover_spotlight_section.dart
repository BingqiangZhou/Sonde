import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/linear_section_header.dart';
import 'package:sonde/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_spotlight_card.dart';

/// One spotlight entry: the chart item plus its rank on the source chart,
/// which feeds the semantic eyebrow and the floating rank badge.
class DiscoverSpotlightEntry {
  const DiscoverSpotlightEntry({
    required this.item,
    required this.chartRank,
  });

  final PodcastDiscoverItem item;
  final int chartRank;
}

/// Spotlight section: the top-ranked chart items as full-bleed editorial
/// hero cards.
///
/// - Narrow layouts: near-full-width snapping carousel with page dots.
/// - Wide layouts (>= [Breakpoints.mediumLarge]): the cards side by side.
class DiscoverSpotlightSection extends StatefulWidget {
  const DiscoverSpotlightSection({
    required this.entries,
    required this.onItemTap,
    required this.onItemSubscribe,
    required this.onItemPlay,
    required this.subscribingShowIds,
    required this.subscribedShowIds,
    super.key,
  });

  static const int maxItemCount = 3;
  static const double carouselViewportFraction = 0.90;
  static const double _neighborScale = 0.94;

  final List<DiscoverSpotlightEntry> entries;
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
  int _currentPage = 0;

  @override
  void dispose() {
    _carouselController?.dispose();
    super.dispose();
  }

  PageController _ensureCarouselController() {
    return _carouselController ??= PageController(
      viewportFraction: DiscoverSpotlightSection.carouselViewportFraction,
    )..addListener(_onCarouselPageChanged);
  }

  void _onCarouselPageChanged() {
    final controller = _carouselController;
    if (controller == null || !controller.hasClients) return;
    final page = controller.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

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
              return _SpotlightEntrance(
                child: Row(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index != 0) SizedBox(width: context.spacing.sm),
                      Expanded(child: _buildCard(index, isWide: true)),
                    ],
                  ],
                ),
              );
            }
            return _SpotlightEntrance(
              child: Column(
                children: [
                  SizedBox(
                    height: DiscoverSpotlightCard.cardHeight,
                    child: PageView.builder(
                      key: const Key('podcast_discover_spotlight_carousel'),
                      controller: _ensureCarouselController(),
                      itemCount: entries.length,
                      physics: const PageScrollPhysics(),
                      itemBuilder: (context, index) {
                        final card = Padding(
                          padding: EdgeInsetsDirectional.only(
                            start:
                                index == 0 ? context.spacing.xs : context.spacing.xxs,
                            end: context.spacing.xs,
                          ),
                          child: _buildCard(index),
                        );
                        // Neighbors settle slightly smaller — a depth cue
                        // that also reads as page progress.
                        return AnimatedBuilder(
                          animation: _ensureCarouselController(),
                          builder: (context, child) {
                            final controller = _carouselController;
                            var scale = 1.0;
                            if (controller != null &&
                                controller.hasClients &&
                                controller.position.haveDimensions) {
                              final page = controller.page ?? 0.0;
                              final neighborScale =
                                  DiscoverSpotlightSection._neighborScale;
                              scale =
                                  (1 - (page - index).abs() * (1 - neighborScale))
                                      .clamp(neighborScale, 1.0);
                            }
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: card,
                        );
                      },
                    ),
                  ),
                  if (entries.length > 1) ...[
                    SizedBox(height: context.spacing.sm),
                    _SpotlightPageDots(
                      count: entries.length,
                      current: _currentPage.clamp(0, entries.length - 1),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(int index, {bool isWide = false}) {
    final entry = widget.entries[index];
    final item = entry.item;
    final itunesId = item.itunesId;
    return DiscoverSpotlightCard(
      chartRank: entry.chartRank,
      item: item,
      onTap: () => widget.onItemTap(item),
      onPrimaryAction: item.isPodcastShow
          ? () => widget.onItemSubscribe(item)
          : () => widget.onItemPlay(item),
      isActing: itunesId != null && widget.subscribingShowIds.contains(itunesId),
      isDone: itunesId != null && widget.subscribedShowIds.contains(itunesId),
      isWide: isWide,
    );
  }
}

/// One-shot fade-and-rise entrance shared by the spotlight layouts.
class _SpotlightEntrance extends StatefulWidget {
  const _SpotlightEntrance({required this.child});

  final Widget child;

  @override
  State<_SpotlightEntrance> createState() => _SpotlightEntranceState();
}

class _SpotlightEntranceState extends State<_SpotlightEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: AppDurations.entranceNormal,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.03),
        duration: AppDurations.entranceNormal,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Page dots for the spotlight carousel: solid dot for the current page.
class _SpotlightPageDots extends StatelessWidget {
  const _SpotlightPageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('podcast_discover_spotlight_dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index != 0) SizedBox(width: context.spacing.sm),
          AnimatedContainer(
            duration: AppDurations.transitionFast,
            curve: Curves.easeOutCubic,
            width: current == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: current == index ? 0.7 : 0.2,
              ),
              borderRadius: AppRadius.pillRadius,
            ),
          ),
        ],
      ],
    );
  }
}
