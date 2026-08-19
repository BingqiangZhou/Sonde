part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageContent on _PodcastEpisodeDetailPageState {
  Widget _buildTabSurface(Widget child, {Key? key}) {
    final tokens = appThemeOf(context);
    final theme = Theme.of(context);

    return SurfacePanel(
      key: key,
      padding: EdgeInsets.zero,
      borderRadius: tokens.cardRadius,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.22),
      showBorder: false,
      child: child,
    );
  }

  Widget _buildPageLoadingState(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SizedBox(),
        Center(
          child: LoadingStatusContent(
            key: const Key('podcast_episode_detail_loading_content'),
            title:
                (AppLocalizations.of(context) ?? AppLocalizationsEn()).loading,
            spinnerSize: 36,
            gapAfterSpinner: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabWidget(PodcastEpisodeModel episode, int index) {
    switch (index) {
      case 0:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildSummaryTabContent(episode);
      default:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
    }
  }

  Widget _buildTranscriptContent(PodcastEpisodeModel episode) {
    final tProvider = transcriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(tProvider);

    return transcriptionState.when(
      data: (transcription) {
        if (transcription != null && isTranscriptionCompleted(transcription)) {
          return TranscriptDisplayWidget(
            key: _transcriptKey,
            transcription: transcription,
          );
        }

        return TranscriptionStatusWidget(
          episodeId: widget.episodeId,
          transcription: transcription,
        );
      },
      loading: () => _buildCenteredLoadingState(
        (AppLocalizations.of(context) ?? AppLocalizationsEn()).loading,
      ),
      error: (error, stack) => _buildTranscriptErrorState(context, error),
    );
  }

  Widget _buildSummaryTabContent(PodcastEpisodeModel episode) {
    final isCompact =
        MediaQuery.sizeOf(context).width < Breakpoints.medium;

    return ScrollableContentWrapper(
      key: _summaryKey,
      padding: EdgeInsets.all(isCompact ? AppSpacing.mdXs : AppSpacing.mdSm),
      child: _buildAiSummarySection(episode, compact: isCompact),
    );
  }

  Widget _buildCenteredLoadingState(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          SizedBox(height: context.spacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptErrorState(BuildContext context, dynamic error) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_transcription_failed,
      subtitle: error.toString(),
    );
  }

  Widget _buildAiSummarySection(
    PodcastEpisodeModel episode, {
    bool compact = false,
  }) {
    final provider = summaryProvider(widget.episodeId);
    final summaryState = ref.watch(provider);
    final summaryNotifier = ref.read(provider.notifier);
    final tProvider = transcriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(tProvider);

    final episodeTranscript = episode.transcriptContent;
    final hasEpisodeTranscript =
        episodeTranscript != null && episodeTranscript.isNotEmpty;

    final loadedTranscript = transcriptionState.value?.transcriptContent;
    final hasLoadedTranscript =
        loadedTranscript != null && loadedTranscript.isNotEmpty;

    final episodeSummary = episode.aiSummary;
    final hasExistingSummary =
        summaryState.hasSummary ||
        (episodeSummary != null && episodeSummary.isNotEmpty);
    final canManageSummary =
        hasEpisodeTranscript || hasLoadedTranscript || hasExistingSummary;

    if (episodeSummary != null &&
        episodeSummary.isNotEmpty &&
        !summaryState.hasSummary &&
        !summaryState.isLoading &&
        !_summaryUpdateScheduled) {
      _summaryUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _summaryUpdateScheduled = false;
        if (mounted) {
          summaryNotifier.updateSummary(
            episodeSummary,
            modelUsed: episode.summaryModelUsed,
            processingTime: episode.summaryProcessingTime,
          );
        }
      });
    }

    final episodeSummaryFailure = HtmlSanitizer.detectFailureReason(
      episode.aiSummary,
    );
    final sanitizedEpisodeSummary =
        !summaryState.hidePersistedSummary && episodeSummaryFailure == null
        ? HtmlSanitizer.cleanModelReasoning(episode.aiSummary)
        : '';

    return Column(
      key: const Key('podcast_episode_detail_summary_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AISummaryControlWidget(
          episodeId: widget.episodeId,
          hasTranscript: canManageSummary,
          compact: compact,
        ),
        SizedBox(height: context.spacing.md),
        if (summaryState.isLoading &&
            !summaryState.hasSummary &&
            sanitizedEpisodeSummary.isEmpty)
          _buildCenteredLoadingState(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_generating_summary,
          )
        else if (summaryState.hasSummary)
          SummaryDisplayWidget(
            summary: summaryState.summary!,
            compact: compact,
            useInternalScrolling: false,
          )
        else if (episodeSummaryFailure != null)
          _buildAiSummaryErrorState(context, episodeSummaryFailure)
        else if (sanitizedEpisodeSummary.isNotEmpty)
          SummaryDisplayWidget(
            summary: sanitizedEpisodeSummary,
            compact: compact,
            useInternalScrolling: false,
          )
        else
          _buildAiSummaryEmptyState(context),
        if (summaryState.isLoading &&
            (summaryState.hasSummary ||
                sanitizedEpisodeSummary.isNotEmpty)) ...[
          SizedBox(height: context.spacing.smMd),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildAiSummaryErrorState(BuildContext context, String message) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_transcription_failed,
      subtitle: message,
    );
  }

  Widget _buildAiSummaryEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return AppEmptyState(
      icon: Icons.auto_awesome,
      title: l10n.podcast_summary_no_summary,
      subtitle: l10n.podcast_summary_empty_hint,
    );
  }

  Widget _buildErrorState(BuildContext context, dynamic error) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Stack(
      fit: StackFit.expand,
      children: [
        const SizedBox(),
        Center(
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: l10n.podcast_error_loading,
            subtitle: error.toString(),
            action: FilledButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: Text(l10n.podcast_go_back),
            ),
          ),
        ),
      ],
    );
  }
}
