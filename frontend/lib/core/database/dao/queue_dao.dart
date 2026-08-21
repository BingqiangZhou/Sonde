import 'package:drift/drift.dart';

import 'package:sonde/core/database/app_database.dart';

part 'queue_dao.g.dart';

@DriftAccessor(tables: [QueueItems])
class QueueDao extends DatabaseAccessor<AppDatabase> with _$QueueDaoMixin {
  QueueDao(super.db);

  /// Queue entries ordered by their position slot.
  Future<List<QueueItem>> ordered() {
    return (select(queueItems)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<bool> contains(int episodeId) async {
    final row = await (select(queueItems)
          ..where((t) => t.episodeId.equals(episodeId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Append an episode to the end of the queue.
  Future<void> append(int episodeId) async {
    final maxPosition = queueItems.position.max();
    final row = await (selectOnly(queueItems)..addColumns([maxPosition]))
        .getSingleOrNull();
    final nextPosition = (row?.read(maxPosition) ?? -1) + 1;
    await into(queueItems).insertOnConflictUpdate(
      QueueItemsCompanion.insert(
        episodeId: Value(episodeId),
        position: nextPosition,
      ),
    );
  }

  /// Remove an episode from the queue; positions stay sparse (stable).
  Future<int> remove(int episodeId) {
    return (delete(queueItems)..where((t) => t.episodeId.equals(episodeId))).go();
  }

  Future<int> clear() {
    return delete(queueItems).go();
  }

  /// Rewrite the ordering after a drag-and-drop reorder.
  Future<void> reorder(List<int> episodeIdsInOrder) {
    return batch((batch) {
      for (var i = 0; i < episodeIdsInOrder.length; i++) {
        batch.update(
          queueItems,
          QueueItemsCompanion(position: Value(i)),
          where: (t) => t.episodeId.equals(episodeIdsInOrder[i]),
        );
      }
    });
  }
}
