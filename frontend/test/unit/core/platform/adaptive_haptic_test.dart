import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/core/platform/adaptive_haptic.dart';

void main() {
  group('AdaptiveHaptic', () {
    Widget _buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AdaptiveHaptic.lightImpact(),
                    child: const Text('light'),
                  ),
                  ElevatedButton(
                    onPressed: () => AdaptiveHaptic.mediumImpact(),
                    child: const Text('medium'),
                  ),
                  ElevatedButton(
                    onPressed: () => AdaptiveHaptic.heavyImpact(),
                    child: const Text('heavy'),
                  ),
                  ElevatedButton(
                    onPressed: () => AdaptiveHaptic.selectionClick(),
                    child: const Text('selection'),
                  ),
                  ElevatedButton(
                    onPressed: () => AdaptiveHaptic.notificationSuccess(),
                    child: const Text('success'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    testWidgets('all haptic methods can be called without error', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // Each button should be tappable without throwing
      await tester.tap(find.text('light'));
      await tester.tap(find.text('medium'));
      await tester.tap(find.text('heavy'));
      await tester.tap(find.text('selection'));
      await tester.tap(find.text('success'));

      // No exceptions = pass
      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('lightImpact is callable in widget context', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.tap(find.text('light'));
      await tester.pump();
      expect(find.text('light'), findsOneWidget);
    });
  });
}
