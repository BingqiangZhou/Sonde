import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/database/dao/episode_cache_dao.dart';

void main() {
  late AppDatabase db;
  late EpisodeCacheDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = EpisodeCacheDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  EpisodesCacheCompanion makeEpisode({
    required int id,
    required int subscriptionId,
    String title = 'Test Episode',
    String audioUrl = 'https://example.com/ep.mp3',
    String? imageUrl,
    int? audioDuration,
    String? subscriptionTitle,
    String? subscriptionImageUrl,
    DateTime? publishedAt,
    DateTime? updatedAt,
  }) {
    return EpisodesCacheCompanion.insert(
      id: Value(id),
      subscriptionId: subscriptionId,
      title: title,
      audioUrl: audioUrl,
      imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
      audioDuration: audioDuration != null ? Value(audioDuration) : const Value.absent(),
      subscriptionTitle: subscriptionTitle != null ? Value(subscriptionTitle) : const Value.absent(),
      subscriptionImageUrl: subscriptionImageUrl != null ? Value(subscriptionImageUrl) : const Value.absent(),
      publishedAt: publishedAt ?? DateTime(2025),
      updatedAt: updatedAt ?? DateTime(2025),
    );
  }

  group('upsertEpisode & getById', () {
    test('inserts and retrieves an episode', () async {
      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10));

      final ep = await dao.getById(1);

      expect(ep, isNotNull);
      expect(ep!.id, 1);
      expect(ep.subscriptionId, 10);
      expect(ep.title, 'Test Episode');
      expect(ep.audioUrl, 'https://example.com/ep.mp3');
    });

    test('returns null for non-existent id', () async {
      final ep = await dao.getById(999);
      expect(ep, isNull);
    });

    test('upserts (replaces) existing episode on conflict', () async {
      await dao.upsertEpisode(makeEpisode(
        id: 1,
        subscriptionId: 10,
        title: 'Original Title',
      ));

      await dao.upsertEpisode(makeEpisode(
        id: 1,
        subscriptionId: 10,
        title: 'Updated Title',
      ));

      final ep = await dao.getById(1);
      expect(ep!.title, 'Updated Title');
    });
  });

  group('deleteById', () {
    test('deletes a cached episode by id', () async {
      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10));
      await dao.upsertEpisode(makeEpisode(id: 2, subscriptionId: 10));

      await dao.deleteById(1);

      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('does nothing for non-existent id', () async {
      await dao.deleteById(999); // should not throw
    });
  });

  group('evictStaleEntries', () {
    test('evicts entries older than maxAge', () async {
      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 10));
      final recentDate = now.subtract(const Duration(days: 1));

      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10, updatedAt: oldDate));
      await dao.upsertEpisode(makeEpisode(id: 2, subscriptionId: 10, updatedAt: oldDate));
      await dao.upsertEpisode(makeEpisode(id: 3, subscriptionId: 10, updatedAt: recentDate));

      final deleted = await dao.evictStaleEntries();

      expect(deleted, 2);
      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNull);
      expect(await dao.getById(3), isNotNull);
    });

    test('does not evict entries exactly at the boundary', () async {
      final now = DateTime.now();
      // Entry updated exactly 7 days ago -- isSmallerThanValue uses strict <
      final boundaryDate = now.subtract(const Duration(days: 7));

      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10, updatedAt: boundaryDate));

      final deleted = await dao.evictStaleEntries();

      expect(deleted, 0);
      expect(await dao.getById(1), isNotNull);
    });

    test('evicts nothing when all entries are fresh', () async {
      final now = DateTime.now();

      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10, updatedAt: now));
      await dao.upsertEpisode(makeEpisode(id: 2, subscriptionId: 10, updatedAt: now.subtract(const Duration(hours: 1))));

      final deleted = await dao.evictStaleEntries();

      expect(deleted, 0);
      expect(await dao.getById(1), isNotNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('custom maxAge works correctly', () async {
      final now = DateTime.now();

      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10, updatedAt: now.subtract(const Duration(days: 2))));
      await dao.upsertEpisode(makeEpisode(id: 2, subscriptionId: 10, updatedAt: now.subtract(const Duration(hours: 12))));

      final deleted = await dao.evictStaleEntries(maxAge: const Duration(days: 1));

      expect(deleted, 1);
      expect(await dao.getById(1), isNull);
      expect(await dao.getById(2), isNotNull);
    });

    test('returns 0 when table is empty', () async {
      final deleted = await dao.evictStaleEntries();
      expect(deleted, 0);
    });
  });

  group('nullable fields', () {
    test('stores and retrieves nullable fields correctly', () async {
      await dao.upsertEpisode(EpisodesCacheCompanion.insert(
        id: const Value(1),
        subscriptionId: 10,
        title: 'Episode with optionals',
        audioUrl: 'https://example.com/ep.mp3',
        imageUrl: const Value('https://img.example.com/cover.jpg'),
        audioDuration: const Value(3600),
        subscriptionTitle: const Value('My Podcast'),
        subscriptionImageUrl: const Value('https://img.example.com/pod.jpg'),
        publishedAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ));

      final ep = await dao.getById(1);
      expect(ep!.imageUrl, 'https://img.example.com/cover.jpg');
      expect(ep.audioDuration, 3600);
      expect(ep.subscriptionTitle, 'My Podcast');
      expect(ep.subscriptionImageUrl, 'https://img.example.com/pod.jpg');
    });

    test('nullable fields default to null when absent', () async {
      await dao.upsertEpisode(makeEpisode(id: 1, subscriptionId: 10));

      final ep = await dao.getById(1);
      expect(ep!.imageUrl, isNull);
      expect(ep.audioDuration, isNull);
      expect(ep.subscriptionTitle, isNull);
      expect(ep.subscriptionImageUrl, isNull);
    });
  });
}
