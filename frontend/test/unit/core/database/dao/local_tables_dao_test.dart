import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/database/dao/playback_dao.dart';
import 'package:sonde/core/database/dao/queue_dao.dart';
import 'package:sonde/core/database/dao/settings_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PlaybackDao', () {
    late PlaybackDao dao;

    setUp(() {
      dao = PlaybackDao(db);
    });

    test('saveProgress merges: absent fields keep their stored value', () async {
      await dao.saveProgress(episodeId: 7, position: 30, isPlaying: true);
      await dao.saveProgress(episodeId: 7, position: 90, playbackRate: 1.5);

      final state = await dao.getByEpisodeId(7);
      expect(state, isNotNull);
      expect(state!.position, 90);
      expect(state.playbackRate, 1.5);
      // isPlaying was absent in the second update — the stored value stays.
      expect(state.isPlaying, isTrue);
    });

    test('upsertState replaces the whole row', () async {
      await dao.upsertState(
        PlaybackStatesCompanion.insert(episodeId: const Value(7)),
      );
      await dao.upsertState(
        PlaybackStatesCompanion.insert(
          episodeId: const Value(7),
          position: const Value(42),
        ),
      );

      final state = await dao.getByEpisodeId(7);
      expect(state!.position, 42);
    });

    test('getByEpisodeIds returns a sparse id-keyed map', () async {
      await dao.saveProgress(episodeId: 1, position: 5);
      await dao.saveProgress(episodeId: 3, position: 10);

      final map = await dao.getByEpisodeIds([1, 2, 3]);
      expect(map.keys, {1, 3});
      expect(map[3]!.position, 10);
    });

    test('recent orders by updatedAt desc', () async {
      // Explicit timestamps: drift stores datetimes with second precision,
      // so real-time deltas inside one test would tie.
      final base = DateTime(2026, 8, 20, 12);
      await dao.upsertState(
        PlaybackStatesCompanion.insert(
          episodeId: const Value(1),
          updatedAt: Value(base),
        ),
      );
      await dao.upsertState(
        PlaybackStatesCompanion.insert(
          episodeId: const Value(2),
          updatedAt: Value(base.add(const Duration(hours: 1))),
        ),
      );

      final recent = await dao.recent();
      expect(recent.map((s) => s.episodeId), [2, 1]);
    });
  });

  group('QueueDao', () {
    late QueueDao dao;

    setUp(() {
      dao = QueueDao(db);
    });

    test('append assigns sequential positions; ordered returns them', () async {
      await dao.append(10);
      await dao.append(20);
      await dao.append(30);

      final queue = await dao.ordered();
      expect(queue.map((q) => q.episodeId), [10, 20, 30]);
      expect(queue.map((q) => q.position), [0, 1, 2]);
    });

    test('append is idempotent per episode', () async {
      await dao.append(10);
      await dao.append(10);

      expect((await dao.ordered()).length, 1);
    });

    test('remove leaves sparse but stable positions', () async {
      await dao.append(10);
      await dao.append(20);
      await dao.append(30);
      await dao.remove(20);

      final queue = await dao.ordered();
      expect(queue.map((q) => q.episodeId), [10, 30]);
      expect(queue.map((q) => q.position), [0, 2]);
    });

    test('reorder rewrites dense positions', () async {
      await dao.append(10);
      await dao.append(20);
      await dao.append(30);

      await dao.reorder([30, 10, 20]);

      final queue = await dao.ordered();
      expect(queue.map((q) => q.episodeId), [30, 10, 20]);
      expect(queue.map((q) => q.position), [0, 1, 2]);
    });
  });

  group('SettingsDao', () {
    late SettingsDao dao;

    setUp(() {
      dao = SettingsDao(db);
    });

    test('set overwrites and get round-trips', () async {
      await dao.set('k', 'v1');
      expect(await dao.get('k'), 'v1');

      await dao.set('k', 'v2');
      expect(await dao.get('k'), 'v2');
    });

    test('get returns null for missing keys; remove deletes', () async {
      expect(await dao.get('missing'), isNull);

      await dao.set('k', 'v');
      expect(await dao.remove('k'), 1);
      expect(await dao.get('k'), isNull);
    });
  });
}
