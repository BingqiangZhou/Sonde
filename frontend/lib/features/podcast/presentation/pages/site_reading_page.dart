/** 阅读 Tab 首页（v2 Phase G）：日/周/月三刊 + 归档/全部动态入口。
 *  正文渲染复用 [SiteReportBody]。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/providers/site_reading_providers.dart';
import 'package:sonde/features/podcast/presentation/providers/site_report_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/site_report_body.dart';

class SiteReadingPage extends ConsumerWidget {
  const SiteReadingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ref.watch(selectedReportKindProvider);
    final report = ref.watch(siteReportProvider(kind));
    final meta = ref.watch(siteMetaProvider);
    final tagline = meta.value?.tagline;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.site_reading_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.site_report_archive,
            onPressed: () => context.push('/reading/archive'),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: l10n.site_report_all_episodes,
            onPressed: () => context.push('/reading/all'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.site_report_refresh,
            onPressed: () {
              ref.read(siteReportProvider(kind).notifier).reload();
              ref.invalidate(siteMetaProvider);
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight * 0.9),
          child: _KindSelector(kind: kind),
        ),
      ),
      body: Column(
        children: [
          // 站点标语（/site/meta；失败静默隐藏）
          if (tagline?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.smMd,
                AppSpacing.md,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  tagline!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: report.when(
              data: (value) => value == null
                  ? AppEmptyState(
                      icon: Icons.outbox_outlined,
                      title: l10n.common_not_published,
                    )
                  : SiteReportBody(report: value),
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) => AppEmptyState(
                icon: Icons.cloud_off,
                title: l10n.common_load_failed,
                subtitle: '$error',
                action: AdaptiveButton(
                  onPressed: () =>
                      ref.read(siteReportProvider(kind).notifier).reload(),
                  child: Text(l10n.retry),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindSelector extends ConsumerWidget {
  const _KindSelector({required this.kind});

  final SiteReportKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedButton<SiteReportKind>(
      segments: [
        ButtonSegment(value: SiteReportKind.daily, label: Text(l10n.site_report_daily)),
        ButtonSegment(value: SiteReportKind.weekly, label: Text(l10n.site_report_weekly)),
        ButtonSegment(value: SiteReportKind.monthly, label: Text(l10n.site_report_monthly)),
      ],
      selected: {kind},
      onSelectionChanged: (selection) => ref
          .read(selectedReportKindProvider.notifier)
          .set(selection.first),
    );
  }
}
