import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/providers/route_provider.dart';
import 'package:sonde/features/podcast/data/models/audio_player_state_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_episode_model.dart';
import 'package:sonde/features/podcast/data/models/podcast_queue_model.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:sonde/features/podcast/presentation/widgets/podcast_queue_sheet.dart';
import 'package:sonde/features/podcast/presentation/widgets/selector_sheet_common.dart';

import '../../helpers/podcast_episode_detail_helper.dart';

void main() {
  group('PodcastBottomPlayerWidget', () {
    testWidgets('dock info tap expands into mobile sheet', (tester) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_info')),
      );
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isTrue);
      expect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );
    });

    testWidgets('expanded sheet fills the entire viewport', (tester) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final sheetRect = tester.getRect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
      );
      expect(sheetRect, const Rect.fromLTWH(0, 0, 390, 844));

      // Bottom controls stay inside the page above its bottom padding.
      final transportRect = tester.getRect(
        find.byKey(const Key('podcast_bottom_player_play_pause')),
      );
      expect(transportRect.bottom, lessThan(844));
      expect(transportRect.bottom, greaterThan(700));
    });

    testWidgets('dock playlist button opens queue sheet directly', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_playlist')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastQueueSheet), findsOneWidget);
      expect(queueController.queueOpenPreparationCalls, 1);

      Navigator.of(tester.element(find.byType(PodcastQueueSheet))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'dock playlist button ignores repeated taps while sheet is open',
      (tester) async {
        _setMobileViewport(tester);
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        );
        final queueController = TestPodcastQueueController();
        final uiNotifier = TestPodcastPlayerUiNotifier();

        await tester.pumpWidget(
          _createWidget(
            audioNotifier: audioNotifier,
            queueController: queueController,
            uiNotifier: uiNotifier,
          ),
        );
        await tester.pumpAndSettle();

        final playlistButton = find.byKey(
          const Key('podcast_bottom_player_mini_playlist'),
        );
        await tester.tap(playlistButton);
        await tester.tap(playlistButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(PodcastQueueSheet), findsOneWidget);
        expect(queueController.loadQueueCalls, 1);
        expect(uiNotifier.state.queueSheetOpen, isTrue);

        Navigator.of(tester.element(find.byType(PodcastQueueSheet))).pop();
        await tester.pumpAndSettle();

        expect(uiNotifier.state.queueSheetOpen, isFalse);
      },
    );

    testWidgets(
      'dock playlist button opens queue sheet before refresh finishes',
      (tester) async {
        _setMobileViewport(tester);
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        );
        final queueController = PendingRefreshPodcastQueueController();
        final uiNotifier = TestPodcastPlayerUiNotifier();

        await tester.pumpWidget(
          _createWidget(
            audioNotifier: audioNotifier,
            queueController: queueController,
            uiNotifier: uiNotifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('podcast_bottom_player_mini_playlist')),
        );
        await tester.pump();

        expect(find.byType(PodcastQueueSheet), findsOneWidget);
        expect(queueController.loadQueueCalls, 1);

        queueController.completeLoad();
        Navigator.of(tester.element(find.byType(PodcastQueueSheet))).pop();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'expanded playlist button ignores repeated taps while sheet is open',
      (tester) async {
        _setMobileViewport(tester);
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        );
        final queueController = TestPodcastQueueController();
        final uiNotifier = TestPodcastPlayerUiNotifier(
          const PodcastPlayerUiState(
            presentation: PodcastPlayerPresentation.expanded,
          ),
        );

        await tester.pumpWidget(
          _createWidget(
            audioNotifier: audioNotifier,
            queueController: queueController,
            uiNotifier: uiNotifier,
          ),
        );
        await tester.pumpAndSettle();

        final playlistButton = find.byKey(
          const Key('podcast_bottom_player_playlist'),
        );
        await tester.tap(playlistButton);
        await tester.tap(playlistButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(PodcastQueueSheet), findsOneWidget);
        expect(queueController.loadQueueCalls, 1);
        expect(uiNotifier.state.queueSheetOpen, isTrue);

        Navigator.of(tester.element(find.byType(PodcastQueueSheet))).pop();
        await tester.pumpAndSettle();

        expect(uiNotifier.state.queueSheetOpen, isFalse);
      },
    );

    testWidgets('expanded page arranges top bar and bottom action rows', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(
        const Key('podcast_bottom_player_collapse'),
      );
      final sleepButton = find.byKey(const Key('podcast_bottom_player_sleep'));
      final speedChip = find.byKey(const Key('podcast_bottom_player_speed'));
      final playlistButton = find.byKey(
        const Key('podcast_bottom_player_playlist'),
      );
      final playPauseButton = find.byKey(
        const Key('podcast_bottom_player_play_pause'),
      );

      expect(sleepButton, findsOneWidget);
      expect(playlistButton, findsOneWidget);
      // Top bar: collapse chevron on the left, sleep timer on the right.
      expect(
        (tester.getCenter(sleepButton).dy -
                tester.getCenter(collapseButton).dy)
            .abs(),
        lessThan(20),
      );
      expect(
        tester.getCenter(sleepButton).dx > tester.getCenter(collapseButton).dx,
        isTrue,
      );
      // Secondary row: speed chip and queue share the bottom action row,
      // below the transport controls.
      expect(
        (tester.getCenter(speedChip).dy - tester.getCenter(playlistButton).dy)
            .abs(),
        lessThan(20),
      );
      expect(
        tester.getCenter(speedChip).dx < tester.getCenter(playlistButton).dx,
        isTrue,
      );
      expect(
        tester.getCenter(playlistButton).dy >
            tester.getCenter(playPauseButton).dy,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();
      expect(find.text('Playback Speed'), findsOneWidget);
      Navigator.of(tester.element(find.text('Playback Speed'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_sleep')));
      await tester.pumpAndSettle();
      expect(find.text('Sleep Timer'), findsOneWidget);
    });

    testWidgets('sleep timer sheet shows preset pills and tinted actions', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_sleep')));
      await tester.pumpAndSettle();

      // Duration presets render as pills.
      expect(find.byKey(const Key('sleep_timer_option_5')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_option_90')), findsOneWidget);
      // Timer inactive: after-episode action shown, cancel action hidden.
      expect(find.text('Stop after this episode'), findsOneWidget);
      expect(find.text('Cancel timer'), findsNothing);

      // Header close button dismisses the sheet.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sleep Timer'), findsNothing);
    });

    testWidgets('expanded content is no longer wrapped by internal cards', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
        findsOneWidget,
      );

      final heroWidget = tester.widget(
        find.byKey(const Key('podcast_bottom_player_expanded_hero')),
      );
      final progressWidget = tester.widget(
        find.byKey(const Key('podcast_bottom_player_expanded_progress')),
      );

      expect(heroWidget, isA<Column>());
      expect(progressWidget, isA<Column>());
    });

    testWidgets('expanded hero stacks large centered artwork above title', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final sheetRect = tester.getRect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
      );
      final coverRect = tester.getRect(
        find.byKey(const Key('podcast_bottom_player_expanded_cover')),
      );
      final titleRect = tester.getRect(
        find.byKey(const Key('podcast_bottom_player_expanded_title_text')),
      );
      final metaRect = tester.getRect(
        find.byKey(const Key('podcast_bottom_player_expanded_meta')),
      );

      // Square, prominently sized, horizontally centered artwork.
      expect(coverRect.width, greaterThan(200));
      expect(coverRect.height, closeTo(coverRect.width, 0.1));
      expect(
        (coverRect.center.dx - sheetRect.center.dx).abs(),
        lessThan(2),
      );
      // Title and meta stack below the artwork, both centered.
      expect(titleRect.top, greaterThan(coverRect.bottom));
      expect(metaRect.top, greaterThan(titleRect.bottom));
      expect(
        (titleRect.center.dx - sheetRect.center.dx).abs(),
        lessThan(2),
      );
    });

    testWidgets('non-home embedded route paints reserved background', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PodcastPlayerLayoutFrame)),
        listen: false,
      );
      container.read(currentRouteProvider.notifier).setRoute('/detail');
      await tester.pumpAndSettle();

      final backgroundFinder = find.byKey(
        const Key('podcast_player_reserved_background'),
      );
      expect(backgroundFinder, findsOneWidget);
      expect(tester.widget<SizedBox>(backgroundFinder).height, greaterThan(0));
    });

    // TODO: fix showAdaptiveSheet navigation context in tests
    testWidgets(
      'speed sheet uses server-backed initial selection state',
      skip: true,
      (tester,) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        playbackRateSelection: (speed: 1.5, applyToSubscription: true),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();

      final subscriptionCheckbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final speedPill = tester.widget<SelectorOptionPill>(
        find.byKey(const Key('playback_speed_option_1.5x')),
      );

      expect(subscriptionCheckbox.value, isTrue);
      expect(speedPill.selected, isTrue);
      expect(audioNotifier.resolvePlaybackRateSelectionCalls, 1);
    });

    // TODO: fix showAdaptiveSheet navigation context in tests
    testWidgets(
      'speed sheet opens before remote selection finishes',
      skip: true,
      (tester) async {
      _setMobileViewport(tester);
      final selectionCompleter = Completer<PlaybackRateSelectionSnapshot>();
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        playbackRateSelectionFuture: selectionCompleter.future,
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();

      expect(find.text('Playback Speed'), findsOneWidget);
      expect(audioNotifier.resolvePlaybackRateSelectionCalls, 1);

      selectionCompleter.complete((speed: 1.5, applyToSubscription: true));
      await tester.pumpAndSettle();
    });

    // TODO: fix showAdaptiveSheet navigation context in tests
    testWidgets(
      'speed sheet applies remote correction before interaction',
      skip: true,
      (tester) async {
      _setMobileViewport(tester);
      final selectionCompleter = Completer<PlaybackRateSelectionSnapshot>();
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        playbackRateSelectionFuture: selectionCompleter.future,
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();

      selectionCompleter.complete((speed: 1.5, applyToSubscription: true));
      await tester.pumpAndSettle();

      final subscriptionCheckbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final speedPill = tester.widget<SelectorOptionPill>(
        find.byKey(const Key('playback_speed_option_1.5x')),
      );

      expect(subscriptionCheckbox.value, isTrue);
      expect(speedPill.selected, isTrue);
    });

    testWidgets('user speed choice is not overwritten by late correction', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final selectionCompleter = Completer<PlaybackRateSelectionSnapshot>();
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        playbackRateSelectionFuture: selectionCompleter.future,
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('playback_speed_option_2x')));
      await tester.pumpAndSettle();

      selectionCompleter.complete((speed: 1.5, applyToSubscription: true));
      await tester.pumpAndSettle();

      final subscriptionCheckbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      final selectedSpeedPill = tester.widget<SelectorOptionPill>(
        find.byKey(const Key('playback_speed_option_2x')),
      );

      expect(subscriptionCheckbox.value, isFalse);
      expect(selectedSpeedPill.selected, isTrue);
    });

    testWidgets('expanded transport controls seek and toggle playback', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          position: 45000,
        ),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(
        find.byKey(const Key('podcast_bottom_player_progress_slider')),
      );
      slider.onChangeStart?.call(60000);
      slider.onChanged?.call(60000);
      await tester.pump();
      expect(audioNotifier.seekToPositions, isEmpty);

      slider.onChangeEnd?.call(60000);
      await tester.pumpAndSettle();
      expect(audioNotifier.seekToPositions, <int>[60000]);

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_play_pause')),
      );
      await tester.pumpAndSettle();
      expect(audioNotifier.resumeCalls, 1);
    });

    testWidgets('dragging mobile handle collapses expanded sheet', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('podcast_bottom_player_drag_handle')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets('desktop layout uses the same mobile sheet pattern', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createDesktopFrameWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
        findsOneWidget,
      );
      expect(find.text('Player'), findsNothing);
      expect(find.text('Playback Console'), findsNothing);
    });

    testWidgets('expanded title tap navigates to episode detail', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createRouterWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_expanded_title')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episode Detail Page'), findsOneWidget);
    });
  });
}

Widget _createDesktopFrameWidget({
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastQueueController queueController,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
      podcastPlayerUiProvider.overrideWith(() => uiNotifier),
    ],
    child: const MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PodcastPlayerLayoutFrame(child: Scaffold(body: SizedBox())),
    ),
  );
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _createWidget({
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastQueueController queueController,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
      podcastPlayerUiProvider.overrideWith(() => uiNotifier),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(podcastQueueControllerProvider);
          return const PodcastPlayerLayoutFrame(
            child: Scaffold(body: SizedBox.shrink()),
          );
        },
      ),
    ),
  );
}

Widget _createRouterWidget({
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastQueueController queueController,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PodcastPlayerLayoutFrame(
          child: Scaffold(body: Text('Home Page')),
        ),
      ),
      GoRoute(
        name: 'episodeDetail',
        path: '/podcast/episode/detail/:episodeId',
        builder: (context, state) => const PodcastPlayerLayoutFrame(
          child: Scaffold(body: Text('Episode Detail Page')),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
      podcastPlayerUiProvider.overrideWith(() => uiNotifier),
    ],
    child: MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

PodcastEpisodeModel _episode({
  String title = 'Test Episode',
  String? subscriptionTitle = 'Test Podcast',
}) {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: title,
    description: 'Description',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    subscriptionTitle: subscriptionTitle,
    createdAt: now,
  );
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(
    this._initialState, {
    this.playbackRateSelection = const (speed: 1.0, applyToSubscription: false),
    PlaybackRateSelectionSnapshot? playbackRateSelectionSnapshot,
    this.playbackRateSelectionFuture,
  }) : playbackRateSelectionSnapshot =
           playbackRateSelectionSnapshot ??
           (speed: _initialState.playbackRate, applyToSubscription: false);

  final AudioPlayerState _initialState;
  final PlaybackRateSelectionSnapshot playbackRateSelection;
  final PlaybackRateSelectionSnapshot playbackRateSelectionSnapshot;
  final Future<PlaybackRateSelectionSnapshot>? playbackRateSelectionFuture;
  final List<int> seekToPositions = <int>[];
  int pauseCalls = 0;
  int resumeCalls = 0;
  int resolvePlaybackRateSelectionCalls = 0;

  @override
  AudioPlayerState build() => _initialState;

  @override
  Future<void> seekTo(int position) async {
    seekToPositions.add(position);
    state = state.copyWith(position: position);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    state = state.copyWith(isPlaying: true);
  }

  @override
  PlaybackRateSelectionSnapshot getPlaybackRateSelectionSnapshot() {
    return playbackRateSelectionSnapshot;
  }

  @override
  Future<PlaybackRateSelectionSnapshot>
  resolvePlaybackRateSelectionForCurrentContext() async {
    resolvePlaybackRateSelectionCalls += 1;
    return playbackRateSelectionFuture ?? playbackRateSelection;
  }
}

class TestPodcastQueueController extends PodcastQueueController {
  int refreshQueueInBackgroundCalls = 0;
  int loadQueueCalls = 0;

  int get queueOpenPreparationCalls =>
      refreshQueueInBackgroundCalls + loadQueueCalls;

  @override
  Future<PodcastQueueModel> build() async => PodcastQueueModel.empty();

  @override
  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    loadQueueCalls += 1;
    state = const AsyncValue.data(PodcastQueueModel());
    return PodcastQueueModel.empty();
  }

  @override
  Future<void> refreshQueueInBackground() async {
    refreshQueueInBackgroundCalls += 1;
    state = const AsyncValue.data(PodcastQueueModel());
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return PodcastQueueModel.empty();
  }
}

class PendingRefreshPodcastQueueController extends TestPodcastQueueController {
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    loadQueueCalls += 1;
    await _loadCompleter.future;
    state = const AsyncValue.data(PodcastQueueModel());
    return PodcastQueueModel.empty();
  }

  void completeLoad() {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }
}
