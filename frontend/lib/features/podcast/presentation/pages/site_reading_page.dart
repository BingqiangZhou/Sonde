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

    return ContentShell(
      title: l10n.site_reading_title,
      subtitle: '',
      roundedViewport: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeaderCapsuleActionButton(
            tooltip: l10n.site_report_archive,
            icon: Icons.history,
            density: HeaderCapsuleActionButtonDensity.iconOnly,
            onPressed: () => context.push('/reading/archive'),
          ),
          SizedBox(width: context.spacing.xs),
          HeaderCapsuleActionButton(
            tooltip: l10n.site_report_all_episodes,
            icon: Icons.list_alt_outlined,
            density: HeaderCapsuleActionButtonDensity.iconOnly,
            onPressed: () => context.push('/reading/all'),
          ),
          SizedBox(width: context.spacing.xs),
          HeaderCapsuleActionButton(
            tooltip: l10n.site_report_refresh,
            icon: Icons.refresh,
            density: HeaderCapsuleActionButtonDensity.iconOnly,
            onPressed: () {
              ref.read(siteReportProvider(kind).notifier).reload();
              ref.invalidate(siteMetaProvider);
            },
          ),
        ],
      ),
      child: Column(
        children: [
          _KindSelector(kind: kind),
          SizedBox(height: context.spacing.sm),
          // 站点标语（/site/meta；失败静默隐藏）
          if (tagline?.isNotEmpty == true)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.md,
                0,
                context.spacing.md,
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
    return AdaptiveSegmentedControl<SiteReportKind>(
      segments: {
        SiteReportKind.daily: Text(l10n.site_report_daily),
        SiteReportKind.weekly: Text(l10n.site_report_weekly),
        SiteReportKind.monthly: Text(l10n.site_report_monthly),
      },
      selected: kind,
      onChanged: (value) =>
          ref.read(selectedReportKindProvider.notifier).set(value),
    );
  }
}
