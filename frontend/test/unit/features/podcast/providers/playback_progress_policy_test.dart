import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_playback_providers.dart';

void main() {
  group('normalizeResumePositionMs', () {
    test('restores seconds as milliseconds for normal progress', () {
      final result = normalizeResumePositionMs(120, 1800);
      expect(result, 120000);
    });

    test('keeps near-tail progress instead of resetting to zero', () {
      final result = normalizeResumePositionMs(1799, 1800);
      expect(result, 1799000);
    });
  });

  group('buildPersistPayload', () {
    test('keeps near-tail progress and current play state', () {
      final payload = buildPersistPayload(1799000, 1800000, true);
      expect(payload.positionSec, 1799);
      expect(payload.isPlaying, isTrue);
    });

    test('keeps normal middle progress with second rounding', () {
      final payload = buildPersistPayload(120400, 1800000, true);
      expect(payload.positionSec, 120);
      expect(payload.isPlaying, isTrue);
    });

    test('clamps negative milliseconds to zero seconds', () {
      final payload = buildPersistPayload(-1000, 1800000, false);
      expect(payload.positionSec, 0);
      expect(payload.isPlaying, isFalse);
    });

    test('clamps progress that exceeds duration', () {
      final payload = buildPersistPayload(2100000, 1800000, false);
      expect(payload.positionSec, 1800);
      expect(payload.isPlaying, isFalse);
    });
  });
}
