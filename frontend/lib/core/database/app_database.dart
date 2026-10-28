import 'package:drift/drift.dart';
import 'package:sonde/core/database/dao/download_dao.dart';
import 'package:sonde/core/database/dao/episode_cache_dao.dart';
import 'package:sonde/core/database/dao/playback_dao.dart';

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
  tables: [DownloadTasks, PlaybackStates, EpisodesCache],
  daos: [DownloadDao, PlaybackDao, EpisodeCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

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

// === Playback States Table ===

class PlaybackStates extends Table {
  @override
  String get tableName => 'playback_states';

  IntColumn get episodeId => integer()();
  IntColumn get positionSeconds =>
      integer().withDefault(const Constant(0))();
  RealColumn get playbackRate =>
      real().withDefault(const Constant(1))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {episodeId};
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
