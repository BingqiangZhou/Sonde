import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';

/// Creates a test-friendly MaterialApp.router with required localizations.
///
/// Use this for widget tests that need routing support.
Widget testAppWithRouter({
  required GoRouter router,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    ),
  );
}

/// Helper to tap a widget and wait for it to settle.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}
