import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/shared/widgets/loading_widget.dart';

class QueueLoadingState extends StatelessWidget {
  const QueueLoadingState({
    required this.title, required this.subtitle, super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.lg, context.spacing.mdLg, context.spacing.xl),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Center(
          child: LoadingStatusContent(
            key: const Key('queue_loading_content'),
            title: title,
            subtitle: subtitle,
            spinnerSize: 40,
          ),
        ),
      ],
    );
  }
}

class QueueEmptyStateList extends StatelessWidget {
  const QueueEmptyStateList({
    required this.icon, required this.title, required this.subtitle, super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.lg, context.spacing.mdLg, context.spacing.xl),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Container(
          key: const Key('queue_state_card'),
          padding: EdgeInsets.all(context.spacing.lg),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[SizedBox(height: context.spacing.md), action!],
            ],
          ),
        ),
      ],
    );
  }
}
