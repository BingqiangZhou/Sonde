/** 全部动态页（v2 Phase G）：全部已分析单集分页列表。
 *  入选条目显示中文标题/摘要/评分；落选条目显示原标题 + 落选原因 + 原始单集外链。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:sonde/features/podcast/presentation/providers/site_reading_providers.dart';

class SiteAllEpisodesPage extends ConsumerWidget {
  const SiteAllEpisodesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteAllEpisodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.site_all_episodes_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.site_report_refresh,
            onPressed: () => ref.read(siteAllEpisodesProvider.notifier).reload(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: state.when(
        data: (value) => _AllEpisodesList(state: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(l10n.site_report_load_failed('$error')),
          ),
        ),
      ),
    );
  }
}

class _AllEpisodesList extends ConsumerWidget {
  const _AllEpisodesList({required this.state});

  final SiteAllEpisodesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            l10n.site_all_episodes_empty,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.read(siteAllEpisodesProvider.notifier).reload(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            return _AnalyzedEpisodeTile(entry: state.items[index]);
          }
          // 尾部：加载更多 / 到底 / 加载中
          if (state.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(siteAllEpisodesProvider.notifier).loadNextPage(),
                child: Text(l10n.site_all_episodes_load_more),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.site_all_episodes_no_more,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyzedEpisodeTile extends StatelessWidget {
  const _AnalyzedEpisodeTile({required this.entry});

  final AnalyzedSiteEpisodeItem entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final item = entry.item;

    final metaParts = [
      if (item.podcast.isNotEmpty) item.podcast,
      if (item.publishedAt != null) item.publishedAt!.split('T').first,
      if (item.durationSeconds != null)
        TimeFormatter.formatSecondsClock(item.durationSeconds!),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: entry.selected
            ? () => PodcastNavigation.goToEpisodeDetail(
                  context,
                  episodeId: item.episodeId,
                  subscriptionId: item.episodeId, // 占位：详情页以 episodeId 为主键查询
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.score != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.smMd),
                  child: _ScoreBadge(score: item.score!),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!entry.selected)
                          Text(
                            l10n.site_all_episodes_unselected,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (item.categoryLabel != null)
                          Text(
                            item.categoryLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          metaParts.join(' · '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.summaryZh?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.summaryZh!,
                        maxLines: entry.selected ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (!entry.selected && entry.reason?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${l10n.site_all_episodes_reason_label} · ${entry.reason}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                    if (!entry.selected && item.url != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: _OpenOriginalButton(url: item.url!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenOriginalButton extends StatelessWidget {
  const _OpenOriginalButton({required this.url});

  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              context.l10n.site_all_episodes_open_original,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : theme.colorScheme.outline;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$score',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
