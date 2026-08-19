import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import 'package:sonde/core/database/app_database.dart';
import 'package:sonde/core/database/database_provider.dart';
import 'package:sonde/core/services/audio_download_service.dart';

/// Provides the [AudioDownloadService] singleton.
final downloadManagerProvider = Provider<AudioDownloadService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = AudioDownloadService(db);

  ref.onDispose(service.dispose);

  return service;
});

/// Watches the download status for a specific episode.
///
/// Returns null if no download task exists for this episode.
final StreamProviderFamily<DownloadTask?, int> episodeDownloadStatusProvider =
    StreamProvider.family<DownloadTask?, int>((ref, episodeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.downloadDao.watchByEpisodeId(episodeId);
});
