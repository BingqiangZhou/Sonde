/** 收藏同步 providers（v2 Phase E：per-user 云收藏）。 */

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, FavoritesListResponse?>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<FavoritesListResponse?> {
  @override
  FutureOr<FavoritesListResponse?> build() async {
    try {
      return await ref.read(podcastRepositoryProvider).listFavorites();
    } catch (error) {
      logger.AppLogger.debug('Failed to load favorites: $error');
      return null;
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(podcastRepositoryProvider).listFavorites());
  }

  Future<void> remove(int episodeId) async {
    try {
      await ref.read(podcastRepositoryProvider).removeFavorite(episodeId);
      await reload();
    } catch (error) {
      logger.AppLogger.debug('Failed to remove favorite $episodeId: $error');
    }
  }
}

/// 单集收藏状态（详情页星标）
final favoriteStatusProvider =
    FutureProvider.family<bool, int>((ref, episodeId) async {
  try {
    return await ref.read(podcastRepositoryProvider).isFavorite(episodeId);
  } catch (_) {
    return false;
  }
});

/// 切换收藏：成功返回新状态，失败返回原状态（调用方负责 invalidate）
Future<bool> toggleFavorite({
  required WidgetRef ref,
  required int episodeId,
  required bool current,
}) async {
  final repo = ref.read(podcastRepositoryProvider);
  try {
    if (current) {
      await repo.removeFavorite(episodeId);
    } else {
      await repo.addFavorite(episodeId);
    }
    ref.invalidate(favoriteStatusProvider(episodeId));
    ref.invalidate(favoritesProvider);
    return !current;
  } catch (error) {
    logger.AppLogger.debug('Failed to toggle favorite $episodeId: $error');
    ref.invalidate(favoriteStatusProvider(episodeId));
    return current;
  }
}
