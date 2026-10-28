/** 指定期刊物详情页（v2 Phase G）：/reading/issue/:kind/:key，正文复用 [SiteReportBody]。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.site_report_not_published,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              )
            : SiteReportBody(report: value),
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
