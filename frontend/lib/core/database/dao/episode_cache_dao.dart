import 'package:drift/drift.dart';

import 'package:sonde/core/database/app_database.dart';

part 'episode_cache_dao.g.dart';

@DriftAccessor(tables: [EpisodesCache])
class EpisodeCacheDao extends DatabaseAccessor<AppDatabase>
    with _$EpisodeCacheDaoMixin {
  EpisodeCacheDao(super.db);

  /// Upsert a single episode into the cache.
  Future<void> upsertEpisode(EpisodesCacheCompanion episode) {
    return into(episodesCache).insertOnConflictUpdate(episode);
  }

  /// Get a cached episode by ID.
  Future<EpisodesCacheData?> getById(int id) {
    return (select(episodesCache)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Delete a cached episode by ID.
  Future<void> deleteById(int id) {
    return (delete(episodesCache)..where((t) => t.id.equals(id))).go();
  }

  /// Removes entries older than [maxAge].
  Future<int> evictStaleEntries({Duration maxAge = const Duration(days: 7)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(episodesCache)
          ..where((t) => t.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
