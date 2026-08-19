part of 'podcast_bottom_player_widget.dart';

class _ReservedBottomBackground extends StatelessWidget {
  const _ReservedBottomBackground({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.20 : 0.28,
      ),
      theme.scaffoldBackgroundColor,
    );

    return IgnorePointer(
      child: SizedBox(
        key: const Key('podcast_player_reserved_background'),
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: baseColor),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    baseColor.withValues(alpha: 0),
                    baseColor.withValues(alpha: 0.52),
                    baseColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastMiniDock extends ConsumerWidget {
  const _PodcastMiniDock({
    required this.episode,
    required this.viewportSpec,
    required this.applySafeArea,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final content = Padding(
      key: const Key('podcast_bottom_player_mini_wrapper'),
      padding: EdgeInsets.fromLTRB(
        viewportSpec.dockHorizontalPadding,
        viewportSpec.dockTopPadding,
        viewportSpec.dockHorizontalPadding,
        viewportSpec.dockBottomSpacing,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: viewportSpec.dockMaxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgRadius,
              boxShadow: [appThemeOf(context).shadowLg],
            ),
            child: Material(
              key: const Key('podcast_bottom_player_mini'),
              color: Colors.transparent,
              borderRadius: AppRadius.lgRadius,
              clipBehavior: Clip.antiAlias,
              child: _MiniDockBody(
                episode: episode,
                onExpand: () => _openExpandedPlayer(ref),
                showPrimaryKeys: true,
                pauseTooltip: l10n.podcast_player_pause,
                playTooltip: l10n.podcast_player_play,
                listTooltip: l10n.podcast_player_list,
              ),
            ),
          ),
        ),
      ),
    );

    if (!applySafeArea) {
      return content;
    }
    return SafeArea(top: false, child: content);
  }
}

class _MiniDockBody extends ConsumerWidget {
  const _MiniDockBody({
    required this.episode,
    required this.onExpand,
    required this.showPrimaryKeys,
    required this.pauseTooltip,
    required this.playTooltip,
    required this.listTooltip,
  });

  final PodcastEpisodeModel episode;
  final VoidCallback onExpand;
  final bool showPrimaryKeys;
  final String pauseTooltip;
  final String playTooltip;
  final String listTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.smMd, context.spacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.player_expand_player,
            child: GestureDetector(
              onTap: onExpand,
              child: RepaintBoundary(
                child: _CoverImage(
                  imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
                  size: 48,
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Semantics(
              button: true,
              label: episode.title,
              child: GestureDetector(
              key: showPrimaryKeys
                  ? const Key('podcast_bottom_player_mini_info')
                  : null,
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  // Isolate progress repaints (500ms ticks) from the rest of the dock.
                  RepaintBoundary(
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillRadius,
                            child: const _MiniProgressIndicator(),
                          ),
                        ),
                        SizedBox(width: context.spacing.sm),
                        const _MiniProgressText(),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          const _MiniPlayPauseButton(
            key: Key('podcast_bottom_player_mini_play_pause'),
          ),
          SizedBox(width: context.spacing.sm),
          // Queue button: isolated Consumer so the dock body does not
          // rebuild when queue-sheet state changes.
          Consumer(
            builder: (context, ref, _) {
              final queueSheetOpen =
                  ref.watch(podcastPlayerQueueSheetOpenProvider);
              return IconButton(
                key: showPrimaryKeys
                    ? const Key('podcast_bottom_player_mini_playlist')
                    : const ValueKey(
                        'podcast_bottom_player_mini_playlist_overlay',
                      ),
                tooltip: listTooltip,
                onPressed: queueSheetOpen
                    ? null
                    : () => _showQueueSheet(context, ref),
                icon: Icon(Icons.playlist_play_rounded, color: theme.colorScheme.onSurface),
                iconSize: 24,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PodcastExpandedOverlay extends ConsumerWidget {
  const _PodcastExpandedOverlay({
    required this.episode,
    required this.viewportSpec,
    required this.visible,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final maxContentWidth = math.min(
      mediaSize.width - (viewportSpec.dockHorizontalPadding * 2),
      viewportSpec.layoutMode == PodcastPlayerLayoutMode.mobile
          ? double.infinity
          : 720.0,
    );

    // Full-screen player page: the surface fills the whole viewport and the
    // content column is only width-constrained (centered) on tablet/desktop.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: _kPlayerTransition,
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.08),
        child: AnimatedOpacity(
          duration: _kPlayerTransition,
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: Container(
            key: visible ? const Key('podcast_player_mobile_sheet') : null,
            color: theme.colorScheme.surfaceContainerHighest,
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ArtworkBackdrop(
                  imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContentWidth,
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: _ExpandedPanelContent(
                          episode: episode,
                          showPrimaryKeys: visible,
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
}

/// Blurred, dimmed full-bleed artwork behind the full-screen player page.
class _ArtworkBackdrop extends StatelessWidget {
  const _ArtworkBackdrop({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final veilAlpha = theme.brightness == Brightness.dark ? 0.84 : 0.9;
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Oversize the image so the blur does not fade at the edges.
            final width = constraints.maxWidth * 1.4;
            final height = constraints.maxHeight * 1.4;
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 56,
                      sigmaY: 56,
                      tileMode: TileMode.decal,
                    ),
                    child: Center(
                      child: PodcastImageWidget(
                        imageUrl: imageUrl,
                        width: width,
                        height: height,
                        iconSize: 160,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: veilAlpha),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExpandedPanelContent extends StatelessWidget {
  const _ExpandedPanelContent({
    required this.episode,
    required this.showPrimaryKeys,
  });

  final PodcastEpisodeModel episode;
  final bool showPrimaryKeys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.md, context.spacing.md),
      child: Column(
        key: showPrimaryKeys
            ? const Key('podcast_bottom_player_expanded')
            : null,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Semantics(
              hint: 'Drag to collapse player',
              child: GestureDetector(
                key: showPrimaryKeys
                    ? const Key('podcast_bottom_player_drag_handle')
                    : null,
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (_) => ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(podcastPlayerUiProvider.notifier).collapse(),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: AppRadius.pillRadius,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: context.spacing.xs),
          const _ExpandedTopBar(),
          // The artwork + title block floats in the space between the top
          // bar and the bottom-anchored progress + transport controls.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artworkSize = [
                  constraints.maxWidth * 0.78,
                  constraints.maxHeight * 0.58,
                  360.0,
                ].reduce(math.min).clamp(160.0, 360.0);
                return _ExpandedHero(episode: episode, artworkSize: artworkSize);
              },
            ),
          ),
          const _ExpandedProgressSection(),
          SizedBox(height: context.spacing.md),
          const RepaintBoundary(
            child: _TransportRow(),
          ),
          SizedBox(height: context.spacing.md),
          const _ExpandedSecondaryActions(),
        ],
      ),
    );
  }
}

class _ExpandedTopBar extends ConsumerWidget {
  const _ExpandedTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: const Key('podcast_bottom_player_collapse'),
          tooltip: l10n.podcast_player_collapse,
          onPressed: () =>
              ref.read(podcastPlayerUiProvider.notifier).collapse(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          iconSize: 30,
        ),
        Expanded(
          child: Center(
            child: Text(
              l10n.podcast_player_now_playing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        _SleepTimerButton(onPressed: () => _showSleepSelector(context, ref)),
      ],
    );
  }
}

class _ExpandedHero extends StatelessWidget {
  const _ExpandedHero({required this.episode, required this.artworkSize});

  final PodcastEpisodeModel episode;
  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        key: const Key('podcast_bottom_player_expanded_hero'),
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: _HeroArtwork(
              imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
              size: artworkSize,
            ),
          ),
          SizedBox(height: context.spacing.lg),
          Semantics(
            button: true,
            hint: 'View episode details',
            child: GestureDetector(
              key: const Key('podcast_bottom_player_expanded_title'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final container = ProviderScope.containerOf(
                  context,
                  listen: false,
                );
                var resolvedCurrentLocation = container.read(
                  currentRouteProvider,
                );
                try {
                  resolvedCurrentLocation = GoRouterState.of(context).uri.toString();
                } catch (e) {
                  logger.AppLogger.debug('[BottomPlayer] Failed to get current route: $e');
                }
                // Compare the path only (query stripped) and exactly, so
                // episode 5 does not match episode 55 via a prefix check.
                final currentPath =
                    Uri.tryParse(resolvedCurrentLocation)?.path ??
                    resolvedCurrentLocation;
                if (currentPath == '/podcast/episode/detail/${episode.id}') {
                  return;
                }
                PodcastNavigation.goToEpisodeDetail(
                  context,
                  episodeId: episode.id,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key: const Key('podcast_bottom_player_expanded_title_text'),
                    episode.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    key: const Key('podcast_bottom_player_expanded_meta'),
                    _buildEpisodeMetaLine(episode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildEpisodeMetaLine(PodcastEpisodeModel episode) {
    final subscriptionTitle = episode.subscriptionTitle;
    final trimmedTitle = subscriptionTitle?.trim();
    final parts = <String>[
      if (trimmedTitle != null && trimmedTitle.isNotEmpty) trimmedTitle,
      episode.publishedAt.toString().split(' ')[0],
      episode.formattedDuration,
    ];
    return parts.join('  ·  ');
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('podcast_bottom_player_expanded_cover'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.xxlRadius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xxlRadius,
        child: PodcastImageWidget(
          imageUrl: imageUrl,
          width: size,
          height: size,
          iconSize: size * 0.32,
        ),
      ),
    );
  }
}

class _ExpandedProgressSection extends ConsumerStatefulWidget {
  const _ExpandedProgressSection();

  @override
  ConsumerState<_ExpandedProgressSection> createState() =>
      _ExpandedProgressSectionState();
}

class _ExpandedProgressSectionState
    extends ConsumerState<_ExpandedProgressSection> {
  bool _isScrubbing = false;
  int _draftPositionMs = 0;

  void _startScrub(double value) {
    setState(() {
      _isScrubbing = true;
      _draftPositionMs = value.round();
    });
  }

  void _updateScrub(double value) {
    setState(() {
      _draftPositionMs = value.round();
    });
  }

  Future<void> _finishScrub(double value) async {
    final targetPosition = value.round();
    setState(() {
      _draftPositionMs = targetPosition;
    });
    await ref.read(audioPlayerProvider.notifier).seekTo(targetPosition);
    if (!mounted) {
      return;
    }
    setState(() {
      _isScrubbing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(audioMiniProgressProvider);
    final durationMs = progress.durationMs > 0 ? progress.durationMs : 1;
    final effectivePositionMs = _isScrubbing
        ? _draftPositionMs.clamp(0, durationMs)
        : progress.positionMs;

    return Column(
      key: const Key('podcast_bottom_player_expanded_progress'),
      children: [
        RepaintBoundary(
          child: SliderTheme(
            data: theme.sliderTheme.copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.transparent,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider.adaptive(
              key: const Key('podcast_bottom_player_progress_slider'),
              value: effectivePositionMs.clamp(0, durationMs).toDouble(),
              max: durationMs.toDouble(),
              onChangeStart: _startScrub,
              onChanged: _updateScrub,
              onChangeEnd: _finishScrub,
            ),
          ),
        ),
        RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMilliseconds(effectivePositionMs),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatMilliseconds(progress.durationMs),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
