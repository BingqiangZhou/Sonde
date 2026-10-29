/** 刊物归档页（v2 Phase G）：日/周/月分栏的历史刊物列表，点开指定期。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/providers/site_report_providers.dart';

class SiteArchivePage extends ConsumerStatefulWidget {
  const SiteArchivePage({super.key, this.initialKind});

  final SiteReportKind? initialKind;

  @override
  ConsumerState<SiteArchivePage> createState() => _SiteArchivePageState();
}

class _SiteArchivePageState extends ConsumerState<SiteArchivePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _kinds = SiteReportKind.values;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialKind == null
        ? 0
        : _kinds.indexOf(widget.initialKind!).clamp(0, _kinds.length - 1);
    _tabController = TabController(
      length: _kinds.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.site_archive_title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.site_report_daily),
            Tab(text: l10n.site_report_weekly),
            Tab(text: l10n.site_report_monthly),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [for (final kind in _kinds) _ArchiveList(kind: kind)],
      ),
    );
  }
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({required this.kind});

  final SiteReportKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final archive = ref.watch(siteReportArchiveProvider(kind));

    return archive.when(
      data: (value) => (value?.keys ?? []).isEmpty
          ? AppEmptyState(
              icon: Icons.history,
              title: l10n.site_archive_empty,
            )
          : AdaptiveRefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(siteReportArchiveProvider(kind)),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: value!.keys.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final entry = value.keys[index];
                  return _ArchiveEntryTile(kind: kind, entry: entry);
                },
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, _) => AppEmptyState(
        icon: Icons.cloud_off,
        title: l10n.common_load_failed,
        subtitle: '$error',
        action: AdaptiveButton(
          onPressed: () => ref.invalidate(siteReportArchiveProvider(kind)),
          child: Text(l10n.retry),
        ),
      ),
    );
  }
}

class _ArchiveEntryTile extends StatelessWidget {
  const _ArchiveEntryTile({required this.kind, required this.entry});

  final SiteReportKind kind;
  final SiteReportKeyEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 生成时间：与 reportKey 同日时只显示时刻，避免日期重复
    final generatedParts = entry.generatedAt?.split('T');
    final generatedAt = generatedParts == null
        ? null
        : (generatedParts.first == entry.reportKey && generatedParts.length > 1)
            ? generatedParts[1].substring(0, 5)
            : generatedParts.first;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          entry.reportKey,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: generatedAt == null
            ? null
            : Text(
                generatedAt,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
        trailing: entry.revision == null
            ? null
            : Text(
                context.l10n.site_report_revision(entry.revision!),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
        onTap: () => context.push(
          '/reading/issue/${kind.name}/${entry.reportKey}',
        ),
      ),
    );
  }
}
