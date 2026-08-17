import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/presentation/providers/audio_handler_logic.dart';

void main() {
  group('validateArtUri', () {
    test('accepts http and https URLs', () {
      expect(validateArtUri('http://example.com/art.jpg')?.scheme, 'http');
      expect(validateArtUri('https://example.com/art.jpg')?.scheme, 'https');
    });

    test('rejects null and empty input', () {
      expect(validateArtUri(null), isNull);
      expect(validateArtUri(''), isNull);
    });

    test('rejects non-http schemes for Vivo/OriginOS lock screens', () {
      expect(validateArtUri('asset://assets/logo.png'), isNull);
      expect(validateArtUri('file:///data/cache/art.jpg'), isNull);
      expect(validateArtUri('content://media/external/1'), isNull);
    });

    test('rejects malformed URLs', () {
      // Uri.tryParse is lenient with spaces; port out of range fails.
      expect(validateArtUri('http://example.com:not-a-port'), isNull);
    });
  });

  group('mapPlayerProcessingState', () {
    test('stopped and disposed map to idle', () {
      expect(
        mapPlayerProcessingState(PlayerState.stopped),
        AudioProcessingState.idle,
      );
      expect(
        mapPlayerProcessingState(PlayerState.disposed),
        AudioProcessingState.idle,
      );
    });

    test('playing and paused map to ready', () {
      expect(
        mapPlayerProcessingState(PlayerState.playing),
        AudioProcessingState.ready,
      );
      expect(
        mapPlayerProcessingState(PlayerState.paused),
        AudioProcessingState.ready,
      );
    });

    test('completed maps to completed', () {
      expect(
        mapPlayerProcessingState(PlayerState.completed),
        AudioProcessingState.completed,
      );
    });
  });

  group('buildMediaControls', () {
    test('full transport row when content is loaded', () {
      final controls = buildMediaControls(playing: true, hasContent: true);
      expect(controls, hasLength(3));
      expect(controls[0], MediaControl.rewind);
      expect(controls[1], MediaControl.pause);
      expect(controls[2], MediaControl.fastForward);
    });

    test('play button replaces pause when not playing', () {
      final controls = buildMediaControls(playing: false, hasContent: true);
      expect(controls[1], MediaControl.play);
    });

    test('lone play button when idle or loading', () {
      final controls = buildMediaControls(playing: false, hasContent: false);
      expect(controls, hasLength(1));
      expect(controls.single, MediaControl.play);
    });

    test('compact indices match control list length', () {
      expect(buildAndroidCompactActionIndices(hasContent: true), const [0, 1, 2]);
      expect(buildAndroidCompactActionIndices(hasContent: false), const [0]);
    });
  });

  group('clampSeek', () {
    const fifteen = Duration(seconds: 15);
    const thirty = Duration(seconds: 30);

    test('rewind clamps to zero below the start', () {
      expect(
        clampSeek(
          position: const Duration(seconds: 5),
          delta: -fifteen,
          duration: const Duration(minutes: 10),
        ),
        Duration.zero,
      );
    });

    test('rewind returns target when inside bounds', () {
      expect(
        clampSeek(
          position: const Duration(seconds: 40),
          delta: -fifteen,
          duration: const Duration(minutes: 10),
        ),
        const Duration(seconds: 25),
      );
    });

    test('fast forward clamps to duration', () {
      expect(
        clampSeek(
          position: const Duration(minutes: 9, seconds: 50),
          delta: thirty,
          duration: const Duration(minutes: 10),
        ),
        const Duration(minutes: 10),
      );
    });

    test('unknown duration clamps fast forward to zero (legacy behavior)', () {
      expect(
        clampSeek(
          position: const Duration(minutes: 1),
          delta: thirty,
        ),
        Duration.zero,
      );
    });
  });

  group('shouldEmitPositionTick', () {
    final base = DateTime(2026, 1, 1, 12);

    test('emits when 500ms elapsed since last broadcast', () {
      expect(
        shouldEmitPositionTick(
          now: base.add(const Duration(milliseconds: 600)),
          lastEmitAt: base,
          lastEmittedPosition: const Duration(seconds: 10),
          position: const Duration(seconds: 10, milliseconds: 200),
        ),
        isTrue,
      );
    });

    test('emits when the position jumped by at least 1s (explicit seek)', () {
      expect(
        shouldEmitPositionTick(
          now: base.add(const Duration(milliseconds: 100)),
          lastEmitAt: base,
          lastEmittedPosition: const Duration(seconds: 10),
          position: const Duration(seconds: 12),
        ),
        isTrue,
      );
    });

    test('skips small backward position drift within the window', () {
      expect(
        shouldEmitPositionTick(
          now: base.add(const Duration(milliseconds: 100)),
          lastEmitAt: base,
          lastEmittedPosition: const Duration(seconds: 10),
          position: const Duration(seconds: 9, milliseconds: 900),
        ),
        isFalse,
      );
    });
  });
}
