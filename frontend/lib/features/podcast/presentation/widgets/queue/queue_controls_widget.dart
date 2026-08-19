import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/selector_sheet_common.dart';

class QueueHeader extends StatelessWidget {
  const QueueHeader({
    required this.title, required this.itemCount, required this.queueOperation, required this.queueSyncing, required this.onRefresh, super.key,
  });

  final String title;
  final int? itemCount;
  final QueueOperationState queueOperation;
  final bool queueSyncing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final statusLabel = queueStatusLabel(
      l10n,
      queueOperation: queueOperation,
      queueSyncing: queueSyncing,
    );

    final showCountChip = itemCount != null;
    final showStatusChip = statusLabel != null;

    return SelectorSheetHeader(
      icon: Icons.queue_music_rounded,
      title: title,
      titleStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      trailing: IconButton(
        tooltip: l10n.refresh,
        visualDensity: VisualDensity.compact,
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
      bottom: (showCountChip || showStatusChip)
          ? Row(
              children: [
                if (showCountChip)
                  QueueInfoChip(
                    icon: Icons.queue_music_rounded,
                    label: '${itemCount ?? 0} ${l10n.queue_in_queue}',
                  ),
                if (showCountChip && showStatusChip)
                  SizedBox(width: context.spacing.sm),
                if (showStatusChip)
                  Flexible(
                    child: QueueInfoChip(
                      icon: Icons.sync_rounded,
                      label: statusLabel,
                      emphasized: true,
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

class QueueInfoChip extends StatelessWidget {
  const QueueInfoChip({
    required this.icon, required this.label, super.key,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm, vertical: context.spacing.sm),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns a human-readable status label for the current queue operation, or
/// `null` when the queue is idle and not syncing.
String? queueStatusLabel(
  AppLocalizations l10n, {
  required QueueOperationState queueOperation,
  required bool queueSyncing,
}) {
  switch (queueOperation.kind) {
    case QueueOperationKind.initialLoading:
      return l10n.loading;
    case QueueOperationKind.refreshing:
      return l10n.refreshing;
    case QueueOperationKind.reordering:
      return l10n.queue_saving_order;
    case QueueOperationKind.removing:
    case QueueOperationKind.activating:
      return l10n.queue_updating;
    case QueueOperationKind.idle:
      if (queueSyncing) {
        return l10n.queue_syncing;
      }
      return null;
  }
}
