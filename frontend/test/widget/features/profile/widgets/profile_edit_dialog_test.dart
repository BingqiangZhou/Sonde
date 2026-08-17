import 'package:flutter/material.dart' show Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/features/auth/domain/models/user.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/profile/presentation/widgets/profile_dialogs.dart';
import 'package:sonde/shared/widgets/custom_text_field.dart';

class _EditProfileAuthNotifier extends AuthNotifier {
  _EditProfileAuthNotifier(this.behavior);

  final Future<void> Function(String username) behavior;

  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: User(
        id: '7',
        email: 'alice@example.com',
        username: 'user_0817x9k2',
        isVerified: true,
        isActive: true,
      ),
    );
  }

  @override
  Future<void> updateUsername(String username) => behavior(username);
}

Widget _harness(AuthNotifier Function() notifierFactory) {
  return ProviderScope(
    overrides: [authProvider.overrideWith(notifierFactory)],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: AdaptiveButton(
              key: const Key('open_dialog'),
              onPressed: () => showEditProfileDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_dialog')));
  await tester.pumpAndSettle();
}

Finder get _nameField {
  return find.descendant(
    of: find.byKey(const Key('edit_profile_name_field')),
    matching: find.byType(TextFormField),
  );
}

void main() {
  group('Edit profile dialog', () {
    testWidgets('prefills current username and offers save/cancel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(() => _EditProfileAuthNotifier((_) async {})),
      );
      await _openDialog(tester);

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(
        tester
            .widget<CustomTextField>(
              find.byKey(const Key('edit_profile_name_field')),
            )
            .controller
            .text,
        'user_0817x9k2',
      );
      expect(find.byKey(const Key('edit_profile_save_button')), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
    });

    testWidgets('validates empty and too-short names', (tester) async {
      await tester.pumpWidget(
        _harness(() => _EditProfileAuthNotifier((_) async {})),
      );
      await _openDialog(tester);

      await tester.enterText(_nameField, '');
      await tester.tap(find.byKey(const Key('edit_profile_save_button')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);

      await tester.enterText(_nameField, 'x');
      await tester.tap(find.byKey(const Key('edit_profile_save_button')));
      await tester.pumpAndSettle();
      expect(find.text('Too short'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('save renames, closes dialog, shows success notice', (
      tester,
    ) async {
      String? saved;
      await tester.pumpWidget(
        _harness(
          () => _EditProfileAuthNotifier((username) async => saved = username),
        ),
      );
      await _openDialog(tester);

      await tester.enterText(_nameField, 'newname');
      await tester.tap(find.byKey(const Key('edit_profile_save_button')));
      await tester.pumpAndSettle();

      expect(saved, 'newname');
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Name updated'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('409 conflict keeps dialog open with inline error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          () => _EditProfileAuthNotifier((_) async {
            throw ServerException('Username already taken', statusCode: 409);
          }),
        ),
      );
      await _openDialog(tester);

      await tester.enterText(_nameField, 'takenname');
      await tester.tap(find.byKey(const Key('edit_profile_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('This name is already taken'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('other server errors close dialog with error notice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          () => _EditProfileAuthNotifier((_) async {
            throw ServerException('Server exploded', statusCode: 500);
          }),
        ),
      );
      await _openDialog(tester);

      await tester.enterText(_nameField, 'newname');
      await tester.tap(find.byKey(const Key('edit_profile_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsNothing);
      expect(find.byKey(const Key('top_floating_notice_message')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
