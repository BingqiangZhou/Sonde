import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/services/audio_download_service.dart';
import 'package:sonde/core/services/download_provider.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/shared/panel_list_views.dart';

/// Page for managing downloaded podcast episodes.
class PodcastDownloadsPage extends ConsumerStatefulWidget {
  const PodcastDownloadsPage({super.key});

  @override
  ConsumerState<PodcastDownloadsPage> createState() =>
      _PodcastDownloadsPageState();
}

class _PodcastDownloadsPageState extends ConsumerState<PodcastDownloadsPage> {
  final ScrollController _scrollController = ScrollController();

  static const double _bottomBufferForPlayer = 100;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asyncDownloads = ref.watch(downloadsListProvider);
    final grouped = ref.watch(groupedDownloadsProvider);

    final deleteButton = grouped.completed.isNotEmpty
        ? HeaderCapsuleActionButton(
            icon: Icons.delete_sweep,
            tooltip: l10n.downloads_delete_all,
            circular: true,
            onPressed: () =>
                _confirmDeleteAll(context, ref, grouped.completed),
          )
        : null;

    return PanelListPageScaffold(
      appBarTitle: l10n.downloads_page_title,
      appBarActions: [?deleteButton],
      scrollController: _scrollController,
      onRefresh: () async {
        ref.invalidate(downloadsListProvider);
      },
      slivers: [
        ...asyncDownloads.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return _buildEmptySlivers(context, l10n);
            }
            return _buildDataSlivers(context, grouped, l10n);
          },
          loading: () => _buildLoadingSlivers(context, l10n),
          error: (e, _) => _buildErrorSlivers(context, ref, l10n, e),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadTask> tasks,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: l10n.downloads_delete_confirm,
      message: l10n.downloads_delete_confirm_message,
      confirmText: l10n.downloads_delete_all,
      isDestructive: true,
    );
    if (confirmed != true) return;

    final service = ref.read(downloadManagerProvider);
    for (final task in tasks) {
      service.delete(task.episodeId);
    }
  }

  List<Widget> _buildEmptySlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.downloads_page_title,
        subtitle: l10n.downloads_empty,
        hideTitle: true,
        body: Padding(
          padding: EdgeInsets.all(context.spacing.mdLg),
          child: panelNoteBox(
            context,
            child: Center(
              child: panelEmptyBody(
                context,
                icon: Icons.download_outlined,
                iconSize: 48,
                gap: context.spacing.smMd,
                subtitle: l10n.downloads_empty_subtitle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDataSlivers(
    BuildContext context,
    GroupedDownloads grouped,
    AppLocalizations l10n,
  ) {
    final totalDownloads = grouped.active.length +
        grouped.failed.length +
        grouped.completed.length;

    final allTasks = [
      ...grouped.active,
      ...grouped.failed,
      ...grouped.completed,
    ];

    return panelDataSlivers(
      context,
      title: l10n.downloads_page_title,
      subtitle: l10n.downloads_items(totalDownloads),
      hideTitle: true,
      itemSlivers: [
        // List items
        SliverList.builder(
          itemCount: allTasks.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.sm,
                index == 0 ? context.spacing.sm : 0,
                context.spacing.sm,
                context.spacing.sm,
              ),
              child: _DownloadTaskCard(task: allTasks[index]),
            );
          },
        ),
      ],
      bottomBuffer: _bottomBufferForPlayer,
    );
  }

  List<Widget> _buildLoadingSlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.downloads_page_title,
        subtitle: l10n.loading,
        hideTitle: true,
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }

  List<Widget> _buildErrorSlivers(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Object error,
  ) {
    return panelStateSlivers(
      PanelStateView(
        title: l10n.downloads_page_title,
        subtitle: l10n.podcast_downloads_load_error,
        hideTitle: true,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: panelErrorBody(
              context,
              iconSize: 48,
              message: l10n.podcast_downloads_load_error,
              retryLabel: l10n.retry,
              onRetry: () => ref.invalidate(downloadsListProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final service = ref.read(downloadManagerProvider);
    final episodeAsync = ref.watch(episodeCacheMetaProvider(task.episodeId));

    final cached = episodeAsync.asData?.value;
    final apiAsync =
        cached == null ? ref.watch(episodeDetailProvider(task.episodeId)) : null;

    final episodeTitle = cached?.title ?? apiAsync?.asData?.value?.title;
    final podcastTitle = cached?.subscriptionTitle ??
        apiAsync?.asData?.value?.subscription?['title'] as String?;
    final imageUrl = cached?.subscriptionImageUrl ??
        cached?.imageUrl ??
        apiAsync?.asData?.value?.subscriptionImageUrl ??
        apiAsync?.asData?.value?.imageUrl;

    return AdaptiveDismissible(
      key: ValueKey(task.id),
      onDelete: () => service.delete(task.episodeId),
      child: Material(
        color: Colors.transparent,
        child: AdaptiveInkWell(
          borderRadius: AppRadius.xxlCardRadius,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.xxlCardRadius,
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
            ),
            padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.smMd, context.spacing.smMd),
            child: Row(
              children: [
                // Leading image or status icon
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      appThemeOf(context).itemRadius,
                    ),
                    child: PodcastImageWidget(
                      imageUrl: imageUrl,
                      width: 44,
                      height: 44,
                      iconSize: 22,
                    ),
                  )
                else
                  _StatusIcon(task: task),
                SizedBox(width: context.spacing.md), // icon-size, not spacing
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeTitle ?? l10n.podcast_episode_fallback_title(task.episodeId),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.spacing.xs),
                      if (podcastTitle != null) ...[
                        Text(
                          podcastTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.spacing.xs / 2),
                      ],
                      if (task.status == DownloadStatus.downloading)
                        LinearProgressIndicator(value: task.progress)
                      else
                        Text(
                          _statusText(task, l10n),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Trailing action
                if (_trailingIcon(task) != null) ...[
                  SizedBox(width: context.spacing.sm),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: Icon(_trailingIcon(task), size: 18),
                      padding: EdgeInsets.zero,
                      tooltip: _trailingTooltip(task, l10n),
                      onPressed: _trailingAction(task, service),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData? _trailingIcon(DownloadTask task) {
    return switch (task.status) {
      DownloadStatus.failed => Icons.refresh,
      DownloadStatus.downloading || DownloadStatus.pending => Icons.close,
      _ => null,
    };
  }

  VoidCallback? _trailingAction(
    DownloadTask task,
    AudioDownloadService service,
  ) {
    return switch (task.status) {
      DownloadStatus.failed => () => service.download(
            episodeId: task.episodeId,
            audioUrl: task.audioUrl,
          ),
      DownloadStatus.downloading || DownloadStatus.pending => () => service.cancel(task.episodeId),
      _ => null,
    };
  }

  String _trailingTooltip(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      DownloadStatus.failed => l10n.download_button_retry,
      DownloadStatus.downloading || DownloadStatus.pending => l10n.download_button_cancel,
      _ => '',
    };
  }

  String _statusText(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      DownloadStatus.completed => l10n.download_button_downloaded,
      DownloadStatus.failed => l10n.download_button_failed,
      DownloadStatus.pending => l10n.download_button_download,
      DownloadStatus.downloading => '${(task.progress * 100).toStringAsFixed(0)}%',
      _ => task.status.name,
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (task.status) {
      DownloadStatus.completed => CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.download_done,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
      DownloadStatus.failed => CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
        ),
      _ => CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: task.status == DownloadStatus.downloading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    child: CircularProgressIndicator.adaptive(
                      value: task.progress > 0 ? task.progress : null,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Icon(
                  Icons.downloading,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
        ),
    };
  }
}
