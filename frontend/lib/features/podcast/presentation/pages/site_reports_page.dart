/** 三刊阅读页（v2 Phase E）：日/周/月全局报刊，刊头 + 看点 + 分节条目。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:sonde/features/podcast/presentation/providers/site_report_providers.dart';

class SiteReportsPage extends ConsumerWidget {
  const SiteReportsPage({super.key, this.initialKind});

  final SiteReportKind? initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(selectedReportKindProvider);
    final report = ref.watch(siteReportProvider(kind));
    final archive = ref.watch(siteReportArchiveProvider(kind));

    return Scaffold(
      appBar: AppBar(
        title: Text(_kindTitle(kind)),
        actions: [
          // 归档选择
          PopupMenuButton<String>(
            icon: const Icon(Icons.history),
            tooltip: '归档',
            itemBuilder: (_) => (archive.value?.keys ?? [])
                .map((e) => PopupMenuItem(value: e.reportKey, child: Text(e.reportKey)))
                .toList(),
            onSelected: (key) =>
                ref.read(siteReportProvider(kind).notifier).loadKey(key),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              ref.read(siteReportProvider(kind).notifier).reload();
              ref.invalidate(siteReportArchiveProvider(kind));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 刊种切换
          SegmentedButton<SiteReportKind>(
            segments: const [
              ButtonSegment(value: SiteReportKind.daily, label: Text('日报')),
              ButtonSegment(value: SiteReportKind.weekly, label: Text('周报')),
              ButtonSegment(value: SiteReportKind.monthly, label: Text('月报')),
            ],
            selected: {kind},
            onSelectionChanged: (selection) => ref
                .read(selectedReportKindProvider.notifier)
                .set(selection.first),
          ),
          Expanded(
            child: report.when(
              data: (value) => value == null
                  ? const _EmptyView(message: '本期尚未成刊，请稍后再来。')
                  : _ReportBody(report: value),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyView(message: '加载失败：$error'),
            ),
          ),
        ],
      ),
    );
  }

  static String _kindTitle(SiteReportKind kind) => switch (kind) {
        SiteReportKind.daily => '日报',
        SiteReportKind.weekly => '周报',
        SiteReportKind.monthly => '月报',
      };
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final SiteReport report;

  @override
  Widget build(BuildContext context) {
    final content = report.content;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 刊头
        Text(
          content.title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${report.reportKey} · 第 ${report.revision} 版 · ${content.selectedCount} 条',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Text(content.leadParagraph, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        // 看点
        if (content.highlights.isNotEmpty) ...[
          _SectionCard(
            title: '看点',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.highlights
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(h)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // 分节条目
        for (final section in content.sections) ...[
          _SectionCard(
            title: section.section,
            child: Column(
              children: [
                for (final item in section.items)
                  _ReportItemTile(item: item),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ReportItemTile extends StatelessWidget {
  const _ReportItemTile({required this.item});

  final SiteReportItem item;

  @override
  Widget build(BuildContext context) {
    final scoreColor = (item.score ?? 0) >= 80
        ? AppColors.success
        : (item.score ?? 0) >= 60
            ? AppColors.warning
            : Theme.of(context).disabledColor;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          item.summaryZh ?? item.originalTitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      leading: item.score != null
          ? Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.score}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                  fontSize: 15,
                ),
              ),
            )
          : null,
      trailing: Text(
        item.podcast,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
      onTap: () => PodcastNavigation.goToEpisodeDetail(
        context,
        episodeId: item.episodeId,
        subscriptionId: item.episodeId, // 占位：详情页以 episodeId 为主键查询
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
