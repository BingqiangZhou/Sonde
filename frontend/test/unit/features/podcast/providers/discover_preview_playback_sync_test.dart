import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';

void main() {
  group('discover preview playback sync guard', () {
    test(
      'discover preview episodes are detected and excluded from server sync',
      () {
        final discoverEpisode = _episodeWithMetadata({
          'discover_preview': true,
          'source': 'top_charts',
        });

        expect(isDiscoverPreviewEpisode(discoverEpisode), isTrue);
        expect(shouldSyncPlaybackToServer(discoverEpisode), isFalse);
      },
    );

    test('normal episodes remain eligible for server sync', () {
      final normalEpisode = _episodeWithMetadata({'source': 'library'});

      expect(isDiscoverPreviewEpisode(normalEpisode), isFalse);
      expect(shouldSyncPlaybackToServer(normalEpisode), isTrue);
    });
  });
}

PodcastEpisodeModel _episodeWithMetadata(Map<String, dynamic>? metadata) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Episode',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: DateTime(2026, 2, 14),
    createdAt: DateTime(2026, 2, 14),
    metadata: metadata,
  );
}
