import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';

/// Country selector pill shown in the top-charts section header.
///
/// Displays the currently selected country code; tapping triggers [onTap]
/// which is expected to open the country selector sheet.
class DiscoverCountryPill extends ConsumerWidget {
  const DiscoverCountryPill({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedCountry = ref.watch(
      countrySelectorProvider.select((state) => state.selectedCountry),
    );
    const height = 30.0;

    return Material(
      color: Colors.transparent,
      child: AdaptiveInkWell(
        key: const Key('podcast_discover_country_button'),
        borderRadius: BorderRadius.circular(height / 2),
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: context.spacing.xs),
              Text(
                selectedCountry.code.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: context.spacing.xs + context.spacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
