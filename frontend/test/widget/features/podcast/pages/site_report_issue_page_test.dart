import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/features/podcast/data/models/site_report_model.dart';
import 'package:sonde/features/podcast/presentation/pages/site_report_issue_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

import '../../../shared/fake_site_repository.dart';

void main() {
  group('SiteReportIssuePage', () {
    testWidgets('renders the requested issue content', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeSiteRepository();
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteReportIssuePage(
              kind: SiteReportKind.weekly,
              reportKey: '2026-10-19',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('weekly 刊头标题'), findsOneWidget);
      expect(find.text('2026-10-19 · Rev. 2 · 1 episodes'), findsOneWidget);
      expect(repo.requests, contains('weekly:2026-10-19'));
    });
  });
}
