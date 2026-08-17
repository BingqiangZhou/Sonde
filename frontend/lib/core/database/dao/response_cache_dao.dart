import 'package:drift/drift.dart';

import 'package:sonde/core/database/app_database.dart';

part 'response_cache_dao.g.dart';

@DriftAccessor(tables: [ResponseCache])
class ResponseCacheDao extends DatabaseAccessor<AppDatabase>
    with _$ResponseCacheDaoMixin {
  ResponseCacheDao(super.attachedDatabase);

  /// Returns the cached JSON payload for [key], or null when missing or
  /// expired. Expired rows are deleted on read.
  Future<String?> getPayload(String key) async {
    final row = await (select(responseCache)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.expiresAt.isBefore(DateTime.now())) {
      await deleteByKey(key);
      return null;
    }
    return row.payload;
  }

  /// Upserts [payload] under [key] with a [ttl] lifetime.
  Future<void> putPayload(String key, String payload, {required Duration ttl}) {
    final now = DateTime.now();
    return into(responseCache).insertOnConflictUpdate(
      ResponseCacheCompanion.insert(
        key: key,
        payload: payload,
        cachedAt: Value(now),
        expiresAt: now.add(ttl),
      ),
    );
  }

  Future<void> deleteByKey(String key) {
    return (delete(responseCache)..where((t) => t.key.equals(key))).go();
  }

  Future<int> clearAll() => delete(responseCache).go();
}
