import 'package:drift/drift.dart';

import 'package:sonde/core/database/app_database.dart';

part 'playback_dao.g.dart';

@DriftAccessor(tables: [PlaybackStates])
class PlaybackDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackDaoMixin {
  PlaybackDao(super.db);

  /// Upsert the full playback state of one episode.
  Future<void> upsertState(PlaybackStatesCompanion state) {
    return into(playbackStates).insertOnConflictUpdate(state);
  }

  /// Merge a progress update into the stored state (keeps playCount).
  Future<void> saveProgress({
    required int episodeId,
    required int position,
    double? playbackRate,
    bool? isPlaying,
  }) async {
    final companion = PlaybackStatesCompanion(
      episodeId: Value(episodeId),
      position: Value(position),
      playbackRate: playbackRate == null ? const Value.absent() : Value(playbackRate),
      isPlaying: isPlaying == null ? const Value.absent() : Value(isPlaying),
      updatedAt: Value(DateTime.now()),
    );
    final rows = await (update(playbackStates)
          ..where((t) => t.episodeId.equals(episodeId)))
        .write(companion);
    if (rows == 0) {
      await into(playbackStates).insert(companion);
    }
  }

  Future<PlaybackState?> getByEpisodeId(int episodeId) {
    return (select(playbackStates)..where((t) => t.episodeId.equals(episodeId)))
        .getSingleOrNull();
  }

  /// Batch fetch for building episode list rows.
  Future<Map<int, PlaybackState>> getByEpisodeIds(List<int> episodeIds) async {
    if (episodeIds.isEmpty) return {};
    final rows = await (select(playbackStates)
          ..where((t) => t.episodeId.isIn(episodeIds)))
        .get();
    return {for (final row in rows) row.episodeId: row};
  }

  /// Recently played episodes (local playback history), newest first.
  Future<List<PlaybackState>> recent({int limit = 50}) {
    return (select(playbackStates)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
  }

  /// Remove an episode's playback state.
  Future<int> deleteByEpisodeId(int episodeId) {
    return (delete(playbackStates)..where((t) => t.episodeId.equals(episodeId)))
        .go();
  }
}
