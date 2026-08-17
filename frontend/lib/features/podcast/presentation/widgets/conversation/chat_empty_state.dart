import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';

/// Empty state for the conversation chat when no messages exist yet.
///
/// Displays an icon, title, hint text, and an optional AI summary preview.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    required this.aiSummary, super.key,
  });

  final String? aiSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_outlined,
                size: 36,
                color: scheme.primary,
              ),
            ),
            SizedBox(height: context.spacing.md),
            Text(
              l10n.podcast_conversation_empty_title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              l10n.podcast_conversation_empty_hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.lg),
            if (aiSummary case final summary? when summary.isNotEmpty)
              Container(
                padding: EdgeInsets.all(context.spacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(ext.cardRadius),
                  border: Border(
                    left: BorderSide(color: scheme.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        SizedBox(width: context.spacing.sm),
                        Text(
                          l10n.podcast_filter_with_summary,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.spacing.sm),
                    Text(
                      summary.length > 200
                          ? '${summary.substring(0, 200)}...'
                          : summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
