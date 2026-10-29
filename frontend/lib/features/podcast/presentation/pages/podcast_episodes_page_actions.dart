part of 'podcast_episodes_page.dart';

extension _PodcastEpisodesPageActions on _PodcastEpisodesPageState {
  void _setupInfiniteScrollListener() {
    _scrollController.addListener(() {
      const preloadThresholdPx = 240.0;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) return;
      final remaining = position.maxScrollExtent - position.pixels;
      if (remaining > preloadThresholdPx) return;

      final episodesState = ref.read(podcastEpisodesProvider);
      if (episodesState.isLoadingMore || !episodesState.hasMore) return;

      ref
          .read(podcastEpisodesProvider.notifier)
          .loadMoreEpisodesForSubscription(
            subscriptionId: widget.subscriptionId,
            hasSummary: _hasSummaryFilter,
          );
    });
  }

  Future<void> _loadEpisodesForSubscription({bool forceRefresh = false}) async {
    logger.AppLogger.debug(
      '[Episodes] Loading episodes for subscription: ${widget.subscriptionId}',
    );
    try {
      await ref
          .read(podcastEpisodesProvider.notifier)
          .loadEpisodesForSubscription(
            subscriptionId: widget.subscriptionId,
            hasSummary: _hasSummaryFilter,
            forceRefresh: forceRefresh,
          );
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.podcast_failed_load_episodes,
          isError: true,
        );
      }
    }
  }

  Future<void> _refreshEpisodes() async {
    await ref
        .read(podcastEpisodesProvider.notifier)
        .refreshEpisodesForSubscription(
          subscriptionId: widget.subscriptionId,
          hasSummary: _hasSummaryFilter,
        );
  }

  Future<void> _reparseSubscription() async {
    if (_isReparsing) return; // Ignore repeated taps while reparsing.

    _applyViewState(() {
      _isReparsing = true;
    });

    final l10n = context.l10n;

    try {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparsing,
          extraTopOffset: 72,
        );
      }

      await ref.read(podcastSubscriptionProvider.notifier).reparseSubscription(
            widget.subscriptionId,
            true,
          );

      await _refreshEpisodes();

      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparse_completed,
          extraTopOffset: 72,
        );
      }
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: '${l10n.podcast_reparse_failed} $error',
          isError: true,
          extraTopOffset: 72,
        );
      }
    } finally {
      if (mounted) {
        _applyViewState(() {
          _isReparsing = false;
        });
      }
    }
  }
}
