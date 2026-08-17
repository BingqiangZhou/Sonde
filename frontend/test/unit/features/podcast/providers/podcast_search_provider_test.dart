import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/features/podcast/data/models/podcast_search_model.dart';
import 'package:sonde/features/podcast/data/services/itunes_search_service.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';
import '../../../../helpers/mock_local_storage_service.dart';

void main() {
  test('search debounce collapses rapid podcast queries into one request', () {
    fakeAsync((async) {
      final service = _FakeITunesSearchService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          iTunesSearchServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = container.listen(
        podcastSearchProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });

      final notifier = container.read(podcastSearchProvider.notifier);
      notifier.searchPodcasts('flutter');

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(service.podcastSearchCallCount, 0);

      notifier.searchPodcasts('flutter riverpod');
      async.elapse(const Duration(milliseconds: 399));
      async.flushMicrotasks();
      expect(service.podcastSearchCallCount, 0);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();

      expect(service.podcastSearchCallCount, 1);
      expect(container.read(podcastSearchProvider).currentQuery, 'flutter riverpod');
    });
  });
}

class _FakeITunesSearchService extends ITunesSearchService {
  int podcastSearchCallCount = 0;

  @override
  Future<ITunesSearchResponse> searchPodcasts({
    required String term,
    PodcastCountry country = PodcastCountry.china,
    int limit = 25,
  }) async {
    podcastSearchCallCount += 1;
    return const ITunesSearchResponse(resultCount: 0, results: []);
  }
}
