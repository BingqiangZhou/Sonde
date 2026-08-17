import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/panel_list_views.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class ProfileHistoryPage extends ConsumerStatefulWidget {
  const ProfileHistoryPage({super.key});

  @override
  ConsumerState<ProfileHistoryPage> createState() => _ProfileHistoryPageState();
}

class _ProfileHistoryPageState extends ConsumerState<ProfileHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final historyAsync = ref.watch(playbackHistoryLiteProvider);

    return PanelListPageScaffold(
      appBarTitle: l10n.profile_viewed_title,
      onRefresh: () => ref
          .read(playbackHistoryLiteProvider.notifier)
          .load(forceRefresh: true),
      slivers: [
        ...historyAsync.when(
          data: (response) {
            final episodes = response?.episodes ??
                const <PlaybackHistoryLiteItem>[];
            if (episodes.isEmpty) {
              return _buildEmptySlivers(context, l10n);
            }
            return _buildDataSlivers(
              context,
              l10n,
              episodes: episodes,
            );
          },
          loading: () => _buildLoadingSlivers(context, l10n),
          error: (error, _) => _buildErrorSlivers(context, l10n, error),
        ),
      ],
    );
  }

  List<Widget> _buildDataSlivers(
    BuildContext context,
    AppLocalizations l10n, {
    required List<PlaybackHistoryLiteItem> episodes,
  }) {
    return panelDataSlivers(
      context,
      title: context.l10n.profile_viewed_title,
      subtitle: context.l10n.profile_history_episode_count(episodes.length),
      hideTitle: true,
      headerPadding: _panelHeaderPadding(context),
      itemSlivers: [
        // List items
        SliverList.builder(
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return _buildHistoryCard(context, episode);
          },
        ),
      ],
    );
  }

  List<Widget> _buildEmptySlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_viewed_title,
        subtitle: l10n.profile_history_subtitle,
        headerPadding: _panelHeaderPadding(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: panelEmptyBody(
              context,
              icon: Icons.history,
              title: l10n.server_history_empty,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoadingSlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_viewed_title,
        subtitle: l10n.profile_history_subtitle,
        headerPadding: _panelHeaderPadding(context),
        bare: true,
        body: LoadingStatusContent(
          key: const Key('profile_history_loading_content'),
          title: l10n.loading,
          spinnerSize: 28,
          gapAfterSpinner: 12,
        ),
      ),
    );
  }

  List<Widget> _buildErrorSlivers(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.profile_viewed_title,
        subtitle: l10n.profile_history_subtitle,
        headerPadding: _panelHeaderPadding(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: panelErrorBody(
              context,
              message: error.toString(),
              retryLabel: l10n.retry,
              onRetry: () => ref.invalidate(playbackHistoryLiteProvider),
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsetsGeometry _panelHeaderPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      context.spacing.mdLg,
      context.spacing.mdLg,
      context.spacing.mdLg,
      context.spacing.smMd,
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    PlaybackHistoryLiteItem episode,
  ) {
    return RepaintBoundary(
      key: ValueKey('history_card_${episode.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.15)),
        ),
        child: Material(
          color: Colors.transparent,
          child: AdaptiveInkWell(
            onTap: () =>
                context.push('/podcast/episode/detail/${episode.id}'),
            borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
            child: SizedBox(
              key: ValueKey(
                  'profile_history_card_content_${episode.id}'),
              height: kPodcastRowCardTargetHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: kPodcastRowCardHorizontalPadding,
                  vertical: context.spacing.xsSm,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        appThemeOf(context).itemRadius,
                      ),
                      child: PodcastImageWidget(
                        imageUrl: episode.imageUrl,
                        fallbackImageUrl: episode.subscriptionImageUrl,
                        width: kPodcastRowCardImageSize,
                        height: kPodcastRowCardImageSize,
                        iconSize: context.spacing.lg,
                        iconColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: kPodcastRowCardHorizontalGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            key: ValueKey(
                              'profile_history_title_box_${episode.id}',
                            ),
                            height: context.spacing.mdLg +
                                context.spacing.md +
                                context.spacing.xs,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                key: ValueKey(
                                  'profile_history_title_${episode.id}',
                                ),
                                episode.title,
                                style: AppTextStyles.caption(
                                      Theme.of(context).colorScheme.onSurface,
                                    ).copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                strutStyle: StrutStyle(
                                  fontSize: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.fontSize ??
                                      13,
                                  height: 1.15,
                                  forceStrutHeight: true,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            key: const Key('profile_history_meta_row'),
                            height: context.spacing.mdLg,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 110,
                                      ),
                                      child: Container(
                                        key: const Key(
                                          'profile_history_meta_podcast',
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.spacing.sm,
                                          vertical: context.spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          borderRadius: AppRadius.mdRadius,
                                        ),
                                        child: Text(
                                          episode.subscriptionTitle ??
                                              AppLocalizations.of(
                                                context,
                                              )!.podcast_default_podcast,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.navLabel(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                                weight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: context.spacing.sm),
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: context.spacing.xs),
                                    Text(
                                      _formatPlayedAt(
                                          context, episode.lastPlayedAt),
                                      style: AppTextStyles.metaSmall(
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    SizedBox(width: context.spacing.sm),
                                    Icon(
                                      Icons.schedule,
                                      size: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: context.spacing.xs),
                                    Text(
                                      _buildProgressText(context, episode),
                                      style: AppTextStyles.metaSmall(
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPlayedAt(BuildContext context, DateTime? lastPlayedAt) =>
      lastPlayedAt == null
          ? context.l10n.not_available
          : TimeFormatter.formatFullDateTime(lastPlayedAt);

  String _buildProgressText(
    BuildContext context,
    PlaybackHistoryLiteItem episode,
  ) {
    final position = episode.playbackPosition ?? 0;
    final totalDuration = episode.audioDuration != null
        ? episode.formattedDuration
        : context.l10n.time_unknown;
    return '${_formatPlaybackPosition(context, position)} / $totalDuration';
  }

  String _formatPlaybackPosition(BuildContext context, int seconds) {
    final l10n = context.l10n;
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (duration.inHours > 0 || remainingSeconds > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    return l10n.player_minutes(minutes);
  }
}
