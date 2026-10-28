/** 三刊正文共享渲染器（Phase G）：刊头 + 导语 + 看点 + 分节条目。
 *  阅读 Tab 首页与归档详情页共用；Material 3 + AppSpacing/AppRadius token。 */

import 'package:flutter/material.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/utils/time_formatter.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';

class SiteReportBody extends StatelessWidget {
  const SiteReportBody({required this.report, super.key});

  final SiteReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final content = report.content;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // 刊头：标题 + 期号/版次/条目数
        Text(
          content.title,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            report.reportKey,
            l10n.site_report_revision(report.revision),
            l10n.site_report_item_count(content.selectedCount),
          ].join(' · '),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: AppSpacing.smMd),
        Text(content.leadParagraph, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        if (content.highlights.isNotEmpty) ...[
          _ReportSectionCard(
            title: l10n.site_report_highlights,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, highlight) in content.highlights.indexed)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${index + 1}.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            highlight,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final section in content.sections) ...[
          _ReportSectionCard(
            title: section.section,
            child: Column(
              children: [
                for (final item in section.items)
                  _ReportItemTile(item: item),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: AppSpacing.mdLg),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReportItemTile extends StatelessWidget {
  const _ReportItemTile({required this.item});

  final SiteReportItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final score = item.score;

    final metaParts = [
      if (item.podcast.isNotEmpty) item.podcast,
      if (item.durationSeconds != null)
        TimeFormatter.formatSecondsClock(item.durationSeconds!),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => PodcastNavigation.goToEpisodeDetail(
        context,
        episodeId: item.episodeId,
        subscriptionId: item.episodeId, // 占位：详情页以 episodeId 为主键查询
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (score != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.smMd),
                child: _ScoreBadge(score: score),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metaParts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
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
                    ),
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.summaryZh?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.summaryZh!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.reasonZh?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.site_report_why_worth_listening} · ${item.reasonZh}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
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
      width: 44,
      height: 44,
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
