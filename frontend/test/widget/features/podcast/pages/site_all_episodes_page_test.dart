import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/features/podcast/presentation/pages/site_all_episodes_page.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_providers.dart';

import '../../../shared/fake_site_repository.dart';

void main() {
  group('SiteAllEpisodesPage', () {
    Future<void> pumpPage(WidgetTester tester, ProviderContainer container) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteAllEpisodesPage(),
          ),
        ),
      );
    }

    testWidgets('shows selected and unselected entries with reason and link',
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

      await pumpPage(tester, container);
      await tester.pumpAndSettle();

      // 入选条目：中文标题 + 摘要
      expect(find.text('入选中文标题'), findsOneWidget);
      expect(find.text('中文摘要内容'), findsOneWidget);
      // 落选条目：原标题 + 徽标 + 落选原因 + 原始单集外链
      expect(find.text('Unselected Original Title'), findsOneWidget);
      expect(find.text('Not selected'), findsOneWidget);
      expect(find.text('Reason · 信息量低'), findsOneWidget);
      expect(find.text('Open original episode'), findsOneWidget);
    });

    testWidgets('load more appends next page then reports the end',
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

      await pumpPage(tester, container);
      await tester.pumpAndSettle();

      // 第一页 2 条 + 加载更多
      expect(find.text('第二页中文标题'), findsNothing);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('第二页中文标题'), findsOneWidget);
      // 两页加载完 → 到底提示，不再有按钮
      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });
}
