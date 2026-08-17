import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/widgets/adaptive/adaptive_dismissible.dart';

void main() {
  group('AdaptiveDismissible', () {
    Widget buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
      VoidCallback? onDelete,
    }) {
      return MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        builder: (context, child) {
          return CupertinoTheme(
            data: const CupertinoThemeData(),
            child: child!,
          );
        },
        home: Scaffold(
          body: AdaptiveDismissible(
            key: const Key('test'),
            onDelete: onDelete ?? () {},
            child: const ListTile(title: Text('Swipe me')),
          ),
        ),
      );
    }

    testWidgets('renders Dismissible on both platforms', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(Dismissible), findsOneWidget);
      expect(find.text('Swipe me'), findsOneWidget);
    });

    testWidgets('renders child content correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.text('Swipe me'), findsOneWidget);
    });
  });
}
