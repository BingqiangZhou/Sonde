part of 'podcast_episode_detail_page.dart';

const double _artworkBorderRadiusWide = 18;
const double _artworkBorderRadiusCompact = 10;

extension _PodcastEpisodeDetailPageHeader on _PodcastEpisodeDetailPageState {
  bool get _isCompactPhoneLayout =>
      MediaQuery.sizeOf(context).width < Breakpoints.medium;

  HeaderCapsuleActionButtonDensity get _buttonDensity =>
      _isCompactPhoneLayout
          ? HeaderCapsuleActionButtonDensity.compact
          : HeaderCapsuleActionButtonDensity.regular;

  Widget _buildHeader(PodcastEpisodeModel episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: AppDurations.navigationTransition,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildHeroHeaderCard(
            episode,
            isWide: false,
            key: ValueKey(
              'podcast_episode_detail_mobile_hero_$isExpanded',
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedHeader(PodcastEpisodeModel episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: AppDurations.navigationTransition,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildHeroHeaderCard(
            episode,
            isWide: true,
            key: ValueKey(
              'podcast_episode_detail_wide_hero_$isExpanded',
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeaderCard(
    PodcastEpisodeModel episode, {
    required bool isWide,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final theme = Theme.of(context);
    final metadata = <Widget>[
      _buildPodcastTitleChip(episode, l10n),
      _buildDateChip(episode),
      if (episode.audioDuration != null) _buildDurationChip(episode),
      if (episode.itemLink != null && episode.itemLink!.trim().isNotEmpty)
        _buildSourceLinkChip(episode, l10n),
      if (episode.episodeNumber != null)
        StatusBadge(
          label: l10n.podcast_episode_number(episode.episodeNumber!),
          icon: Icons.radio_outlined,
        ),
      if (episode.explicit)
        StatusBadge(
          label: l10n.podcast_explicit_label,
          icon: Icons.explicit_outlined,
          color: theme.colorScheme.tertiary,
        ),
    ];

    if (isWide) {
      return SurfacePanel(
        key: key,
        padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.mdLg, context.spacing.md, context.spacing.mdLg),
        child: Row(
          children: [
            _buildHeroArtwork(episode, isWide: true),
            SizedBox(width: context.spacing.mdLg),
            Expanded(
              child: Column(
                key: const Key('podcast_episode_detail_wide_hero_content'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    key: const Key('podcast_episode_detail_hero_metadata_row'),
                    spacing: context.spacing.sm,
                    runSpacing: context.spacing.smMd,
                    children: metadata.whereType<Widget>().toList(
                      growable: false,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.mdLg),
            _buildWideHeaderActionColumn(episode),
          ],
        ),
      );
    }

    final mobileMetadata = _buildCompactHeaderMetadataText(
      publishedAt: episode.publishedAt,
      durationMilliseconds: episode.audioDuration == null
          ? null
          : episode.audioDuration! * 1000,
    );

    return Row(
      key: key,
      children: [
        _buildHeroArtwork(episode, isWide: false),
        SizedBox(width: context.spacing.smMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mobileMetadata,
                key: const Key(
                  'podcast_episode_detail_mobile_hero_metadata',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.spacing.xs),
        _buildFavoriteButton(episode),
        SizedBox(width: context.spacing.xs),
        _buildShareButton(episode),
        if (episode.itemLink != null &&
            episode.itemLink!.trim().isNotEmpty) ...[
          SizedBox(width: context.spacing.xs),
          _buildSourceLinkIconButton(episode, l10n),
        ],
      ],
    );
  }

  Widget _buildHeroArtwork(
    PodcastEpisodeModel episode, {
    required bool isWide,
  }) {
    final size = isWide ? 76.0 : 44.0;
    final borderRadius = BorderRadius.circular(
      isWide ? _artworkBorderRadiusWide : _artworkBorderRadiusCompact,
    );
    return Hero(
      tag: 'episode_cover_${episode.id}',
      child: Container(
        key: Key(
          isWide
              ? 'podcast_episode_detail_wide_hero_artwork'
              : 'podcast_episode_detail_mobile_hero_artwork',
        ),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: PodcastImageWidget(
            imageUrl: episode.imageUrl,
            fallbackImageUrl: episode.subscriptionImageUrl,
            width: size,
            height: size,
            iconSize: size * 0.32,
          ),
        ),
      ),
    );
  }

  Widget _buildWideHeaderActionColumn(PodcastEpisodeModel episode) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 124, maxWidth: 168),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.xs,
            alignment: WrapAlignment.end,
            children: [
              _buildFavoriteButton(episode),
              _buildShareButton(episode),
            ],
          ),
        ],
      ),
    );
  }

  String _resolvePodcastTitle(
    PodcastEpisodeModel episode,
    AppLocalizations l10n,
  ) {
    final subscription = episode.subscription;
    final candidates = <dynamic>[
      subscription?['title'],
      subscription?['name'],
      subscription?['podcast_title'],
      episode.metadata?['podcast_title'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return l10n.podcast_default_podcast;
  }

  Widget _buildPodcastTitleChip(
    PodcastEpisodeModel episode,
    AppLocalizations l10n,
  ) {
    return StatusBadge(
      key: const Key('podcast_episode_detail_podcast_title_chip'),
      label: _resolvePodcastTitle(episode, l10n),
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildMetadataActionBadge({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onTap, Color? color,
    bool iconOnly = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;

    return Tooltip(
      message: label,
      child: Material(
        key: key,
        color: resolvedColor.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pillRadius,
          side: BorderSide(color: resolvedColor.withValues(alpha: 0.18)),
        ),
        child: AdaptiveInkWell(
          borderRadius: AppRadius.pillRadius,
          onTap: onTap,
          child: iconOnly
              ? SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: Icon(icon, size: 13, color: resolvedColor),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: context.spacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: resolvedColor),
                      SizedBox(width: context.spacing.xs),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: resolvedColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _buildCompactHeaderMetadataText({
    required DateTime publishedAt,
    required int? durationMilliseconds,
  }) {
    final segments = <String>[EpisodeCardUtils.formatDate(publishedAt)];
    if (durationMilliseconds != null) {
      segments.add(_formatDurationLabel(durationMilliseconds));
    }
    return segments.join(' / ');
  }

  Future<void> _launchEpisodeSource(
    PodcastEpisodeModel episode,
  ) async {
    final itemLink = episode.itemLink;
    if (itemLink == null || itemLink.trim().isEmpty) {
      return;
    }

    final linkUri = Uri.tryParse(itemLink);
    if (linkUri == null) {
      return;
    }

    if (await canLaunchUrl(linkUri)) {
      await launchUrl(linkUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDateChip(PodcastEpisodeModel episode) {
    return StatusBadge(
      label: EpisodeCardUtils.formatDate(episode.publishedAt),
      icon: Icons.calendar_today_outlined,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  Widget _buildDurationChip(PodcastEpisodeModel episode) {
    final durationSeconds = episode.audioDuration ?? 0;
    return StatusBadge(
      label: _formatDurationLabel(durationSeconds * 1000),
      icon: Icons.schedule_outlined,
      color: Theme.of(context).colorScheme.tertiary,
    );
  }

  Widget _buildSourceLinkChip(
    PodcastEpisodeModel episode,
    AppLocalizations l10n, {
    bool iconOnly = false,
  }) {
    return _buildMetadataActionBadge(
      key: const Key('podcast_episode_detail_source_button'),
      label: l10n.podcast_source,
      icon: Icons.link_rounded,
      color: Theme.of(context).colorScheme.secondary,
      iconOnly: iconOnly,
      onTap: () {
        unawaited(_launchEpisodeSource(episode));
      },
    );
  }

  String _formatDurationLabel(int milliseconds) {
    return TimeFormatter.formatDuration(
      Duration(milliseconds: milliseconds),
      padHours: false,
    );
  }
  Widget _buildFavoriteButton(PodcastEpisodeModel episode) {
    final favorited = ref.watch(favoriteStatusProvider(episode.id)).value ?? false;
    return HeaderCapsuleActionButton(
      tooltip: favorited ? '取消收藏' : '收藏',
      icon: favorited ? Icons.star_rounded : Icons.star_outline_rounded,
      onPressed: () => toggleFavorite(
        ref: ref,
        episodeId: episode.id,
        current: favorited,
      ),
      circular: true,
      density: _buttonDensity,
    );
  }

  Widget _buildShareButton(PodcastEpisodeModel episode) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return HeaderCapsuleActionButton(
      tooltip: l10n.share,
      icon: Icons.adaptive.share,
      onPressed: () => _shareEpisode(episode),
      circular: true,
      density: _buttonDensity,
    );
  }

  Widget _buildSourceLinkIconButton(
    PodcastEpisodeModel episode,
    AppLocalizations l10n,
  ) {
    return HeaderCapsuleActionButton(
      tooltip: l10n.podcast_source,
      icon: Icons.link_rounded,
      onPressed: () => unawaited(_launchEpisodeSource(episode)),
      circular: true,
      density: _buttonDensity,
    );
  }

  Future<void> _shareEpisode(PodcastEpisodeModel episode) async {
    AdaptiveHaptic.mediumImpact();
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    // Generate a deep link to the episode
    // For now, use the audio URL as the shareable link
    // In production, this should be a proper deep link to the app
    final podcastName = _resolvePodcastTitle(episode, l10n);
    final shareUrl = episode.audioUrl;

    try {
      await AdaptiveShare.shareEpisode(
        title: episode.title,
        url: shareUrl,
        podcastName: podcastName,
        description: episode.description?.trim(),
      );
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_share_episode_failed(error.toString()),
          isError: true,
          extraTopOffset: 72,
        );
      }
    }
  }
}
