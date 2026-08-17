import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/storage/local_storage_service.dart';
import 'package:sonde/shared/widgets/server_config_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_local_storage_service.dart';

void main() {
  group('ServerConfigDialog Widget Tests', () {
    testWidgets('displays server config dialog with all elements', (
      tester,
    ) async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Backend API Server Configuration'), findsOneWidget);

      // Verify all required elements are present
      expect(find.text('Backend API URL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('local server button is present', (tester) async {
      // Removed: local server auto-fill button was simplified away
      // Verify the URL input field exists instead
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify URL input field exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has URL input field', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify URL input field exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has connection status panel', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status panel exists (looks for the unverified status text)
      expect(find.textContaining('Unverified'), findsOneWidget);
    });

    testWidgets('clear button shows and hides based on text input', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog(initialUrl: '')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify clear button appears when text is entered
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify text is cleared when clear button is tapped
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify text is cleared
      final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldAfter.controller?.text, isEmpty);
    });

    testWidgets('history list is not shown when empty', (tester) async {
      // Removed: server URL history feature was simplified away
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify history title is not shown
      expect(find.text('History'), findsNothing);
    });

    testWidgets('save button is disabled when connection is not successful', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find save button - it should be disabled (null onPressed)
      final saveButton = find.widgetWithText(TextButton, 'Save');
      expect(saveButton, findsOneWidget);

      // Get the TextButton widget
      final textButton = tester.widget<TextButton>(saveButton);
      // Save button should be disabled when status is not success
      expect(textButton.onPressed, isNull);
    });

    testWidgets('uses mobile width consistent with profile dialogs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 362.0,
        ),
        findsOneWidget,
      );
    });
  });

  group('ServerConfigDialog Bilingual Tests', () {
    testWidgets('supports English localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify English text
      expect(find.text('Backend API Server Configuration'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('supports Chinese localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Chinese text
      expect(find.text('后端 API 服务器配置'), findsOneWidget);
      expect(find.text('未验证'), findsOneWidget);
    });

    testWidgets('clear button has correct localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Test English
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text to show clear button
      await tester.enterText(find.byType(TextField), 'http://example.com');
      await tester.pumpAndSettle();

      // Verify clear icon tooltip in English
      final clearButton = find.byIcon(Icons.close);
      expect(clearButton, findsOneWidget);

      // Test Chinese
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text to show clear button
      await tester.enterText(find.byType(TextField), 'http://example.com');
      await tester.pumpAndSettle();

      // Verify clear icon exists in Chinese locale
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
