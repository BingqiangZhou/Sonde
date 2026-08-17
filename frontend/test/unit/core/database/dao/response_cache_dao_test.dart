import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/response_cache_dao.dart';

void main() {
  late AppDatabase db;
  late ResponseCacheDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = ResponseCacheDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('returns null for a missing key', () async {
    expect(await dao.getPayload('missing'), isNull);
  });

  test('stores and returns a payload within ttl', () async {
    await dao.putPayload(
      'episodes:1',
      '{"total":1}',
      ttl: const Duration(hours: 6),
    );

    expect(await dao.getPayload('episodes:1'), '{"total":1}');
  });

  test('upsert replaces payload for the same key', () async {
    await dao.putPayload('k', 'v1', ttl: const Duration(hours: 1));
    await dao.putPayload('k', 'v2', ttl: const Duration(hours: 1));

    expect(await dao.getPayload('k'), 'v2');
  });

  test('expired payload is deleted on read', () async {
    await dao.putPayload(
      'stale',
      'old',
      ttl: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(await dao.getPayload('stale'), isNull);
    // Row was removed, not just skipped.
    final remaining = await dao.getPayload('stale');
    expect(remaining, isNull);
  });

  test('clearAll removes every entry', () async {
    await dao.putPayload('a', '1', ttl: const Duration(hours: 1));
    await dao.putPayload('b', '2', ttl: const Duration(hours: 1));

    final removed = await dao.clearAll();

    expect(removed, 2);
    expect(await dao.getPayload('a'), isNull);
    expect(await dao.getPayload('b'), isNull);
  });

  test('deleteByKey removes only the target entry', () async {
    await dao.putPayload('a', '1', ttl: const Duration(hours: 1));
    await dao.putPayload('b', '2', ttl: const Duration(hours: 1));

    await dao.deleteByKey('a');

    expect(await dao.getPayload('a'), isNull);
    expect(await dao.getPayload('b'), '2');
  });
}
