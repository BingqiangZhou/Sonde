import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/widgets/adaptive/adaptive_text_field.dart';

void main() {
  group('AdaptiveTextField', () {
    Widget buildTestWidget({
      TargetPlatform platform = TargetPlatform.android,
      String? placeholder,
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
          body: AdaptiveTextField(
            controller: TextEditingController(),
            placeholder: placeholder ?? 'Enter text',
          ),
        ),
      );
    }

    testWidgets('renders Material TextField on Android', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(),
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders CupertinoTextField on iOS', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(platform: TargetPlatform.iOS),
      );
      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(placeholder: 'Search...'),
      );
      expect(find.text('Search...'), findsOneWidget);
    });
  });
}
