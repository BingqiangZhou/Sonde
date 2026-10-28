import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/features/podcast/presentation/pages/site_reading_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

import '../../../shared/fake_site_repository.dart';

void main() {
  group('SiteReadingPage', () {
    testWidgets('renders latest daily report body and site tagline',
        (tester) async {
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteReadingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 刊头/导语/看点/分节/条目
      expect(find.text('daily 刊头标题'), findsOneWidget);
      expect(find.text('daily 导语内容'), findsOneWidget);
      expect(find.text('看点一'), findsOneWidget);
      expect(find.text('入选中文标题'), findsOneWidget);
      expect(find.text("Why it's worth listening"), findsNothing); // 无 reasonZh 时不显示
      // 站点标语（/site/meta）
      expect(find.text('把一天的播客，读成一份日报'), findsOneWidget);
    });

    testWidgets('switching to weekly loads the weekly report',
        (tester) async {
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
            home: SiteReadingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('weekly 刊头标题'), findsOneWidget);
      expect(repo.requests, contains('weekly:latest'));
    });

    testWidgets('exposes archive and all-episodes entries in the app bar',
        (tester) async {
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteReadingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Archive'), findsOneWidget);
      expect(find.byTooltip('All Episodes'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    });
  });
}
