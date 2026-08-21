// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_dao.dart';

// ignore_for_file: type=lint
mixin _$QueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $QueueItemsTable get queueItems => attachedDatabase.queueItems;
  QueueDaoManager get managers => QueueDaoManager(this);
}

class QueueDaoManager {
  final _$QueueDaoMixin _db;
  QueueDaoManager(this._db);
  $$QueueItemsTableTableManager get queueItems =>
      $$QueueItemsTableTableManager(_db.attachedDatabase, _db.queueItems);
}
