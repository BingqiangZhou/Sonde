import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/pages/site_archive_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

import '../../../shared/fake_site_repository.dart';

Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/reading/issue/:kind/:key',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'issue:${state.pathParameters['kind']}:${state.pathParameters['key']}',
            ),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('SiteArchivePage', () {
    testWidgets('lists archived issues per kind tab', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(FakeSiteRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithRouter(
            const SiteArchivePage(initialKind: SiteReportKind.daily),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-10-27'), findsOneWidget);
      expect(find.text('2026-10-26'), findsOneWidget);
      expect(find.text('Rev. 2'), findsOneWidget);
    });

    testWidgets('tapping an issue navigates to the issue route', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(FakeSiteRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithRouter(
            const SiteArchivePage(initialKind: SiteReportKind.daily),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2026-10-27'));
      await tester.pumpAndSettle();

      expect(find.text('issue:daily:2026-10-27'), findsOneWidget);
    });
  });
}
