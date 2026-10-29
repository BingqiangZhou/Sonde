/** 指定期刊物详情页（v2 Phase G）：/reading/issue/:kind/:key，正文复用 [SiteReportBody]。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/providers/site_reading_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/site_report_body.dart';

class SiteReportIssuePage extends ConsumerWidget {
  const SiteReportIssuePage({
    required this.kind,
    required this.reportKey,
    super.key,
  });

  final SiteReportKind kind;
  final String reportKey;

  static SiteReportKind? parseKind(String? value) {
    for (final kind in SiteReportKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final issue = ref.watch(siteReportIssueProvider((kind, reportKey)));

    return Scaffold(
      appBar: AppBar(title: Text(reportKey)),
      body: issue.when(
        data: (value) => value == null
            ? AppEmptyState(
                icon: Icons.outbox_outlined,
                title: l10n.common_not_published,
              )
            : SiteReportBody(report: value),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => AppEmptyState(
          icon: Icons.cloud_off,
          title: l10n.common_load_failed,
          subtitle: '$error',
          action: AdaptiveButton(
            onPressed: () =>
                ref.invalidate(siteReportIssueProvider((kind, reportKey))),
            child: Text(l10n.retry),
          ),
        ),
      ),
    );
  }
}
