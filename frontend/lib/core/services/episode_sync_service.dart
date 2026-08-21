import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/database/database_provider.dart';
import 'package:sonde/core/network/dio_client.dart';
import 'package:sonde/core/providers/core_providers.dart';
import 'package:sonde/core/utils/app_logger.dart' as logger;

class EpisodeSyncResult {
  const EpisodeSyncResult({required this.syncedEpisodes, this.completed = true});

  /// Number of episodes upserted into the local cache this run.
  final int syncedEpisodes;

  /// False when the run aborted mid-way (network error / page cap);
  /// the persisted cursor lets the next run resume exactly where it stopped.
  final bool completed;
}

/// Incremental hydration of the local episode cache from the backend's
/// `/podcasts/episodes/sync` keyset endpoint (oldest-first by updated_at).
///
/// The persisted cursor doubles as the sync watermark: after a completed
/// run it points at the last applied row, so later runs are tiny deltas.
class EpisodeSyncService {
  EpisodeSyncService(this._dio, this._db);

  final DioClient _dio;
  final AppDatabase _db;

  static const String _cursorKey = 'episode_sync_cursor';
  static const int _batchLimit = 200;

  /// Safety valve: 200 * 50 = 10k episodes per run is far beyond a
  /// personal library; larger initial pulls resume on the next run.
  static const int _maxPages = 50;

  Future<EpisodeSyncResult> sync() async {
    var cursor = await _db.settingsDao.get(_cursorKey);
    var hasMore = true;
    var synced = 0;
    var pages = 0;

    while (hasMore && pages < _maxPages) {
      final response = await _dio.get(
        '/podcasts/episodes/sync',
        queryParameters: {
          'limit': _batchLimit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      final data = _asMap(response.data);
      if (data == null) break;

      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .cast<Map<String, dynamic>>();
      await _db.batch((batch) {
        for (final item in items) {
          batch.insert(
            _db.episodeCacheDao.episodesCache,
            _toCompanion(item),
            onConflict: DoUpdate(
              (_) => _toCompanion(item),
              target: [_db.episodeCacheDao.episodesCache.id],
            ),
          );
        }
      });
      synced += items.length;

      hasMore = data['has_more'] == true;
      final nextCursor = data['next_cursor'];
      if (nextCursor is String && nextCursor.isNotEmpty) {
        cursor = nextCursor;
        await _db.settingsDao.set(_cursorKey, nextCursor);
      } else {
        hasMore = false;
      }
      pages++;
    }

    logger.AppLogger.debug(
      '[EpisodeSync] synced=$synced pages=$pages completed=$hasMore',
    );
    return EpisodeSyncResult(
      syncedEpisodes: synced,
      completed: !hasMore,
    );
  }

  Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  EpisodesCacheCompanion _toCompanion(Map<String, dynamic> item) {
    DateTime? parse(String? raw) =>
        raw == null ? null : DateTime.tryParse(raw);
    return EpisodesCacheCompanion(
      id: Value(item['id'] as int),
      subscriptionId: Value(item['subscription_id'] as int),
      title: Value(item['title'] as String? ?? ''),
      audioUrl: Value(item['audio_url'] as String? ?? ''),
      imageUrl: Value(item['image_url'] as String?),
      audioDuration: Value(item['audio_duration'] as int?),
      subscriptionTitle: Value(item['subscription_title'] as String?),
      subscriptionImageUrl: Value(item['subscription_image_url'] as String?),
      publishedAt: Value(parse(item['published_at'] as String?) ?? DateTime.now()),
      updatedAt: Value(parse(item['updated_at'] as String?) ?? DateTime.now()),
      description: Value(item['description'] as String?),
      aiSummary: Value(item['ai_summary'] as String?),
    );
  }
}

final episodeSyncServiceProvider = Provider<EpisodeSyncService>((ref) {
  return EpisodeSyncService(
    ref.read(dioClientProvider),
    ref.read(appDatabaseProvider),
  );
});
