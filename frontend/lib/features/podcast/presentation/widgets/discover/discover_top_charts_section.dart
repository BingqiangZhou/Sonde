import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/widgets/linear_section_header.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_category_chips.dart';
import 'package:sonde/features/podcast/presentation/widgets/discover/discover_country_pill.dart';

/// Top charts section: eyebrow header with the country selector pill and
/// the horizontal category chips below it.
class DiscoverTopChartsSection extends ConsumerWidget {
  const DiscoverTopChartsSection({
    required this.state,
    required this.onCategorySelected,
    required this.onCountryTap,
    super.key,
    this.isDense = false,
  });

  final PodcastDiscoverState state;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onCountryTap;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      key: const Key('podcast_discover_top_charts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearSectionHeader.label(
          l10n.podcast_discover_top_charts,
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xs,
            vertical: isDense ? context.spacing.xs : context.spacing.smMd,
          ),
          trailing: Padding(
            padding: EdgeInsets.only(right: context.spacing.sm),
            child: DiscoverCountryPill(onTap: onCountryTap),
          ),
        ),
        SizedBox(height: isDense ? context.spacing.xxs : context.spacing.smMd),
        DiscoverCategoryChips(
          state: state,
          onCategorySelected: onCategorySelected,
        ),
      ],
    );
  }
}
