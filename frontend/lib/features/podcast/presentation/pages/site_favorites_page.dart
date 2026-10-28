/** 收藏页（v2 Phase E：per-user 云同步收藏）。 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/favorites_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';

class SiteFavoritesPage extends ConsumerWidget {
  const SiteFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
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
            return const Center(child: Text('还没有收藏的单集'));
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(favoritesProvider.notifier).reload(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(Icons.podcasts),
                            ),
                          ),
                        )
                      : const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.podcasts),
                        ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(item.subscriptionTitle ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    tooltip: '取消收藏',
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
      ),
    );
  }
}
