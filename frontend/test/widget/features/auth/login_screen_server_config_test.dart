import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/l10n_delegates.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_local_storage_service.dart';

void main() {
  group('LoginScreen ServerConfigDialog Integration Tests', () {
    testWidgets('server config dialog can be displayed', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog is displayed
      expect(find.text('Backend API Server Configuration'), findsOneWidget);
    });

    testWidgets('server config dialog has all required UI elements',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all required elements
      expect(find.text('Backend API URL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('server config dialog supports bilingual', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Test Chinese
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Chinese text
      expect(find.text('后端 API 服务器配置'), findsOneWidget);
      expect(find.text('未验证'), findsOneWidget);
    });

    testWidgets('server config dialog has URL input field', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify URL input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('server config dialog has connection status panel',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status panel (unverified status)
      expect(find.textContaining('Unverified'), findsOneWidget);
    });
  });
}
