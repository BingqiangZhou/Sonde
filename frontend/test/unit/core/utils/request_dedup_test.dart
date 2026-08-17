import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/utils/request_dedup.dart';

void main() {
  group('InFlightSlot', () {
    test('concurrent calls share one fetch', () async {
      final slot = InFlightSlot<int>();
      var fetchCount = 0;

      final first = slot(() async {
        fetchCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 42;
      });
      final second = slot(() async {
        fetchCount++;
        return -1;
      });

      expect(await first, 42);
      expect(await second, 42);
      expect(fetchCount, 1);
    });

    test('slot is reusable after completion', () async {
      final slot = InFlightSlot<int>();
      var fetchCount = 0;

      Future<int> fetch() async {
        return ++fetchCount;
      }

      expect(await slot(fetch), 1);
      expect(await slot(fetch), 2);
    });

    test('slot is reusable after failure', () async {
      final slot = InFlightSlot<int>();

      await expectLater(
        slot(() => Future<int>.error(StateError('boom'))),
        throwsStateError,
      );
      expect(slot.inFlight, isNull);
      expect(await slot(() async => 7), 7);
    });

    test('a failed fetch is joined by concurrent callers', () async {
      final slot = InFlightSlot<int>();
      var fetchCount = 0;

      Future<int> failing() async {
        fetchCount++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('boom');
      }

      final first = slot(failing);
      final second = slot(failing);

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      expect(fetchCount, 1);
    });

    test('reset drops the running future without failing it', () async {
      final slot = InFlightSlot<int>();

      final future = slot(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 1;
      });
      slot.reset();
      expect(slot.inFlight, isNull);

      // The original caller still gets its result.
      expect(await future, 1);

      // A new call starts a fresh fetch rather than joining the reset one.
      expect(await slot(() async => 2), 2);
    });

    test('completed slot keeps clearing only its own future', () async {
      final slot = InFlightSlot<int>();

      final slow = slot(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return 1;
      });
      // A reset-then-new-call sequence: the slow future completing must not
      // clobber the newer in-flight entry.
      slot.reset();
      final fast = slot(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 2;
      });

      expect(await fast, 2);
      expect(await slow, 1);
      expect(slot.inFlight, isNull);
    });
  });

  group('FreshnessTracker', () {
    test('starts stale', () {
      expect(FreshnessTracker().isFresh, isFalse);
    });

    test('fresh after success within maxAge', () {
      withClock(Clock.fixed(DateTime(2026)), () {
        final tracker = FreshnessTracker()..markSuccess();

        expect(tracker.isFresh, isTrue);
      });
    });

    test('stale once maxAge elapsed', () {
      final base = DateTime(2026);
      final tracker = FreshnessTracker();
      withClock(Clock.fixed(base), tracker.markSuccess);
      expect(
        withClock(Clock.fixed(base.add(const Duration(minutes: 4))), () {
          return tracker.isFresh;
        }),
        isTrue,
      );
      expect(
        withClock(Clock.fixed(base.add(const Duration(minutes: 6))), () {
          return tracker.isFresh;
        }),
        isFalse,
      );
    });

    test('reset makes data stale again', () {
      withClock(Clock.fixed(DateTime(2026)), () {
        final tracker = FreshnessTracker()..markSuccess();
        tracker.reset();
        expect(tracker.isFresh, isFalse);
      });
    });

    test('custom maxAge is respected', () {
      final base = DateTime(2026);
      final tracker = FreshnessTracker(maxAge: const Duration(seconds: 1));
      withClock(Clock.fixed(base), tracker.markSuccess);
      expect(
        withClock(Clock.fixed(base.add(const Duration(milliseconds: 999))), () {
          return tracker.isFresh;
        }),
        isTrue,
      );
      expect(
        withClock(Clock.fixed(base.add(const Duration(seconds: 2))), () {
          return tracker.isFresh;
        }),
        isFalse,
      );
    });
  });

  group('RequestToken', () {
    test('begin returns increasing tokens', () {
      final token = RequestToken();
      expect(token.begin(), 1);
      expect(token.begin(), 2);
      expect(token.begin(), 3);
    });

    test('isCurrent only for the latest token', () {
      final token = RequestToken();
      final first = token.begin();
      final second = token.begin();

      expect(token.isCurrent(first), isFalse);
      expect(token.isCurrent(second), isTrue);
    });

    test('cancel invalidates outstanding tokens', () {
      final token = RequestToken();
      final outstanding = token.begin();
      token.cancel();

      expect(token.isCurrent(outstanding), isFalse);
    });
  });
}
