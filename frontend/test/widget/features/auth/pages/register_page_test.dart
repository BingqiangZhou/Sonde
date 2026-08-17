import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/widgets/adaptive/adaptive_switch.dart';
import 'package:sonde/features/auth/presentation/pages/register_page.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier() : super();

  @override
  AuthState build() {
    return const AuthState();
  }
}

void main() {
  group('RegisterPage Widget Tests', () {
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
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegisterPage(),
        ),
      );
    }

    testWidgets('renders register form without a name field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for register button
      expect(find.byKey(const Key('register_button')), findsOneWidget);

      // Text input fields: Email (CustomTextField -> TextFormField),
      // Password (PasswordTextField -> CustomTextField -> TextFormField),
      // Confirm Password (PasswordTextField -> CustomTextField -> TextFormField)
      // Total: 3 TextFormField widgets — no name field at signup
      expect(find.byType(TextFormField), findsNWidgets(3));

      // The name label is gone from the form
      expect(find.text('Full Name'), findsNothing);

      // Check for adaptive switches: Remember Me + Terms agreement
      expect(find.byType(AdaptiveSwitch), findsNWidgets(2));
    });

    testWidgets('shows auto-generated nickname hint', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('generate a nickname'),
        findsOneWidget,
      );
    });

    testWidgets('displays header icon and title text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for person_add icon in the header container
      expect(find.byIcon(Icons.person_add), findsOneWidget);

      // Check for title text "Create Account" (appears in AuthShell title and button)
      expect(find.text('Create Account'), findsAtLeast(1));

      // Check for subtitle text "Join us to get started"
      expect(find.text('Join us to get started'), findsOneWidget);
    });

    testWidgets('has register button with proper key', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_button')), findsOneWidget);
    });

    testWidgets('has terms acceptance switch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have 2 AdaptiveSwitch widgets: Remember Me + Terms
      expect(find.byType(AdaptiveSwitch), findsNWidgets(2));

      // Check for Terms and Conditions text (rendered via Text.rich TextSpan)
      expect(find.text('Terms and Conditions'), findsOneWidget);

      // Check for Privacy Policy text (rendered via Text.rich TextSpan)
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields on submit', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll to the register button so it is visible for tapping
      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Tap register button without filling any fields
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Check for validation error messages (no name error anymore)
      expect(find.text('Please enter your name'), findsNothing);
      expect(find.text('Please enter your email'), findsOneWidget);
      // "Please enter your password" appears for both password and confirm password fields
      expect(find.text('Please enter your password'), findsNWidgets(2));
    });

    testWidgets('shows validation error for password mismatch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find text fields by their labels (the label Text widgets above each field)
      final emailField = find.widgetWithText(Column, 'Email');
      final passwordField = find.widgetWithText(Column, 'Password');
      final confirmPasswordField = find.widgetWithText(Column, 'Confirm Password');

      // Enter text into each TextFormField (they are descendants of the labeled Columns)
      await tester.enterText(find.descendant(of: emailField, matching: find.byType(TextFormField)).first, 'test@example.com');
      await tester.enterText(find.descendant(of: passwordField, matching: find.byType(TextFormField)).first, 'Password1');
      await tester.enterText(find.descendant(of: confirmPasswordField, matching: find.byType(TextFormField)).first, 'DifferentPassword1');

      // Scroll to the register button so it is visible for tapping
      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Tap register button
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      // Check for password mismatch error
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows validation error for password longer than 72 chars', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(Column, 'Email');
      final passwordField = find.widgetWithText(Column, 'Password');
      final confirmPasswordField = find.widgetWithText(Column, 'Confirm Password');

      final longPassword = 'Password1${'a' * 70}';
      await tester.enterText(find.descendant(of: emailField, matching: find.byType(TextFormField)).first, 'test@example.com');
      await tester.enterText(find.descendant(of: passwordField, matching: find.byType(TextFormField)).first, longPassword);
      await tester.enterText(find.descendant(of: confirmPasswordField, matching: find.byType(TextFormField)).first, longPassword);

      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pumpAndSettle();

      expect(find.text('Too long'), findsOneWidget);
    });

    testWidgets('has sign in link', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for "Already have an account?" text
      expect(find.text('Already have an account?'), findsOneWidget);

      // Check for "Sign In" link
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('has remember me switch', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for "Remember me" text
      expect(find.text('Remember me'), findsOneWidget);
    });
  });
}
