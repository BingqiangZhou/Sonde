import 'package:drift/drift.dart';
import 'package:personal_ai_assistant/core/database/dao/download_dao.dart';
import 'package:personal_ai_assistant/core/database/dao/episode_cache_dao.dart';
import 'package:personal_ai_assistant/core/database/dao/response_cache_dao.dart';

part 'app_database.g.dart';

/// Download task status stored as an integer enum in the database.
///
/// Order matters: index values are written to SQLite and must never change.
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

@DriftDatabase(
  tables: [DownloadTasks, EpisodesCache, ResponseCache],
  daos: [DownloadDao, EpisodeCacheDao, ResponseCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Recreate episodes_cache with primary key on id
        await migrator.deleteTable('episodes_cache');
        await migrator.createTable(episodesCache);
      }
      if (from < 4) {
        // Convert string status to integer enum
        await customStatement(
          "UPDATE download_tasks SET status = CASE "
          "WHEN status = 'pending' THEN 0 "
          "WHEN status = 'downloading' THEN 1 "
          "WHEN status = 'completed' THEN 2 "
          "WHEN status = 'failed' THEN 3 "
          "WHEN status = 'paused' THEN 4 "
          "ELSE 0 END",
        );
      }
      if (from < 5) {
        // Add composite index for efficient episode lookups by subscription
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_episodes_cache_subscription_published '
          'ON episodes_cache (subscription_id, published_at DESC)',
        );
      }
      if (from < 6) {
        // Drop the unused playback_states table; playback persistence lives
        // in server snapshots and local storage. Add the response blob cache
        // that replaces large JSON payloads in SharedPreferences.
        await migrator.deleteTable('playback_states');
        await migrator.createTable(responseCache);
      }
    },
  );
}

// === Download Tasks Table ===

class DownloadTasks extends Table {
  @override
  String get tableName => 'download_tasks';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get episodeId => integer()();
  TextColumn get audioUrl => text()();
  TextColumn get localPath => text().nullable()();
  IntColumn get status => intEnum<DownloadStatus>().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// === Episodes Cache Table ===

class EpisodesCache extends Table {
  @override
  String get tableName => 'episodes_cache';

  IntColumn get id => integer()();
  IntColumn get subscriptionId => integer()();
  TextColumn get title => text()();
  TextColumn get audioUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get audioDuration => integer().nullable()();
  TextColumn get subscriptionTitle => text().nullable()();
  TextColumn get subscriptionImageUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// === Response Cache Table ===

/// Opaque JSON response blobs cached for instant rendering, keyed by a
/// composite cache key. Replaces large JSON payloads previously stored in
/// SharedPreferences so app startup does not have to load them into memory.
class ResponseCache extends Table {
  @override
  String get tableName => 'response_cache';

  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
