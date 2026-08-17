import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';

void main() {
  group('AdaptiveHaptic', () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return const Column(
                children: [
                  ElevatedButton(
                    onPressed: AdaptiveHaptic.lightImpact,
                    child: Text('light'),
                  ),
                  ElevatedButton(
                    onPressed: AdaptiveHaptic.mediumImpact,
                    child: Text('medium'),
                  ),
                  ElevatedButton(
                    onPressed: AdaptiveHaptic.heavyImpact,
                    child: Text('heavy'),
                  ),
                  ElevatedButton(
                    onPressed: AdaptiveHaptic.selectionClick,
                    child: Text('selection'),
                  ),
                  ElevatedButton(
                    onPressed: AdaptiveHaptic.notificationSuccess,
                    child: Text('success'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    testWidgets('all haptic methods can be called without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());

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
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('light'));
      await tester.pump();
      expect(find.text('light'), findsOneWidget);
    });
  });
}
