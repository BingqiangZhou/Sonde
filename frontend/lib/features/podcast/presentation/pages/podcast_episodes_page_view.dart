part of 'podcast_episodes_page.dart';

extension _PodcastEpisodesPageView on _PodcastEpisodesPageState {
  Widget _buildHeaderCover(String? fallbackImageUrl) {
    final extension = appThemeOf(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(extension.itemRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(extension.itemRadius),
        child: Builder(
          builder: (context) {
            final sub = widget.subscription;
            if (sub?.imageUrl != null) {
              return PodcastImageWidget(
                imageUrl: sub!.imageUrl,
                width: 32,
                height: 32,
                iconSize: 20,
                iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }
            if (fallbackImageUrl != null) {
              return PodcastImageWidget(
                imageUrl: fallbackImageUrl,
                width: 32,
                height: 32,
                iconSize: 20,
                iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }
            return Icon(
              Icons.podcasts,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildHeaderActions(AppLocalizations l10n) {
    return [
      IconButton(
        icon: _isReparsing
            ? SizedBox(
                width: context.spacing.mdLg,
                height: context.spacing.mdLg,
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      child: const CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    );
                  },
                ),
              )
            : const Icon(Icons.refresh),
        onPressed: _isReparsing ? null : _reparseSubscription,
        tooltip: l10n.podcast_reparse_tooltip,
      ),
      if (MediaQuery.sizeOf(context).width < Breakpoints.compact)
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
          tooltip: l10n.filter,
        ),
    ];
  }

  /// Mobile layout: SliverList.builder with episode cards.
  Widget _buildMobileSlivers(PodcastEpisodesState episodesState) {
    final itemCount =
        episodesState.episodes.length + (episodesState.isLoadingMore ? 1 : 0);
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == episodesState.episodes.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.md),
              child: const CircularProgressIndicator.adaptive(),
            ),
          );
        }
        final episode = episodesState.episodes[index];
        return _buildEpisodeCard(episode);
      },
    );
  }

  /// Desktop layout: SliverGrid with episode cards.
  Widget _buildDesktopSlivers(
    PodcastEpisodesState episodesState,
    double width,
  ) {
    final itemCount =
        episodesState.episodes.length + (episodesState.isLoadingMore ? 1 : 0);
    final crossAxisCount =
        width < Breakpoints.mediumLarge ? 2 : (width < Breakpoints.large ? 3 : 4);
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.smMd,
        mainAxisSpacing: AppSpacing.smMd,
        mainAxisExtent: _PodcastEpisodesPageState._desktopEpisodeCardHeight,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == episodesState.episodes.length) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final episode = episodesState.episodes[index];
          return _buildEpisodeCard(episode);
        },
        childCount: itemCount,
      ),
    );
  }

  Widget _buildEpisodeCard(PodcastEpisodeModel episode) {
    return SimplifiedEpisodeCard(
      episode: episode,
      onTap: () => context.push('/podcast/episode/detail/${episode.id}'),
    );
  }

  Widget _buildEmptyState() {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.headphones_outlined,
      title: _showOnlyWithSummary
          ? l10n.podcast_no_episodes_with_summary
          : l10n.podcast_no_episodes,
      subtitle: _showOnlyWithSummary
          ? l10n.podcast_try_adjusting_filters
          : l10n.podcast_no_episodes_yet,
    );
  }

  Widget _buildFilterChips() {
    final l10n = context.l10n;
    if (PlatformHelper.isApple(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildPillButton(l10n.podcast_filter_all, !_showOnlyWithSummary, () {
            if (!_showOnlyWithSummary) return;
            _applyViewState(() {
              _showOnlyWithSummary = false;
            });
            _refreshEpisodes();
          }),
          SizedBox(width: context.spacing.sm),
          _buildPillButton(l10n.podcast_filter_with_summary, _showOnlyWithSummary, () {
            _applyViewState(() {
              _showOnlyWithSummary = !_showOnlyWithSummary;
            });
            _refreshEpisodes();
          }),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilterChip(
          label: Text(l10n.podcast_filter_all),
          selected: !_showOnlyWithSummary,
          onSelected: (selected) {
            if (!_showOnlyWithSummary) return;
            _applyViewState(() {
              _showOnlyWithSummary = false;
            });
            _refreshEpisodes();
          },
        ),
        SizedBox(width: context.spacing.sm),
        FilterChip(
          label: Text(l10n.podcast_filter_with_summary),
          selected: _showOnlyWithSummary,
          onSelected: (selected) {
            _applyViewState(() {
              _showOnlyWithSummary = selected;
            });
            _refreshEpisodes();
          },
          avatar: _showOnlyWithSummary
              ? const Icon(Icons.summarize, size: 16)
              : null,
        ),
      ],
    );
  }

  Widget _buildPillButton(String label, bool isSelected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgXlRadius,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(
            isSelected ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(height: context.spacing.md),
          Text(
            l10n.podcast_failed_load_episodes,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacing.xl),
          AdaptiveButton(
            onPressed: _refreshEpisodes,
            icon: const Icon(Icons.refresh),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final previousShowOnlySummary = _showOnlyWithSummary;
    final l10n = context.l10n;
    showAppDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog.adaptive(
          backgroundColor: Colors.transparent,
          title: Text(l10n.podcast_filter_episodes),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (PlatformHelper.isApple(context))
                AdaptiveListTile(
                  leading: const AdaptiveSwitch(
                    value: false,
                    onChanged: null,
                  ),
                  title: Text(l10n.podcast_only_with_summary),
                  trailing: AdaptiveSwitch(
                    value: _showOnlyWithSummary,
                    semanticLabel: l10n.podcast_only_with_summary,
                    onChanged: (value) {
                      setDialogState(() {
                        _showOnlyWithSummary = value;
                      });
                    },
                  ),
                )
              else
                CheckboxListTile(
                  title: Text(l10n.podcast_only_with_summary),
                  value: _showOnlyWithSummary,
                  onChanged: (value) {
                    setDialogState(() {
                      _showOnlyWithSummary = value!;
                    });
                  },
                ),
            ],
          ),
          actions: [
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () {
                _showOnlyWithSummary = previousShowOnlySummary;
                Navigator.of(context).pop();
              },
              child: Text(l10n.cancel),
            ),
            AdaptiveButton(
              style: AdaptiveButtonStyle.text,
              onPressed: () {
                Navigator.of(context).pop();
                _applyViewState(() {});
                _refreshEpisodes();
              },
              child: Text(l10n.podcast_apply),
            ),
          ],
        ),
      ),
    );
  }
}
