import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/constants/cache_constants.dart';
import 'package:sonde/features/podcast/data/models/profile_stats_model.dart';
import 'package:sonde/features/podcast/data/services/local_podcast_store.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';
import '../../../../helpers/local_store_fakes.dart';

void main() {
  group('ProfileStatsNotifier', () {
    test('uses fresh cache for repeated load', () async {
      final repository = _FakePodcastRepository(
        stats: <ProfileStatsModel>[_stats(10)],
      );
      final container = ProviderContainer(
        overrides: [localPlaybackStoreProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(profileStatsProvider.notifier);
      await notifier.load();
      await notifier.load();

      expect(repository.getProfileStatsCalls, 1);
      expect(container.read(profileStatsProvider).value?.totalEpisodes, 10);
    });

    test('forceRefresh bypasses cache and updates state', () async {
      final repository = _FakePodcastRepository(
        stats: <ProfileStatsModel>[_stats(10), _stats(20)],
      );
      final container = ProviderContainer(
        overrides: [localPlaybackStoreProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(profileStatsProvider.notifier);
      await notifier.load();
      await notifier.load(forceRefresh: true);

      expect(repository.getProfileStatsCalls, 2);
      expect(container.read(profileStatsProvider).value?.totalEpisodes, 20);
    });

    test('reloads after TTL expires', () {
      fakeAsync((async) {
        final repository = _FakePodcastRepository(
          stats: <ProfileStatsModel>[_stats(10), _stats(30)],
        );
        final container = ProviderContainer(
          overrides: [
            localPlaybackStoreProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(profileStatsProvider.notifier);
        async.run((_) {
          notifier.load();
        });
        async.flushMicrotasks();

        // Advance past the cache TTL
        async.elapse(CacheConstants.defaultListCacheDuration + const Duration(seconds: 1));

        async.run((_) {
          notifier.load();
        });
        async.flushMicrotasks();

        expect(repository.getProfileStatsCalls, 2);
        expect(container.read(profileStatsProvider).value?.totalEpisodes, 30);
      });
    });
  });
}

class _FakePodcastRepository extends ScriptedLocalPlaybackStore {
  _FakePodcastRepository({required List<ProfileStatsModel> stats})
    : _stats = List<ProfileStatsModel>.from(stats),
      super(profileStatsResponse: stats.isEmpty ? null : stats.first);

  final List<ProfileStatsModel> _stats;
  int getProfileStatsCalls = 0;

  @override
  Future<ProfileStatsModel> profileStats() async {
    final index = getProfileStatsCalls < _stats.length
        ? getProfileStatsCalls
        : _stats.length - 1;
    getProfileStatsCalls += 1;
    return _stats[index];
  }
}

ProfileStatsModel _stats(int totalEpisodes) {
  return ProfileStatsModel(
    totalSubscriptions: 1,
    totalEpisodes: totalEpisodes,
    summariesGenerated: 0,
    pendingSummaries: 0,
    playedEpisodes: 0,
  );
}
