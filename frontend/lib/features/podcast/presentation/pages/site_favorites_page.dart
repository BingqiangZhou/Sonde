/** 收藏页（v2 Phase E：per-user 云同步收藏）。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:sonde/features/podcast/presentation/providers/favorites_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_image_widget.dart';

class SiteFavoritesPage extends ConsumerWidget {
  const SiteFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(favoritesProvider.notifier).reload(),
          ),
        ],
      ),
      body: favorites.when(
        data: (value) {
          final items = value?.items ?? const [];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.star_border,
              title: l10n.favorites_empty,
            );
          }
          return AdaptiveRefreshIndicator(
            onRefresh: () =>
                ref.read(favoritesProvider.notifier).reload(),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.spacing.xs,
                    vertical: context.spacing.xxs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdLgRadius,
                  ),
                  leading: ClipRRect(
                    borderRadius: AppRadius.smRadius,
                    child: PodcastImageWidget(
                      imageUrl: item.imageUrl,
                      width: 52,
                      height: 52,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.subscriptionTitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.star,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.favoriteDark
                          : AppColors.favorite,
                    ),
                    tooltip: l10n.favorites_remove,
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .remove(item.id),
                  ),
                  onTap: () => PodcastNavigation.goToEpisodeDetail(
                    context,
                    episodeId: item.id,
                    subscriptionId: item.subscriptionId,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => AppEmptyState(
          icon: Icons.cloud_off,
          title: l10n.common_load_failed,
          subtitle: error.toString(),
          action: AdaptiveButton(
            onPressed: () => ref.read(favoritesProvider.notifier).reload(),
            child: Text(l10n.retry),
          ),
        ),
      ),
    );
  }
}
