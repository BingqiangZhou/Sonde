import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/router/app_router.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets(
    'redirects unauthenticated access to /reports/daily back to pairing',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: ref.watch(appRouterProvider),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      router.go('/reports/daily');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/pairing',
      );
    },
  );
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}
