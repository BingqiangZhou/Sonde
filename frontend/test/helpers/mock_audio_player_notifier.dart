import 'package:sonde/features/podcast/data/models/audio_player_state_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';

class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  MockAudioPlayerNotifier([this._initialState = const AudioPlayerState()]);

  final AudioPlayerState _initialState;

  /// The last episode passed to [playEpisode], for assertion in tests.
  PodcastEpisodeModel? lastPlayedEpisode;

  @override
  AudioPlayerState build() => _initialState;

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {
    lastPlayedEpisode = episode;
  }

  @override
  Future<void> playManagedEpisode(PodcastEpisodeModel episode) async {}
}

/// Teardown function that creates a [MockAudioPlayerNotifier] without arguments,
/// suitable for use as a `overrideWith` factory.
AudioPlayerNotifier mockAudioPlayerNotifierFactory() =>
    MockAudioPlayerNotifier();
