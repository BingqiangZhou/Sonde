import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/data/models/audio_player_state_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_playback_model.dart';
import 'package:sonde/features/podcast/data/services/local_podcast_store.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';
import '../../../../helpers/local_store_fakes.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerNotifier playback-rate sync', () {
    test('uses server effective rate for speed sheet state', () async {
      final store = _TrackingPodcastRepository(
        effectiveResponse: const PlaybackRateEffectiveResponse(
          globalPlaybackRate: 1,
          subscriptionPlaybackRate: 1.5,
          effectivePlaybackRate: 1.5,
          source: 'subscription',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(
              AudioPlayerState(
                currentEpisode: _episode(playbackRate: 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(audioPlayerProvider.notifier);
      final selection = await notifier
          .resolvePlaybackRateSelectionForCurrentContext();

      expect(selection.speed, 1.5);
      expect(selection.applyToSubscription, isTrue);
      expect(store.effectivePlaybackRateRequests, <int?>[1]);
    });

    test('sync speed sheet snapshot falls back to local playback state', () {
      final store = _TrackingPodcastRepository(
        effectivePlaybackRateError: Exception('offline'),
      );
      final container = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(
              AudioPlayerState(
                currentEpisode: _episode(playbackRate: 1.25),
                playbackRate: 1.25,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = container
          .read(audioPlayerProvider.notifier)
          .getPlaybackRateSelectionSnapshot();

      expect(snapshot.speed, 1.25);
      expect(snapshot.applyToSubscription, isFalse);
      expect(store.effectivePlaybackRateRequests, isEmpty);
    });

    test(
      'falls back to current state when resolving effective rate fails',
      () async {
        final store = _TrackingPodcastRepository(
          effectivePlaybackRateError: Exception('offline'),
        );
        final container = ProviderContainer(
          overrides: [
            localPlaybackStoreProvider.overrideWithValue(store),
            audioPlayerProvider.overrideWith(
              () => _TestAudioPlayerNotifier(
                AudioPlayerState(
                  currentEpisode: _episode(playbackRate: 1.25),
                  playbackRate: 1.25,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        final selection = await notifier
            .resolvePlaybackRateSelectionForCurrentContext();

        expect(selection.speed, 1.25);
        expect(selection.applyToSubscription, isFalse);
        expect(store.effectivePlaybackRateRequests, <int?>[1]);
      },
    );

    test('resume refreshes audio speed from server before playing', () async {
      final store = _TrackingPodcastRepository(
        effectiveResponse: const PlaybackRateEffectiveResponse(
          globalPlaybackRate: 1,
          subscriptionPlaybackRate: 1.75,
          effectivePlaybackRate: 1.75,
          source: 'subscription',
        ),
      );
      final notifier = _TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(playbackRate: 1),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          localQueueStoreProvider.overrideWithValue(ScriptedLocalQueueStore()),
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      await container.read(audioPlayerProvider.notifier).resume();

      expect(store.effectivePlaybackRateRequests, <int?>[1]);
      expect(notifier.audioSpeedCalls, <double>[1.75]);
      expect(notifier.playAudioCalls, 1);
      expect(container.read(audioPlayerProvider).playbackRate, 1.75);
      expect(store.updatePlaybackProgressCalls, 1);
    });

    test(
      'resume falls back to local playback rate when server lookup fails',
      () async {
        final store = _TrackingPodcastRepository(
          effectivePlaybackRateError: Exception('offline'),
        );
        final notifier = _TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(playbackRate: 1.25),
            playbackRate: 1.25,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            localPlaybackStoreProvider.overrideWithValue(store),
            localQueueStoreProvider.overrideWithValue(ScriptedLocalQueueStore()),
            audioPlayerProvider.overrideWith(() => notifier),
          ],
        );
        addTearDown(container.dispose);

        await container.read(audioPlayerProvider.notifier).resume();

        expect(store.effectivePlaybackRateRequests, <int?>[1]);
        expect(notifier.audioSpeedCalls, <double>[1.25]);
        expect(notifier.playAudioCalls, 1);
        expect(container.read(audioPlayerProvider).playbackRate, 1.25);
      },
    );

    test('setPlaybackRate refreshes cached speed selection snapshot', () async {
      final store = _TrackingPodcastRepository();
      final notifier = _TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(playbackRate: 1),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          localQueueStoreProvider.overrideWithValue(ScriptedLocalQueueStore()),
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioPlayerProvider.notifier)
          .setPlaybackRate(1.75, applyToSubscription: true);

      final snapshot = container
          .read(audioPlayerProvider.notifier)
          .getPlaybackRateSelectionSnapshot();

      expect(store.applyPlaybackRateCalls, 1);
      expect(snapshot.speed, 1.75);
      expect(snapshot.applyToSubscription, isTrue);
      expect(container.read(audioPlayerProvider).playbackRate, 1.75);
    });

    test(
      'sleep timer remains session-local and does not hit repository',
      () async {
        final store = _TrackingPodcastRepository();
        final container = ProviderContainer(
          overrides: [
              audioPlayerProvider.overrideWith(
              () => _TestAudioPlayerNotifier(const AudioPlayerState()),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        notifier.setSleepTimer(const Duration(minutes: 5));
        notifier.cancelSleepTimer();

        expect(container.read(audioPlayerProvider).isSleepTimerActive, isFalse);
        expect(store.effectivePlaybackRateRequests, isEmpty);
        expect(store.applyPlaybackRateCalls, 0);
        expect(store.updatePlaybackProgressCalls, 0);
      },
    );

    test('sleep timer is cleared after provider rebuild', () async {
      final store = _TrackingPodcastRepository();
      final firstContainer = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(const AudioPlayerState()),
          ),
        ],
      );
      addTearDown(firstContainer.dispose);

      firstContainer
          .read(audioPlayerProvider.notifier)
          .setSleepTimer(const Duration(minutes: 5));
      expect(
        firstContainer.read(audioPlayerProvider).isSleepTimerActive,
        isTrue,
      );

      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [
          localPlaybackStoreProvider.overrideWithValue(store),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(const AudioPlayerState()),
          ),
        ],
      );
      addTearDown(secondContainer.dispose);

      expect(
        secondContainer.read(audioPlayerProvider).isSleepTimerActive,
        isFalse,
      );
    });
  });
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;
  final List<double> audioSpeedCalls = <double>[];
  int playAudioCalls = 0;

  @override
  AudioPlayerState build() {
    // Intentionally skip super.build() to avoid initializing the real audio
    // handler and auth provider, which are not needed for unit tests.
    return _initialState;
  }

  @override
  Future<void> setAudioSpeed(double rate) async {
    audioSpeedCalls.add(rate);
  }

  @override
  Future<void> playAudio() async {
    playAudioCalls += 1;
  }
}

class _TrackingPodcastRepository extends ScriptedLocalPlaybackStore {
  _TrackingPodcastRepository({
    PlaybackRateEffectiveResponse? effectiveResponse,
    Object? effectivePlaybackRateError,
  }) : super(
          effectiveRateResponse:
              effectiveResponse ??
              const PlaybackRateEffectiveResponse(
                globalPlaybackRate: 1,
                subscriptionPlaybackRate: null,
                effectivePlaybackRate: 1,
                source: 'global',
              ),
          effectiveRateError: effectivePlaybackRateError,
          applyRateResponse: effectiveResponse,
        );

  int get updatePlaybackProgressCalls => savedProgress.length;
  int get applyPlaybackRateCalls => appliedRates.length;
  List<int?> get effectivePlaybackRateRequests => super.effectiveRateRequests;
}


PodcastEpisodeModel _episode({required double playbackRate}) {
  final now = DateTime(2026, 3, 12);
  return PodcastEpisodeModel(
    id: 7,
    subscriptionId: 1,
    title: 'Episode',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    playbackRate: playbackRate,
    createdAt: now,
  );
}
