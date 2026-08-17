import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_switch.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier() : super();

  @override
  AuthState build() {
    return const AuthState(
      
    );
  }
}

void main() {
  group('LoginPage Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(MockAuthNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget() {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginPage(),
        ),
      );
    }

    testWidgets('renders login form with all required fields', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for login button
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      // Check for email field
      expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
      // Check for remember me switch
      expect(find.byType(AdaptiveSwitch), findsOneWidget);
      // Check for app logo image
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('displays app logo and title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for logo (asset image)
      expect(find.byType(Image), findsOneWidget);

      // 品牌徽章已随 UI 改版移至 onboarding 页；登录页显示欢迎副标题。
      expect(find.text("Dawn's near. Let's begin."), findsOneWidget);
    });

    testWidgets('has login button with key', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_button')), findsOneWidget);
    });

    testWidgets('has switch for remember me', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveSwitch), findsOneWidget);
    });

    testWidgets('has text input fields for email and password', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
    });
  });
}
